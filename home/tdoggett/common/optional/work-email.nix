# Work email TUI stack for macOS (Google Workspace via Thunderbird)
#
# Architecture:
#   Google Workspace ←─OAuth─→ Thunderbird (sole network-connected component)
#       ↓ caches locally as Maildir (one file per message)
#   ~/Library/Thunderbird/Profiles/<hash>/ImapMail/imap.gmail.com/
#       ↓ stable symlink (created by activation script)
#   ~/.mail/thunderbird-imap/
#       ↕ neomutt + notmuch read/write here directly
#
# Read/unread flags sync bidirectionally: neomutt and Thunderbird share the same
# Maildir files; flag changes are carried in the filename suffix (:2,S = Seen),
# so marking a message read in neomutt is visible to Thunderbird immediately.
#
# Outgoing mail:
#   neomutt compose → sendmail wrapper → appends to Thunderbird's Unsent Messages
#   → launchd agent fires Cmd+Shift+D every 5 min → sent via Thunderbird OAuth SMTP
#
# One-time Thunderbird setup (required before `darwin-rebuild switch` can link):
#   1. Open Thunderbird and add your Google Workspace account (via OAuth).
#   2. Account Settings → <account> → Server Settings →
#      "Message Store Type" → "Maildir (one file per message)".
#   3. Restart Thunderbird and let it fully sync.
#   4. Run `darwin-rebuild switch`.
#
# If Thunderbird was set up AFTER `darwin-rebuild switch` runs, step 2 may not
# be needed: the activation script writes user.js to the profile declaring
# Maildir as the default for new accounts, so the account will be created in
# Maildir format automatically.
#
# If Thunderbird was already configured before this, the activation script
# detects mbox format (INBOX is a plain file, not a directory) and prints a
# warning with instructions for the manual Server Settings conversion.

{
  pkgs,
  config,
  configVars,
  lib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  # All mail tooling anchors here; notmuch also uses this as its database root.
  mailBase = "${homeDir}/.mail";
  # Symlink to Thunderbird's IMAP cache; created by the activation script.
  thunderbirdImapDir = "${mailBase}/thunderbird-imap";

  # Wrapper script: neomutt pipes composed messages here.
  # Appended to Thunderbird's Unsent Messages mbox; Thunderbird then sends via
  # its own OAuth SMTP connection.
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

    # mboxrd format: "From " at the start of a body line must be escaped as
    # ">From " so it is not mistaken for the message separator.
    {
      printf 'From MAILER-DAEMON %s\n' "$(date +'%a %b %d %H:%M:%S %Y')"
      printf '%s\n' "$MESSAGE" | sed 's/^\(>*From \)/>From /'
      printf '\n'
    } >> "$OUTBOX"

    printf 'Queued — Thunderbird will send within ~5 minutes.\n' >&2
  '';

in
{
  home.packages = with pkgs; [
    w3m # HTML rendering inside neomutt
    urlscan # URL picker invoked from neomutt
  ];

  # All email tooling anchors its Maildir paths here.
  accounts.email.maildirBasePath = "${homeDir}/.mail";

  # Account definition drives notmuch and neomutt config generation.
  # No imap/mbsync block: neomutt reads Thunderbird's Maildir directly.
  accounts.email.accounts.work = {
    primary = true;
    address = configVars.email.work;
    realName = configVars.userFullName;

    # thunderbird-imap is a symlink created by the activation script pointing at
    # Thunderbird's ImapMail/imap.gmail.com/ cache directory.
    maildir.path = "thunderbird-imap";

    # HM's neomutt module's accountStr function always references imap.tls.enable
    # (line 358 of neomutt/default.nix) regardless of whether IMAP is used. The
    # imap block must be a non-null set or Nix evaluation fails with
    # "expected a set but found null". neomutt won't connect here because
    # mailboxType defaults to Maildir when maildir.path is set.
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
    # (see programs.neomutt/default.nix:496).  It also short-circuits
    # accountStr's SMTP evaluation, which would otherwise error with no smtp set.
    neomutt.enable = true;
    neomutt.sendMailCommand = "${homeDir}/.local/bin/send-via-thunderbird";
  };

  # notmuch: full-text search index over ~/.mail/ (includes thunderbird-imap/).
  programs.notmuch = {
    enable = true;
    maildir.synchronizeFlags = true;
    new.tags = [
      "new"
      "unread"
    ];
    search.excludeTags = [
      "deleted"
      "spam"
    ];
    hooks.postNew = ''
      ${pkgs.notmuch}/bin/notmuch tag +inbox -new -- tag:new
    '';
  };

  # neomutt: TUI client reading Thunderbird's Maildir directly.
  programs.neomutt = {
    enable = true;
    vimKeys = true;
    # HM's `settings` generates unquoted `set key=value` lines.
    # Values containing spaces must go in `extraConfig` to avoid parse errors.
    settings = {
      folder = thunderbirdImapDir;
      spoolfile = "+INBOX";

      editor = "nvim";
      sort = "reverse-date-received";
      pager_index_lines = "10";
      markers = "no";
      reply_to = "yes";
      sendmail = "${homeDir}/.local/bin/send-via-thunderbird";
      sendmail_wait = "0";
      mailcap_path = "${homeDir}/.config/neomutt/mailcap";
      sidebar_visible = "yes";
      sidebar_width = "24";
      # Keep deleted-message files in-place with the 'T' (trashed) flag rather
      # than unlinking them immediately. Thunderbird maps 'T' to IMAP \Deleted
      # and expunges on next sync, ensuring server-side deletion propagates.
      maildir_trash = "yes";
    };
    extraConfig = ''
      set realname = "${configVars.userFullName}"
      set date_format = "%Y-%m-%d %H:%M"
      set index_format = "[%Z] %D %-20.20n %s"
      set sidebar_format = "%B%?F? [%F]?%* %?N?%N/?%S"

      auto_view text/html
      alternative_order text/plain text/enriched text/html

      # Gmail folder layout: nested labels live under [Gmail].sbd/
      mailboxes +INBOX "+[Gmail].sbd/All Mail" +Sent +Drafts +Trash
      bind index,pager \CP sidebar-prev
      bind index,pager \CN sidebar-next
      bind index,pager \CO sidebar-open

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
    $DRY_RUN_CMD mkdir -p "${mailBase}"

    # Locate the Thunderbird profile directory (name contains a random hash).
    PROFILE=$(ls -d "${homeDir}/Library/Thunderbird/Profiles/"*.default-release \
                2>/dev/null | head -1)
    if [ -z "$PROFILE" ]; then
      PROFILE=$(ls -d "${homeDir}/Library/Thunderbird/Profiles/"*.default \
                  2>/dev/null | head -1)
    fi

    if [ -n "$PROFILE" ]; then
      # Declare Maildir as the default store type for new IMAP accounts.
      # Written to user.js (read by Thunderbird on every startup, overriding
      # prefs.js) so this preference survives profile resets and Thunderbird
      # reinstalls. Idempotent: skipped if already present in user.js or prefs.js.
      USER_JS="$PROFILE/user.js"
      PREFS_JS="$PROFILE/prefs.js"
      MAILDIR_KEY='mailnews.default_store_contract_id", "@mozilla.org/msgstore/maildirstore;1'
      if ! grep -qF "$MAILDIR_KEY" "$USER_JS" 2>/dev/null && \
         ! grep -qF "$MAILDIR_KEY" "$PREFS_JS" 2>/dev/null; then
        $VERBOSE_ECHO "Adding Maildir preference to $USER_JS"
        if [ -z "$DRY_RUN_CMD" ]; then
          printf '// Managed by Nix: sets Maildir (one file per message) as default\n' >> "$USER_JS"
          printf '// store for new IMAP accounts so neomutt can share the same files.\n' >> "$USER_JS"
          printf 'user_pref("mailnews.default_store_contract_id", "@mozilla.org/msgstore/maildirstore;1");\n' >> "$USER_JS"
        fi
      fi

      IMAP_DIR="$PROFILE/ImapMail/imap.gmail.com"
      if [ -d "$IMAP_DIR" ]; then
        if [ -d "$IMAP_DIR/INBOX" ] && [ -d "$IMAP_DIR/INBOX/cur" ]; then
          # INBOX is a Maildir directory — safe to link.
          $DRY_RUN_CMD ln -sfn "$IMAP_DIR" "${thunderbirdImapDir}"
        elif [ -f "$IMAP_DIR/INBOX" ]; then
          # INBOX is a plain file — Thunderbird is using mbox format.
          $VERBOSE_ECHO "WARNING: Thunderbird INBOX is in mbox format (neomutt requires Maildir)."
          $VERBOSE_ECHO "Convert in Thunderbird:"
          $VERBOSE_ECHO "  Account Settings → <account> → Server Settings"
          $VERBOSE_ECHO "  → Message Store Type → Maildir (one file per message)"
          $VERBOSE_ECHO "  → restart Thunderbird → wait for re-sync"
          $VERBOSE_ECHO "  → darwin-rebuild switch --flake ~/.config/nix-darwin#macbookpro"
        else
          # INBOX not present yet — Thunderbird hasn't fully synced.
          $VERBOSE_ECHO "NOTE: Thunderbird imap.gmail.com folder found but INBOX not synced yet."
          $VERBOSE_ECHO "Let Thunderbird finish syncing, then run darwin-rebuild switch."
          $DRY_RUN_CMD ln -sfn "$IMAP_DIR" "${thunderbirdImapDir}"
        fi
      else
        $VERBOSE_ECHO "NOTE: Thunderbird imap.gmail.com folder not found."
        $VERBOSE_ECHO "Add your Google Workspace account in Thunderbird, let it sync,"
        $VERBOSE_ECHO "then run: darwin-rebuild switch --flake ~/.config/nix-darwin#macbookpro"
      fi
    else
      $VERBOSE_ECHO "NOTE: No Thunderbird profile found."
      $VERBOSE_ECHO "Install Thunderbird and add your Google Workspace account,"
      $VERBOSE_ECHO "then run: darwin-rebuild switch --flake ~/.config/nix-darwin#macbookpro"
    fi
  '';

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
