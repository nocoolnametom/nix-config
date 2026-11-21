"""slack-watch: emit Slack candidate events from the live slk cache.

Reads slk's SQLite cache (read-only), classifies newly cached messages
into candidate events needing attention, and prints or POSTs them as JSON.

  slack-watch [--backfill SECONDS]     one-shot: print JSON (READ-ONLY —
                                       only the daemon owns delivery state)
  slack-watch --daemon                 poll every SLACK_WATCH_POLL_SECONDS
                                       (default 5); POST HMAC-signed batches
                                       (generic V2) to SLACK_WATCH_WEBHOOK_URL
                                       when candidates exist

Cursor: messages.rowid. It is the table's B-tree key, so each poll reads
at most SCAN_LIMIT rows past the cursor without scanning the cache, and a
new row takes max(rowid)+1 inside its write transaction; SQLite has one
writer at a time, so rowids follow commit order and a write that commits
late still lands above the cursor. messages.created_at can do neither: it
is unindexed and stamped before the write. slk's upserts keep a message's
rowid on edits and re-fetches (they are not re-reported), and slk never
replaces, deletes or VACUUMs messages; its own FTS index depends on those
rowids staying stable. If a future slk did any of that, rows could be
renumbered or reused and this cursor would need replacing.

Freshness: slk caches old history (opening an old DM, scrolling back) as
brand-new rows, so ingestion order alone would alert on stale messages. A
row is a candidate only if it is newer than the channel's read marker
(channels.last_read_ts) and its Slack timestamp is at most
SLACK_WATCH_MAX_AGE_HOURS old (default 24).

Missing metadata: slk can cache a message before its conversation's row
(the lookup may fail or be rate-limited). Such rows are kept in a deferred
set and re-checked every poll until the channel appears or the message
ages out; they never fall behind the cursor.

Self identity is resolved per workspace (slk does not store it): the
owner's user ID for that workspace from SLACK_WATCH_SELF_IDS, else a
users.name match against the configured handles within that workspace,
else (only when handles are configured) an exact display-name match.

KNOWN GAP — messages missed while disconnected: slk's reconnect catch-up
refreshes unread counts and the channel on screen only; other channels are
marked stale and fetched when opened. A DM that arrives during a connection
outage (or while slk is not running) therefore stays out of the cache, and
no alert fires, until that conversation is opened in slk. Closing this needs
slk itself to fetch unread conversations after reconnecting (or a source
with durable event delivery); it is deliberately not patched locally.

Delivery: a batch is persisted as `pending` (stable X-Request-ID plus the
complete state change to apply on success) BEFORE the POST, and retried
unchanged until the gateway acknowledges it, including across restarts.
Candidates that do not fit a batch stay above the cursor for a later poll.
Batch size keeps the gateway's {__raw__} rendering (truncated at 4000
chars) intact.

State: ~/.local/state/slack-watch/state.json
Env:   WEBHOOK_SECRET, SLACK_WATCH_WEBHOOK_URL, SLACK_WATCH_POLL_SECONDS,
       SLACK_WATCH_SELF_HANDLES (comma-separated Slack handles, no "@"),
       SLACK_WATCH_SELF_IDS (comma-separated TEAM_ID:USER_ID pairs),
       SLACK_WATCH_MAX_AGE_HOURS
"""
import hashlib
import hmac
import json
import os
import sqlite3
import sys
import time
import urllib.request
import uuid

DB = os.path.expanduser("~/.local/share/slk/cache.db")
STATE = os.path.expanduser("~/.local/state/slack-watch/state.json")
STATE_VERSION = 4

SELF_HANDLES = tuple(
    h.strip().lstrip("@").lower()
    for h in os.environ.get("SLACK_WATCH_SELF_HANDLES", "").replace(" ", ",").split(",")
    if h.strip().lstrip("@")
)
CONFIGURED_SELF_IDS = {}
for _pair in os.environ.get("SLACK_WATCH_SELF_IDS", "").replace(" ", ",").split(","):
    _team, _, _user = _pair.strip().partition(":")
    if _team and _user:
        CONFIGURED_SELF_IDS.setdefault(_team, set()).add(_user)
MAX_AGE = float(os.environ.get("SLACK_WATCH_MAX_AGE_HOURS", "24")) * 3600

SCAN_LIMIT = 500      # rows read past the cursor per poll
MAX_DEFERRED = 500    # deferred rows tracked at once (oldest dropped first)
MAX_EVENTS = 30
CONTEXT_MSGS = 3
# The gateway renders {__raw__} as json.dumps(payload, indent=2)[:4000];
# keep the whole payload under that so no event is truncated away.
RENDER_BUDGET = 3600
ALERT_KEYWORDS = ("alert", "incident", "oncall", "on-call", "pagerduty",
                  "datadog", "sev-", "sev1", "sev2", "outage", "uptime")
BULK_NOISE = ("datadog", "newrelic", "grafana", "watchdog", "sentry",
              "build", "ci-", "github", "dependabot")

ROW_SQL = """
    SELECT m.rowid AS seq, m.ts AS ts_raw, CAST(m.ts AS REAL) AS ts,
           m.workspace_id, m.channel_id, m.user_id, m.text, m.thread_ts,
           m.is_deleted, c.id AS cid, c.name AS cname,
           CASE
               WHEN m.thread_ts <> '' AND m.thread_ts <> m.ts
                    AND m.subtype <> 'thread_broadcast'
               THEN (SELECT s.last_read FROM thread_subscriptions s
                     WHERE s.workspace_id = m.workspace_id
                       AND s.channel_id = m.channel_id
                       AND s.thread_ts = m.thread_ts)
               ELSE c.last_read_ts
           END AS last_read_ts,
           CASE c.type WHEN 'dm' THEN 'im' WHEN 'group_dm' THEN 'mpim'
                ELSE c.type END AS ctype,
           u.name AS uname
    FROM messages m
    LEFT JOIN channels c ON c.id = m.channel_id
    LEFT JOIN users u ON u.id = m.user_id
"""


def fresh_state(con, backfill):
    """Start at the newest cached message (nothing reported), or `backfill`
    seconds of ingestion back. The backfill lookup scans created_at once;
    the cursor itself never does."""
    if backfill > 0:
        row = con.execute("SELECT MIN(rowid) - 1 FROM messages WHERE created_at >= ?",
                          (int(time.time() - backfill),)).fetchone()
        if row and row[0] is not None:
            return {"v": STATE_VERSION, "cursor": row[0], "deferred": {}, "pending": None}
    end = con.execute("SELECT COALESCE(MAX(rowid), 0) FROM messages").fetchone()[0]
    return {"v": STATE_VERSION, "cursor": end, "deferred": {}, "pending": None}


def load_state(con, backfill):
    """v4 state: {v, cursor (messages.rowid), deferred: {rowid:
    first_deferred_epoch}, pending}. Older states (created_at watermarks)
    cannot be mapped onto rowids, so they restart at the newest message."""
    try:
        with open(STATE) as f:
            st = json.load(f)
        if st.get("v") == STATE_VERSION:
            st["deferred"] = {int(k): v for k, v in st.get("deferred", {}).items()}
            st.setdefault("pending", None)
            return st
        print("slack-watch: state predates the rowid cursor; starting at the "
              "newest cached message", file=sys.stderr, flush=True)
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return fresh_state(con, backfill)


def save_state(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"v": STATE_VERSION, "cursor": st["cursor"],
                   "deferred": {str(k): v for k, v in sorted(st["deferred"].items())},
                   "pending": st["pending"], "updated": time.strftime("%F %T")}, f)
    os.replace(tmp, STATE)


def self_ids_by_workspace(con):
    """{workspace_id: {user ids that are the owner}}, resolved separately
    for each workspace: configured IDs, else the handles (by username,
    then exact display name) looked up within that workspace only."""
    out = {}
    for ws in con.execute("SELECT id FROM workspaces"):
        ids = set(CONFIGURED_SELF_IDS.get(ws["id"], ()))
        if not ids and SELF_HANDLES:
            marks = ",".join("?" * len(SELF_HANDLES))
            ids.update(r["id"] for r in con.execute(
                f"SELECT id FROM users WHERE workspace_id = ? AND lower(name) IN ({marks})",
                (ws["id"], *SELF_HANDLES)))
            if not ids:
                ids.update(r["id"] for r in con.execute(
                    f"SELECT id FROM users WHERE workspace_id = ? AND lower(display_name) IN ({marks})",
                    (ws["id"], *SELF_HANDLES)))
        out[ws["id"]] = ids
    return out


def classify(ctype, cname, self_ids, text):
    """Return (kind, priority) or None to skip."""
    raw = text or ""
    t = raw.lower()
    if ctype in ("im", "mpim"):
        return ("dm", "high")
    if any(f"<@{i}>" in raw for i in self_ids):
        return ("mention", "high")
    if any(token in t for token in (
        "<!here>", "<!channel>", "<!everyone>", "@here", "@channel", "@everyone"
    )):
        return ("mention", "high")
    if any(f"@{h}" in t for h in SELF_HANDLES):
        return ("mention", "high")
    name_l = (cname or "").lower()
    if any(k in name_l for k in ALERT_KEYWORDS):
        # alert-bot chatter in alert channels: low unless addressed to user
        if any(k in name_l for k in BULK_NOISE):
            return ("alert", "low")
        return ("alert", "medium")
    return None


def ts_key(ts):
    """Slack ts "<sec>.<micro>" as a sortable tuple ('' sorts first)."""
    if not ts:
        return (0, 0)
    sec, _, micro = ts.partition(".")
    try:
        return (int(sec), int((micro + "000000")[:6]))
    except ValueError:
        return (0, 0)


def judge(r, selfs, now):
    """('skip'|'defer'|'candidate', kind). Deferral only for missing
    channel metadata, and only while the message is still fresh enough to
    matter once it arrives."""
    if r["ts_raw"] is None or r["is_deleted"]:
        return ("skip", None)            # row gone or deleted since ingest
    if now - r["ts"] > MAX_AGE:
        return ("skip", None)            # history, not news
    if r["cid"] is None:
        return ("defer", None)           # conversation not cached yet
    if r["last_read_ts"] and ts_key(r["ts_raw"]) <= ts_key(r["last_read_ts"]):
        return ("skip", None)            # already read
    ws_selfs = selfs.get(r["workspace_id"], set())
    if r["user_id"] and r["user_id"] in ws_selfs:
        return ("skip", None)            # the owner's own message
    kind = classify(r["ctype"], r["cname"], ws_selfs, r["text"])
    return ("candidate", kind) if kind else ("skip", None)


def plan(con, st, now):
    """Examine deferred rows and up to SCAN_LIMIT rows past the cursor.
    Returns (candidates, new_cursor, new_deferred, scanned):
      candidates   [(seq, kind, row)] in seq order (deferred ones first)
      new_cursor / new_deferred  the state once every candidate is delivered
    """
    selfs = self_ids_by_workspace(con)
    candidates = []
    new_deferred = dict(st["deferred"])

    if st["deferred"]:
        seqs = sorted(st["deferred"])
        marks = ",".join("?" * len(seqs))
        for r in con.execute(ROW_SQL + f" WHERE m.rowid IN ({marks}) ORDER BY m.rowid", seqs):
            verdict, kind = judge(r, selfs, now)
            if verdict == "candidate":
                candidates.append((r["seq"], kind, r))
                new_deferred.pop(r["seq"])
            elif verdict == "skip":
                new_deferred.pop(r["seq"])
        # Rows that no longer exist: nothing left to wait for.
        found = {r[0] for r in con.execute(
            f"SELECT rowid FROM messages WHERE rowid IN ({marks})", seqs)}
        for s in seqs:
            if s not in found:
                new_deferred.pop(s, None)

    rows = con.execute(ROW_SQL + " WHERE m.rowid > ? ORDER BY m.rowid LIMIT ?",
                       (st["cursor"], SCAN_LIMIT)).fetchall()
    new_cursor = st["cursor"]
    for r in rows:
        verdict, kind = judge(r, selfs, now)
        if verdict == "candidate":
            candidates.append((r["seq"], kind, r))
        elif verdict == "defer":
            new_deferred.setdefault(r["seq"], int(now))
        new_cursor = r["seq"]

    while len(new_deferred) > MAX_DEFERRED:
        oldest = min(new_deferred)
        print(f"slack-watch: dropping deferred row seq={oldest} (deferred set full)",
              file=sys.stderr, flush=True)
        new_deferred.pop(oldest)
    return candidates, new_cursor, new_deferred, len(rows)


def make_event(con, kind, r):
    # Compare raw timestamps to preserve the (channel_id, ts) index.
    thread_ts = r["thread_ts"] if r["thread_ts"] != r["ts_raw"] else ""
    ctx = con.execute(
        """SELECT user_id, text FROM messages
           WHERE channel_id=? AND is_deleted = 0 AND ts < ?
             AND (? = '' OR ts = ? OR thread_ts = ?)
           ORDER BY ts DESC LIMIT ?""",
        (r["channel_id"], r["ts_raw"], thread_ts, thread_ts, thread_ts,
         CONTEXT_MSGS),
    ).fetchall()
    return {
        "kind": kind[0],
        "priority": kind[1],
        "channel": r["cname"] or r["channel_id"],
        "channel_type": r["ctype"],
        "from": r["uname"] or r["user_id"],
        "ts": time.strftime("%F %T", time.localtime(r["ts"])),
        "thread": bool(r["thread_ts"]),
        "text": (r["text"] or "")[:800],
        "context": [
            {"from": c["user_id"], "text": (c["text"] or "")[:200]}
            for c in reversed(ctx)
        ],
    }


def format_message(events):
    """Human-readable digest for direct delivery (ntfy push). The bridge has
    already classified these as attention-worthy, so the push is the alert."""
    lines = [f"Slack: {len(events)} event(s) for you"]
    for e in events:
        where = f"DM {e['channel']}" if e["channel_type"] == "im" else f"#{e['channel']}"
        text = " ".join((e["text"] or "").split())
        if len(text) > 140:
            text = text[:137] + "..."
        lines.append(f"• {where} — {e['from']}: {text}")
    return "\n".join(lines)


def build_payload(events):
    return {
        "event_type": "slack",
        "source": "slack-watch",
        "count": len(events),
        "message": format_message(events),
        "events": events,
    }


def rendered_len(batched):
    return len(json.dumps(build_payload([e for _, e in batched]), indent=2))


def fit_budget(candidates, con):
    """Take up to MAX_EVENTS candidates (seq order), fetch context for that
    prefix only, then shrink so the rendered payload stays under
    RENDER_BUDGET — the gateway truncates {__raw__} at 4000 chars, which
    would silently drop later events. Trailing events are dropped first
    (they retry later); only a single oversized event gets trimmed.
    Returns [(seq, event)]."""
    batched = [(seq, make_event(con, kind, r)) for seq, kind, r in candidates[:MAX_EVENTS]]
    while len(batched) > 1 and rendered_len(batched) > RENDER_BUDGET:
        batched.pop()
    while batched and rendered_len(batched) > RENDER_BUDGET:
        e = batched[0][1]
        if e["context"]:
            e["context"] = e["context"][:-1]
        elif len(e["text"]) > 100:
            e["text"] = e["text"][: max(100, len(e["text"]) // 2)]
        else:
            break
    return batched


def settle(st, candidates, batched, new_cursor, new_deferred):
    """State after `batched` is delivered. Candidates left out of the batch
    stay pending for a later poll: deferred ones stay deferred, and the
    cursor stops just below the first new one left out."""
    sent = {seq for seq, _ in batched}
    cursor, deferred = new_cursor, dict(new_deferred)
    for seq, _, _ in candidates:
        if seq in sent:
            continue
        if seq in st["deferred"]:
            deferred[seq] = st["deferred"][seq]
        else:
            cursor = min(cursor, seq - 1)
    # Rows deferred during this poll above the new cursor will be rescanned.
    deferred = {s: t for s, t in deferred.items() if s <= cursor or s in st["deferred"]}
    return cursor, deferred


def post_batch(payload, request_id, url, secret):
    """POST one batch, signed with the gateway's generic HMAC V2 scheme:
    X-Webhook-Signature-V2 = hex(hmac_sha256(secret, "<ts>.<body>")).
    X-Request-ID becomes the gateway's webhook_id: reusing it makes a retry
    idempotent instead of re-running triage."""
    body = json.dumps(payload).encode()
    ts = str(int(time.time()))
    sig = hmac.new(secret.encode(), ts.encode() + b"." + body, hashlib.sha256).hexdigest()
    req = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "X-Webhook-Timestamp": ts,
        "X-Webhook-Signature-V2": sig,
        "X-Request-ID": request_id,
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.status


def ack_pending(st):
    st["cursor"] = st["pending"]["cursor"]
    st["deferred"] = {int(k): v for k, v in st["pending"]["deferred"].items()}
    st["pending"] = None


def main():
    backfill = 0.0
    if "--backfill" in sys.argv:
        backfill = float(sys.argv[sys.argv.index("--backfill") + 1])
    daemon = "--daemon" in sys.argv

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    if not SELF_HANDLES and not CONFIGURED_SELF_IDS:
        print("slack-watch: neither SLACK_WATCH_SELF_IDS nor SLACK_WATCH_SELF_HANDLES "
              "is set; mentions and the owner's own messages cannot be recognised",
              file=sys.stderr, flush=True)

    if not daemon:
        # Inspection mode: READ-ONLY. Print the batch that would go out now;
        # delivery state belongs to the daemon alone.
        st = fresh_state(con, backfill) if "--backfill" in sys.argv else load_state(con, 0)
        candidates, new_cursor, new_deferred, n = plan(con, st, time.time())
        batched = fit_budget(candidates, con)
        print(json.dumps({
            "events": [e for _, e in batched],
            "rows_scanned": n,
            "truncated": len(batched) < len(candidates),
            "cursor": st["cursor"],
            "deferred": len(new_deferred),
            "pending_batch": bool(st["pending"]),
            "self_ids_by_workspace": {k: len(v) for k, v in self_ids_by_workspace(con).items()},
        }, indent=1))
        return

    st = load_state(con, backfill)
    save_state(st)

    url = os.environ.get(
        "SLACK_WATCH_WEBHOOK_URL", "http://127.0.0.1:8644/webhooks/slack-events")
    secret = os.environ.get("WEBHOOK_SECRET", "")
    poll = float(os.environ.get("SLACK_WATCH_POLL_SECONDS", "5"))
    if not secret:
        print("slack-watch: WEBHOOK_SECRET is not set", file=sys.stderr)
        sys.exit(1)
    print(f"slack-watch daemon: every {poll:.0f}s -> {url}", file=sys.stderr, flush=True)

    while True:
        try:
            if not st["pending"]:
                candidates, new_cursor, new_deferred, _ = plan(con, st, time.time())
                batched = fit_budget(candidates, con)
                cursor, deferred = settle(st, candidates, batched, new_cursor, new_deferred)
                if not batched:
                    if cursor != st["cursor"] or deferred != st["deferred"]:
                        st["cursor"], st["deferred"] = cursor, deferred
                        save_state(st)
                else:
                    st["pending"] = {
                        "request_id": uuid.uuid4().hex,
                        "payload": build_payload([e for _, e in batched]),
                        "cursor": cursor,
                        "deferred": {str(k): v for k, v in deferred.items()},
                    }
                    save_state(st)  # persist BEFORE POST: a lost POST retries

            if st["pending"]:
                # Retry the exact batch under the same X-Request-ID until
                # the gateway acknowledges it.
                status = post_batch(st["pending"]["payload"],
                                    st["pending"]["request_id"], url, secret)
                n = st["pending"]["payload"]["count"]
                if 200 <= status < 300:
                    ack_pending(st)
                    save_state(st)
                    print(f"posted {n} events -> HTTP {status}", file=sys.stderr, flush=True)
                    continue  # more may be waiting above the cursor
                print(f"POST rejected HTTP {status}; will retry", file=sys.stderr, flush=True)
                time.sleep(min(poll * 4, 60))
        except Exception as e:  # transient DB/HTTP error: never die
            print(f"slack-watch: error: {e}", file=sys.stderr, flush=True)
            time.sleep(min(poll * 4, 60))
        time.sleep(poll)


if __name__ == "__main__":
    main()
