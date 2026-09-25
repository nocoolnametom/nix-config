# Work email TUI stack for macOS (Google Workspace via lieer + notmuch)
#
# Architecture:
#   Google Workspace ←─OAuth REST API─→ lieer (gmi sync, every 5 min)
#       ↓ flat Maildir (all messages in one directory)
#   ~/.mail/work/mail/cur/<hash>:2,<flags>
#       ↕ indexed by notmuch (full-text search, tag-based organization)
#   notmuch tags ↔ Gmail labels (bidirectional via gmi push)
#       ↕ neomutt presents mail via notmuch virtual-mailboxes
#
# Outgoing mail:
#   neomutt compose → send-via-thunderbird → Thunderbird Unsent Messages mbox
#   → launchd agent fires Cmd+Shift+D every 5 min → sent via Thunderbird OAuth SMTP
#
# Flag/label sync path:
#   neomutt marks message (renames file with Maildir T/S flag)
#   → gmi pull runs `notmuch new` (detects rename, updates tags: T→deleted, S→~unread)
#   → gmi push reads tag changes, applies Gmail labels (\Trash, etc.)
#
# One-time setup per machine:
#   1. darwin-rebuild switch  (creates ~/.mail/work/ and writes .gmailieer.json)
#   2. cd ~/.mail/work && gmi auth  (OAuth browser flow; credentials saved locally)
#   3. cd ~/.mail/work && gmi pull  (initial sync; may take a few minutes)
#   4. For outgoing: open Thunderbird and add your Google Workspace account via OAuth.
#
# Re-auth when Google Workspace policy expires the token:
#   cd ~/.mail/work && gmi auth
#
# Credentials are NOT stored in SOPS because enterprise OAuth tokens expire on
# policy schedules you don't control — re-auth is always a manual step. There is
# no benefit to wrapping a value that needs periodic replacement in nix-secrets.

{
  pkgs,
  config,
  configVars,
  lib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  # All mail tooling anchors here; notmuch database also lives here (.notmuch/).
  mailBase = "${homeDir}/.mail";
  # lieer account directory: contains .gmailieer.json, .credentials.gmailieer.json
  lieerDir = "${mailBase}/work";
  # lieer writes all message files here (flat Maildir, no subfolders)
  lieerMailDir = "${lieerDir}/mail";

  # Wrapper: neomutt pipes composed messages here.
  # Appended to Thunderbird's Unsent Messages mbox; Thunderbird sends via OAuth SMTP.
  sendmailScript = pkgs.writeShellScript "send-via-thunderbird" ''
    set -e

    PROFILE=$(ls -d "${homeDir}/Library/Thunderbird/Profiles/"*.default-release \
                2>/dev/null | head -1)
    if [ -z "$PROFILE" ]; then
      PROFILE=$(ls -d "${homeDir}/Library/Thunderbird/Profiles/"*.default \
                  2>/dev/null | head -1)
    fi
    if [ -z "$PROFILE" ]; then
      printf 'send-via-thunderbird: Thunderbird profile not found\n' >&2
      exit 1
    fi

    LOCAL_FOLDERS="$PROFILE/Mail/Local Folders"
    mkdir -p "$LOCAL_FOLDERS"
    OUTBOX="$LOCAL_FOLDERS/Unsent Messages"
    [ -f "$OUTBOX" ] || touch "$OUTBOX"

    # Cooperative mbox locking — Thunderbird also creates this .lock directory.
    LOCK="$OUTBOX.lock"
    TRIES=0
    until mkdir "$LOCK" 2>/dev/null; do
      TRIES=$((TRIES + 1))
      if [ "$TRIES" -ge 10 ]; then
        printf 'send-via-thunderbird: timed out waiting for outbox lock\n' >&2
        exit 1
      fi
      sleep 1
    done
    trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

    MESSAGE=$(cat)

    # mboxrd format: "From " at the start of a body line must be escaped.
    {
      printf 'From MAILER-DAEMON %s\n' "$(date +'%a %b %d %H:%M:%S %Y')"
      printf '%s\n' "$MESSAGE" | sed 's/^\(>*From \)/>From /'
      printf '\n'
    } >> "$OUTBOX"

    printf 'Queued — Thunderbird will send within ~5 minutes.\n' >&2
  '';

  # Non-sensitive lieer configuration. Written declaratively by the activation
  # script. The credentials file (.credentials.gmailieer.json) is NOT managed
  # here — generate it with `cd ~/.mail/work && gmi auth`.
  gmailieerConfig = pkgs.writeText "gmailieer-config.json" (builtins.toJSON {
    account = configVars.email.work;
    replace_slash_with_dot = false;
    timeout = 600;
    drop_non_existing_label = false;
    ignore_empty_history = false;
    ignore_tags = [ ];
    # Must match notmuch's Maildir T-flag mapping (T flag → `deleted` tag).
    # notmuch.maildir.synchronizeFlags maps T → `deleted`, so setting
    # local_trash_tag = "deleted" ensures gmi push propagates neomutt deletions
    # to Gmail's \Trash label.
    local_trash_tag = "deleted";
    ignore_remote_labels = [
      "CATEGORY_PERSONAL"
      "CATEGORY_PROMOTIONS"
      "CATEGORY_UPDATES"
      "CATEGORY_SOCIAL"
      "CATEGORY_FORUMS"
    ];
    remove_local_messages = true;
    file_extension = "";
    translation_list_overlay = [ ];
  });

in
{
  home.packages = with pkgs; [
    w3m # HTML rendering inside neomutt
    urlscan # URL picker invoked from neomutt
    lieer # Gmail REST API sync; provides the `gmi` command
  ];

  # All email tooling anchors Maildir paths here; notmuch database root.
  accounts.email.maildirBasePath = "${homeDir}/.mail";

  accounts.email.accounts.work = {
    primary = true;
    address = configVars.email.work;
    realName = configVars.userFullName;

    # lieer uses a flat Maildir at ~/.mail/work/mail/ (relative: work/mail)
    maildir.path = "work/mail";

    # HM's neomutt module unconditionally accesses imap.tls.enable (line 358 of
    # neomutt/default.nix) regardless of whether IMAP is used. Without a non-null
    # imap block, evaluation fails with "expected a set but found null".
    # neomutt never connects here because mailboxType defaults to Maildir when
    # maildir.path is set.
    imap = {
      host = "127.0.0.1";
      port = 993;
      tls.enable = false;
      tls.useStartTls = false;
    };
    passwordCommand = "echo dummy";

    notmuch.enable = true;

    # sendMailCommand being non-null is what places this account in
    # neomuttAccounts — the list that gates neomuttrc generation in HM
    # (programs.neomutt/default.nix:496). It also short-circuits accountStr's
    # SMTP evaluation path, which would error with no smtp block set.
    neomutt.enable = true;
    neomutt.sendMailCommand = "${homeDir}/.local/bin/send-via-thunderbird";
    # lieer uses a flat Maildir with no Inbox subfolder — suppress the physical
    # `mailboxes ".../mail/Inbox"` line HM generates by default, which causes
    # an "Unknown Mailbox" error and a segfault on startup.
    neomutt.showDefaultMailbox = false;
  };

  # notmuch: full-text search index + tag store over ~/.mail/
  # lieer handles all label→tag mapping during `gmi pull`, so we don't need
  # new.tags or a postNew hook to set inbox/unread — lieer does that from Gmail's
  # INBOX and UNREAD labels. An inbox-tagging hook would incorrectly re-add the
  # inbox tag to archived messages.
  programs.notmuch = {
    enable = true;
    # Bidirectional sync between Maildir flags and notmuch tags:
    #   T flag (Trashed)  ↔  deleted tag
    #   S flag (Seen)     ↔  ~unread tag (presence of S removes unread)
    maildir.synchronizeFlags = true;
    new.tags = [ ];
    new.ignore = [
      # lieer stores config, credentials, lock, and state files alongside the
      # Maildir in ~/.mail/work/. notmuch new would otherwise warn about each.
      ".gmailieer.json"
      ".credentials.gmailieer.json"
      ".lock"
      ".state.gmailieer.json"
      ".state.gmailieer.json.bak"
      ".resume-pull.gmailieer.json.bak"
      # launchd agent logs land in ~/.mail/; *.log catches current and future ones.
      "*.log"
      # Old Dovecot directory — cleaned up by activation script but guarded here too.
      "dovecot-run"
      # Thunderbird's own IMAP cache directory, exposed under ~/.mail/ via symlink
      # in the old Dovecot-based architecture. Activation script removes the symlink,
      # but this guard prevents re-indexing if Thunderbird recreates it.
      "thunderbird-source"
      # Old mbsync IMAP subfolder structure — lieer uses a flat Maildir, so any
      # subdirectory under mail/ is a leftover from before lieer. Activation script
      # removes them; this prevents accidental re-indexing.
      "Trash"
      "Sent"
      "Sent Mail"
      "All Mail"
      "Drafts"
      "Spam"
      "Starred"
    ];
    search.excludeTags = [
      "deleted"
      "spam"
    ];
    hooks.postNew = ''
      # When neomutt marks a message for deletion (Maildir T flag, maildir_trash=yes),
      # notmuch new adds the `deleted` tag via maildir.synchronizeFlags. But `inbox`
      # has no Maildir flag counterpart, so it is never removed automatically.
      # Without this hook, deleted messages keep `inbox` and reappear in the INBOX
      # virtual-mailbox after every sync. lieer's gmi push picks up the tag delta
      # (-inbox, +deleted) and moves the message to Gmail Trash.
      ${pkgs.notmuch}/bin/notmuch tag -inbox -unread -- tag:deleted
    '';
  };

  # neomutt: TUI mail client presenting Gmail via notmuch virtual-mailboxes.
  # lieer's flat Maildir has no subfolder hierarchy; all organization is via tags.
  programs.neomutt = {
    enable = true;
    vimKeys = true;
    # HM's `settings` generates unquoted `set key=value` lines.
    # Values containing spaces must go in `extraConfig` to avoid parse errors.
    settings = {
      editor = "nvim";
      sort = "reverse-date-received";
      pager_index_lines = "10";
      markers = "no";
      reply_to = "yes";
      sendmail = "${homeDir}/.local/bin/send-via-thunderbird";
      sendmail_wait = "0";
      mailcap_path = "${homeDir}/.config/neomutt/mailcap";
      sidebar_visible = "yes";
      sidebar_width = "30";
      # Keep deleted-message files in-place with the T (Trashed) flag rather than
      # unlinking them. notmuch.maildir.synchronizeFlags converts T → `deleted` tag;
      # gmi push then moves the message to Gmail's \Trash label.
      maildir_trash = "yes";
    };
    extraConfig = ''
      set realname = "${configVars.userFullName}"
      set date_format = "%Y-%m-%d %H:%M"
      set index_format = "[%Z] %D %-20.20n %s"
      set sidebar_format = "%B%?F? [%F]?%* %?N?%N/?%S"

      auto_view text/html
      alternative_order text/plain text/enriched text/html

      # notmuch virtual-mailbox setup.
      # folder: physical Maildir root — used by neomutt to resolve message paths
      #   when opening individual messages from a virtual-mailbox view.
      # nm_default_url: the notmuch database directory (containing .notmuch/).
      # spoolfile: the mailbox neomutt opens on startup (notmuch inbox query).
      set folder = "${lieerMailDir}"
      set nm_default_url = "notmuch://${mailBase}"
      set spoolfile = "notmuch://${mailBase}?query=tag:inbox"

      # Clear any mailboxes registered by HM's per-account stanzas before
      # declaring our own clean set. `unmailboxes *` covers both physical and
      # virtual mailboxes in this neomutt build (the fix landed alongside the
      # separate `virtual-unmailboxes` command). HM generates a virtual
      # "My INBOX" from notmuch.enable = true that duplicates our INBOX below.
      unmailboxes *

      virtual-mailboxes "INBOX"    "notmuch://${mailBase}?query=tag:inbox"
      virtual-mailboxes "Unread"   "notmuch://${mailBase}?query=tag:unread"
      virtual-mailboxes "Sent"     "notmuch://${mailBase}?query=tag:sent"
      virtual-mailboxes "All Mail" "notmuch://${mailBase}?query=NOT tag:deleted AND NOT tag:spam"

      bind index,pager \CP sidebar-prev
      bind index,pager \CN sidebar-next
      bind index,pager \CO sidebar-open

      # vim-keys.rc binds \Cm (Enter) to list-reply with a "Doesn't work currently"
      # comment. Override it so Enter opens the selected message as expected.
      bind index \Cm display-message

      # After neomutt marks messages for deletion (Maildir T flag via dd) and after
      # reading messages (Maildir S flag), press $ to flush the flag renames to
      # disk and run notmuch new. notmuch new picks up the file renames, updates
      # tags (T→+deleted, S→-unread), and runs the postNew hook which removes
      # inbox from deleted messages. lieer's next gmi push propagates the changes.
      macro index $ '<sync-mailbox><shell-escape>notmuch new<enter>' \
        'sync and update notmuch index'

      macro index,pager \Cu "<pipe-message> ${pkgs.urlscan}/bin/urlscan<Enter>" "pick URL"
      macro index \` "<vfolder-from-query>" "notmuch query"
    '';
  };

  home.file.".config/neomutt/mailcap".text = ''
    text/html; ${pkgs.w3m}/bin/w3m -I %{charset} -T text/html %s; needsterminal
  '';

  home.file.".local/bin/send-via-thunderbird" = {
    source = sendmailScript;
    executable = true;
  };

  home.activation.setupMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Create the Maildir structure that lieer expects.
    $DRY_RUN_CMD mkdir -p "${lieerMailDir}/cur" "${lieerMailDir}/new" "${lieerMailDir}/tmp"

    # Write the non-sensitive lieer config declaratively.
    # Overwritten on every darwin-rebuild switch — do not edit by hand.
    # Credentials (.credentials.gmailieer.json) are not written here.
    $DRY_RUN_CMD cp -f ${gmailieerConfig} "${lieerDir}/.gmailieer.json"

    # Remove symlinks from previous mail architectures.
    # thunderbird-imap: old Dovecot IMAP server symlink.
    # thunderbird-source: symlink into Thunderbird's own IMAP cache (before lieer).
    for STALE_LINK in \
      "${mailBase}/thunderbird-imap" \
      "${mailBase}/thunderbird-source"; do
      if [ -L "$STALE_LINK" ]; then
        $VERBOSE_ECHO "Removing stale symlink: $STALE_LINK"
        $DRY_RUN_CMD rm -f "$STALE_LINK"
      fi
    done

    # Remove leftover artifacts from previous mail architectures (Dovecot, mbsync).
    for STALE in \
      "${mailBase}/dovecot-run" \
      "${mailBase}/dovecot-stderr.log" \
      "${mailBase}/dovecot-stdout.log" \
      "${mailBase}/dovecot.log" \
      "${mailBase}/mbsync.log" \
      "${lieerMailDir}/Trash" \
      "${lieerMailDir}/Sent" \
      "${lieerMailDir}/Sent Mail" \
      "${lieerMailDir}/All Mail" \
      "${lieerMailDir}/Drafts" \
      "${lieerMailDir}/Spam" \
      "${lieerMailDir}/Starred"; do
      if [ -e "$STALE" ] || [ -L "$STALE" ]; then
        $VERBOSE_ECHO "Removing stale artifact: $STALE"
        $DRY_RUN_CMD rm -rf "$STALE"
      fi
    done

    # Initialize notmuch database if not already present.
    if [ ! -d "${mailBase}/.notmuch" ] && [ -z "$DRY_RUN_CMD" ]; then
      $VERBOSE_ECHO "Initializing notmuch database at ${mailBase}/.notmuch"
      ${pkgs.notmuch}/bin/notmuch new
    fi

    # Credentials are generated by the OAuth flow and are not managed by Nix.
    # After darwin-rebuild switch on a new machine, run:
    #   cd ${lieerDir} && ${pkgs.lieer}/bin/gmi auth
    if [ ! -f "${lieerDir}/.credentials.gmailieer.json" ]; then
      $VERBOSE_ECHO "NOTE: lieer OAuth credentials not found."
      $VERBOSE_ECHO "To authenticate with Google Workspace:"
      $VERBOSE_ECHO "  cd ${lieerDir} && ${pkgs.lieer}/bin/gmi auth"
    fi
  '';

  # Sync Gmail every 5 minutes via lieer.
  # `gmi sync` = `gmi pull` (Gmail → Maildir + notmuch tags) +
  #              `gmi push` (notmuch tag changes → Gmail labels).
  launchd.agents.lieer-sync = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.lieer}/bin/gmi"
        "sync"
      ];
      WorkingDirectory = lieerDir;
      StartInterval = 300;
      StandardOutPath = "${mailBase}/lieer-sync.log";
      StandardErrorPath = "${mailBase}/lieer-sync.log";
    };
  };

  # Thunderbird outbox flush every 5 minutes.
  # Fires Cmd+Shift+D (File → Send Unsent Messages) when Thunderbird is running;
  # silently no-ops if Thunderbird is closed.
  launchd.agents.thunderbird-flush-outbox = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/osascript"
        "-e"
        "tell application \"System Events\" to if exists process \"thunderbird\" then tell process \"thunderbird\" to keystroke \"d\" using {command down, shift down}"
      ];
      StartInterval = 300;
      StandardOutPath = "${mailBase}/thunderbird-flush.log";
      StandardErrorPath = "${mailBase}/thunderbird-flush.log";
    };
  };
}
