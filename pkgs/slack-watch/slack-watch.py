#!/run/current-system/sw/bin/python3
"""slack-watch: emit Slack candidate events newer than a checkpoint.

Reads the live slk cache (read-only), classifies new messages into
candidate events needing attention, prints JSON to stdout.

  slack-watch [--backfill SECONDS]     one-shot: print JSON (READ-ONLY —
                                       only the daemon owns delivery state)
  slack-watch --daemon                 poll every SLACK_WATCH_POLL_SECONDS
                                       (default 5); POST HMAC-signed batches
                                       (generic V2) to SLACK_WATCH_WEBHOOK_URL
                                       when candidates exist

First daemon run: checkpoint = now (nothing reported). --backfill N starts
a fresh checkpoint N seconds in the past (for testing / catching up).

Checkpointing tracks cache ingestion, not Slack send time: the watermark
is messages.created_at (the epoch slk inserted the row), which is
monotonic with respect to cache ingestion. A channel refreshed hours late
still lands above the watermark, so its DMs and mentions are never missed.
The scan uses an inclusive boundary (created_at >= watermark) and dedupes
on the message uid (created_at + channel + ts), so rows sharing the
boundary second are handled without loss or double-send. Only DELIVERED
events are marked seen; batch overflow stays unseen and goes out in a
later poll.

Batch size is bounded so the gateway's {__raw__} renderer (which truncates
the payload JSON at 4000 chars) always sees the complete event list:
events are dropped from the tail, then shrunk, until the rendered payload
fits RENDER_BUDGET. Dropped events are retried, not lost.

A batch is persisted as `pending` (with a stable X-Request-ID) BEFORE the
POST, and retried unchanged until the gateway acknowledges it — including
across bridge restarts — so a lost response cannot cause double triage.
State: ~/.local/state/slack-watch/state.json
Env:   SLACK_SELF_ID, WEBHOOK_SECRET, SLACK_WATCH_WEBHOOK_URL,
       SLACK_WATCH_POLL_SECONDS
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
# Slack handle(s) for the owner: 'tdogg' is the in-Slack username,
# 'tdoggett' the corporate one. First exact name match wins.
SELF_NAMES = ("tdogg", "tdoggett")
MAX_EVENTS = 30
CONTEXT_MSGS = 3
# The gateway renders {__raw__} as json.dumps(payload, indent=2)[:4000];
# keep the whole payload under that so no event is truncated away.
RENDER_BUDGET = 3600
ALERT_KEYWORDS = ("alert", "incident", "oncall", "on-call", "pagerduty",
                  "datadog", "sev-", "sev1", "sev2", "outage", "uptime")
BULK_NOISE = ("datadog", "newrelic", "grafana", "watchdog", "sentry",
              "build", "ci-", "github", "dependabot")


def load_state(backfill):
    """v3 state: {v, last_ca, seen: [uid...], pending: null|{...}}.
    Anything older starts fresh at 'now - backfill': earlier watermark
    schemes keyed on Slack send timestamps, which does not map onto the
    ingestion boundary."""
    try:
        with open(STATE) as f:
            st = json.load(f)
        if st.get("v") == 3:
            st["seen"] = set(st.get("seen", []))
            st.setdefault("pending", None)
            return st
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return {"v": 3, "last_ca": int(time.time() - backfill), "seen": set(),
            "pending": None}


def save_state(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    # Prune uids below the checkpoint in memory too, not just on disk: the
    # daemon is long-lived and would otherwise grow `seen` forever.
    st["seen"] = {u for u in st["seen"] if int(u.split("|", 1)[0]) >= st["last_ca"]}
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"v": 3, "last_ca": st["last_ca"], "seen": sorted(st["seen"]),
                   "pending": st["pending"], "updated": time.strftime("%F %T")}, f)
    os.replace(tmp, STATE)


def uid_of(created_at, channel_id, ts):
    return f"{created_at}|{channel_id}|{ts}"


def classify(ctype, cname, self_id, text):
    """Return (kind, priority) or None to skip."""
    t = (text or "").lower()
    if ctype in ("im", "mpim"):
        return ("dm", "high")
    if self_id and f"<@{self_id}>" in (text or ""):
        return ("mention", "high")
    if any(token in t for token in (
        "<!here>", "<!channel>", "<!everyone>", "@here", "@channel", "@everyone"
    )):
        return ("mention", "high")
    if any(f"@{n}" in t for n in SELF_NAMES):
        return ("mention", "high")
    name_l = (cname or "").lower()
    if any(k in name_l for k in ALERT_KEYWORDS):
        # alert-bot chatter in alert channels: low unless addressed to user
        if any(k in name_l for k in BULK_NOISE):
            return ("alert", "low")
        return ("alert", "medium")
    return None


def find_self_id(con):
    self_id = os.environ.get("SLACK_SELF_ID") or None
    if not self_id:
        for handle in SELF_NAMES:
            row = con.execute("SELECT id FROM users WHERE name=?", (handle,)).fetchone()
            if row:
                self_id = row["id"]
                break
    if not self_id:
        row = con.execute(
            "SELECT id FROM users WHERE display_name LIKE ? LIMIT 1",
            (f"%{SELF_NAMES[0]}%",),
        ).fetchone()
        if row:
            self_id = row["id"]
    return self_id


def scan(con, st, self_id):
    """Return (candidates, max_ca, n_rows) for cache rows ingested at or
    above the checkpoint. candidates = [(ca, uid, kind, row)] in ingestion
    order, excluding uids already seen. Context is NOT fetched here — only
    the batchable prefix gets that (see fit_budget)."""
    rows = con.execute(
        """SELECT CAST(m.ts AS REAL) AS ts, m.ts AS ts_raw, m.created_at AS ca,
                  m.channel_id, m.user_id, m.text,
                  m.thread_ts, c.name AS cname,
                  CASE c.type WHEN 'dm' THEN 'im' WHEN 'group_dm' THEN 'mpim'
                       ELSE c.type END AS ctype, u.name AS uname
           FROM messages m
           LEFT JOIN channels c ON c.id = m.channel_id
           LEFT JOIN users u ON u.id = m.user_id
           WHERE m.is_deleted = 0 AND m.created_at >= ?
           ORDER BY m.created_at""",
        (st["last_ca"],),
    ).fetchall()

    candidates, max_ca = [], st["last_ca"]
    for r in rows:
        max_ca = max(max_ca, r["ca"])
        uid = uid_of(r["ca"], r["channel_id"], r["ts_raw"])
        if uid in st["seen"]:
            continue
        if self_id and r["user_id"] == self_id:
            continue
        kind = classify(r["ctype"], r["cname"], self_id, r["text"])
        if not kind:
            continue
        candidates.append((r["ca"], uid, kind, r))

    return candidates, max_ca, len(rows)


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


def fit_budget(candidates, con):
    """Take up to MAX_EVENTS candidates (ingestion order), fetch context for
    that prefix only, then shrink so the rendered payload stays under
    RENDER_BUDGET — the gateway truncates {__raw__} at 4000 chars, which
    would silently drop later events. Trailing events are dropped first
    (they retry later); only a single oversized event gets trimmed.
    Returns [(ca, uid, event)]."""
    batched = [(ca, uid, make_event(con, kind, r))
               for ca, uid, kind, r in candidates[:MAX_EVENTS]]
    while len(batched) > 1 and len(json.dumps(
            build_payload([e for _, _, e in batched]), indent=2)) > RENDER_BUDGET:
        batched.pop()
    while batched and len(json.dumps(
            build_payload([e for _, _, e in batched]), indent=2)) > RENDER_BUDGET:
        e = batched[0][2]
        if e["context"]:
            e["context"] = e["context"][:-1]
        elif len(e["text"]) > 100:
            e["text"] = e["text"][: max(100, len(e["text"]) // 2)]
        else:
            break
    return batched


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
    """Mark the pending batch delivered and slide the checkpoint. Never
    advance past an undelivered candidate: the inclusive boundary rescans
    those."""
    delivered = st["pending"]
    for uid in delivered["uids"]:
        st["seen"].add(uid)
    st["last_ca"] = max(st["last_ca"],
                        max(int(u.split("|", 1)[0]) for u in delivered["uids"]))
    st["pending"] = None


def main():
    backfill = 0.0
    if "--backfill" in sys.argv:
        backfill = float(sys.argv[sys.argv.index("--backfill") + 1])
    daemon = "--daemon" in sys.argv

    st = load_state(backfill)
    if daemon:
        save_state(st)
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    self_id = find_self_id(con)

    if not daemon:
        if "--backfill" in sys.argv:
            st["last_ca"] = int(time.time() - backfill)
            st["seen"] = set()
        # Inspection mode: READ-ONLY. Print the batch that would go out now;
        # delivery state belongs to the daemon alone (writing here could
        # skip undelivered candidates or race the daemon's state file).
        candidates, _max_ca, n = scan(con, st, self_id)
        batched = fit_budget(candidates, con)
        print(json.dumps({
            "events": [e for _, _, e in batched],
            "new_messages_since_checkpoint": n,
            "truncated": len(batched) < len(candidates),
            "checkpoint": st["last_ca"],
            "pending_batch": bool(st["pending"]),
            "self_id_found": bool(self_id),
        }, indent=1))
        return

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
            if not self_id:  # slk may still be populating its user cache
                self_id = find_self_id(con)

            if st["pending"]:
                # Retry the exact batch under the same X-Request-ID until
                # the gateway acknowledges it.
                status = post_batch(st["pending"]["payload"],
                                    st["pending"]["request_id"], url, secret)
                if 200 <= status < 300:
                    n = st["pending"]["payload"]["count"]
                    ack_pending(st)
                    save_state(st)
                    print(f"posted {n} events -> HTTP {status}",
                          file=sys.stderr, flush=True)
                else:
                    print(f"POST rejected HTTP {status}; will retry", file=sys.stderr, flush=True)
                    time.sleep(min(poll * 4, 60))
                continue

            if not self_id:
                time.sleep(poll)
                continue
            candidates, max_ca, _ = scan(con, st, self_id)
            batched = fit_budget(candidates, con)
            if not batched:
                if not candidates and max_ca > st["last_ca"]:
                    st["last_ca"] = max_ca  # every scanned row fully processed
                    save_state(st)
                # Undelivered candidates (pathological oversize): hold the
                # checkpoint; the inclusive boundary rescans them.
            else:
                st["pending"] = {
                    "request_id": uuid.uuid4().hex,
                    "payload": build_payload([e for _, _, e in batched]),
                    "uids": [uid for _, uid, _ in batched],
                }
                save_state(st)  # persist BEFORE POST: a lost POST retries
                status = post_batch(st["pending"]["payload"],
                                    st["pending"]["request_id"], url, secret)
                if 200 <= status < 300:
                    ack_pending(st)
                    if len(candidates) > len(batched):
                        # Overflow waits: cap at the oldest undelivered ca.
                        oldest_undelivered = candidates[len(batched)][0]
                        st["last_ca"] = min(st["last_ca"], oldest_undelivered)
                    save_state(st)
                    print(f"posted {len(batched)} events -> HTTP {status}",
                          file=sys.stderr, flush=True)
                else:
                    print(f"POST rejected HTTP {status}; will retry", file=sys.stderr, flush=True)
                    time.sleep(min(poll * 4, 60))
        except Exception as e:  # transient DB/HTTP error: never die
            print(f"slack-watch: error: {e}", file=sys.stderr, flush=True)
            time.sleep(min(poll * 4, 60))
        time.sleep(poll)


if __name__ == "__main__":
    main()
