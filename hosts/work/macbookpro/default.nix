###############################################################################
#
#  MBP - MBP
#  Darwin running on MacBook Pro 16-inch 2023 M2
#
###############################################################################

{
  inputs,
  pkgs,
  lib,
  configLib,
  config,
  configVars,
  configurationRevision,
  ...
}:

let
  externallyManagedPackageNames = [
    # These are kept MORE up-to-date than unstable usually allows
    # so we need to defer to using the system services instead of
    # Nix-Darwin to handle them.
    "vscode"
    "code-cursor"
    "google-chrome"
    "google-chrome-beta"
    "google-chrome-canary"

    # These require screen recording permissions that, for some reason,
    # I cannot figure out how to provide to Nix-Darwin-handled apps
    "slack"
    "zoom-us"

    # These packages are NOT kept updated nearly enough to keep up with
    # their development
    "tableplus"
  ];
in
{
  imports = [
    ######################## Direct Imports for MBP ############################
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/darwin/core"

    #################### Host-specific Optional Configs ####################
    # Be very careful, most of these are meant for NixOS, not Darwin!
    "hosts/common/darwin/optional/nix-remote-builders.nix"
    "hosts/common/optional/direnv.nix"
    "hosts/common/optional/stylix.nix"
    "hosts/common/optional/tmux.nix"
    "hosts/common/optional/yubikey.nix"
    "hosts/common/darwin/optional/yknotify.nix"
    "hosts/common/darwin/optional/homebrew"
    "hosts/common/darwin/optional/services/aerospace"
    "hosts/common/darwin/optional/services/dnsmasq"
    # This can be re-enabled once nixpkgs gets the new Mac compilation stuff for Tahoe working
    "hosts/common/darwin/optional/services/jankyborders"
    "hosts/common/darwin/optional/services/sketchybar"
    "hosts/common/darwin/optional/services/colima"
    "hosts/common/darwin/optional/services/litra"
    "hosts/common/darwin/optional/services/synergy"
    "hosts/common/darwin/optional/services/tailscale"

    #################### Users to Manage ####################
    "home/${configVars.username}/persistence/macbookpro.nix"
    "hosts/common/users/${configVars.username}/darwin.nix"
  ]);

  # Enable local SSH ONLY with keys
  services.openssh.enable = lib.mkForce true;
  services.openssh.extraConfig = "PasswordAuthentication no";

  # Per-host sketchybar customization. UUIDs are repo-safe (no PII);
  # discover yours with `icalBuddy calendars`. See
  # hosts/common/darwin/optional/services/sketchybar/default.nix for
  # the option definitions.
  services.sketchybar.personalizedOptions = {
    calendars = [
      "684D9DAB-74E3-42D4-AA64-BEA3F8165EC9" # Personal
      "CD6E7A4E-53C2-4A31-88CF-E240FFD36576" # Family
      "20B53EC0-1CB6-4014-8149-8E46D1757A59" # Work
    ];
    # Clicking the clock or calendar widget on this host opens TickTick
    # instead of Apple Calendar. Bundle ID is more robust than `open -a` if
    # the app is ever renamed or moved.
    clockClickCommand = "open -b com.TickTick.task.mac";
    # repoPath uses the conventional default
    #   /Users/<configVars.username>/Projects/<configVars.handle>/nix-config
    # which matches this host. Set explicitly only if the checkout moves.
    enableLedDevicesWidget = true;
  };

  # Litra Glow control — auto-start litra-autotoggle on login + sketchybar
  # widget to suspend/resume. See hosts/common/darwin/optional/services/litra/.
  services.litra.enable = true;

  # Watches macOS notification delivery via /usr/bin/log stream and fires the
  # corresponding `notify-blink <source>` for each matched bundle. Keys must
  # match `services.notification-leds.sources` (in shared HM config) so the
  # LED actually has a color/device mapping to use.
  services.notification-watcher = {
    enable = true;
    sources = {
      slack = {
        bundleIds = [ "com.tinyspeck.slackmacgap" ];
        # When slk-watcher's background tmux session is alive, slk-watcher
        # drives Slack LEDs with content-aware colours. Yield to it here so
        # both agents don't fire on the same notification.
        inhibitWhenTmuxSession = "slk-bg";
      };
      email.bundleIds = [ "com.apple.mail" ];
      calendar.bundleIds = [
        "com.apple.iCal"
        "com.TickTick.task.mac"
      ];
    };
  };

  # Polls slk's SQLite message cache for new messages matching patterns and fires
  # notify-blink sources distinct from the generic Slack notification.
  #
  # Requires slk to be open (the TUI syncs the cache; the watcher reads it).
  # When slk is closed, notification-watcher provides the generic red fallback.
  #
  # Source names must exist in `services.notification-leds.sources` (configured in
  # home/tdoggett/common/optional/notification-leds.nix).
  services.slk-watcher = {
    enable = true;
    # Check every 30 seconds — responsive without hammering the SQLite file.
    pollInterval = 30;
    # Don't re-fire the same source within 60 seconds of the last firing.
    cooldown = 60;
    # Fire the generic slack source for every new message so slk is the sole
    # LED driver when running. notification-watcher yields to this via
    # inhibitWhenTmuxSession above; when slk stops, notification-watcher
    # resumes driving the generic red blink automatically.
    defaultSource = "slack";
    sources = {
      # Orange blink when directly @-mentioned or a broadcast goes out.
      # TODO: fill in your Slack user ID. Find it while slk has synced some channels:
      #   sqlite3 ~/.local/share/slk/cache.db \
      #     "SELECT id, name, display_name FROM users WHERE name LIKE '%tdoggett%';"
      # Once you appear in the cache (after sending a message slk has fetched):
      #   sqlite3 ~/.local/share/slk/cache.db \
      #     "SELECT DISTINCT u.id, u.name FROM messages m JOIN users u ON m.user_id = u.id WHERE u.name = 'tdoggett';"
      mention = {
        handles = [
          # "U0YOURSLACKID"   ← replace with your actual Slack user ID
        ];
        patterns = [
          "@here"
          "@channel"
        ];
        notifySource = "slack-mention";
      };

      # Magenta blink on high-urgency keywords. Extend this list as needed.
      urgent = {
        keywords = [
          "urgent"
          "outage"
          "P0"
          "SEV0"
          "SEV1"
          "on fire"
          "ASAP"
        ];
        notifySource = "slack-urgent";
      };
    };

    # Keep slk running in a detached tmux session so the message cache stays
    # fresh even when no interactive terminal has slk open.
    #
    # Presence is safe: slk uses batch_presence_aware=1 + connect_only=true
    # on its WebSocket — Slack won't mark you active just because slk is connected.
    #
    # To interact with the running TUI at any time:
    #   tmux attach -t slk-bg     # attach your terminal to the background session
    #   Ctrl-b d                   # detach (slk stays running)
    background.enable = true;
  };

  networking.hostName = configVars.networking.work.macbookpro.name;

  system.primaryUser = configVars.username;

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    appleFonts.sf-pro-nerd
    appleFonts.sf-mono-nerd
  ];

  # Once synergy is actually working on Comsic we can re-enable this, but until then it
  # makes sense to not have a useless service just sitting open
  # services.synergy.server.enable = false;

  # Remember to use unstable for packages that should be kept up-to-date.
  # If the most recent unstable package version can't satisfy the work auto-updater
  # be certain to add the package name to the list of
  # `externallyManagedPackageNames` at the top of this file and remove it from this
  # list and use the system services to keep it updated for you.
  environment.systemPackages = [
    # Graphical Programs
    pkgs.unstable.iterm2
    pkgs.unstable.obsidian
    pkgs.unstable.podman-desktop
    pkgs.unstable.postman
    pkgs.unstable.protonmail-bridge
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.zed-editor

    # Terminal Programs
    pkgs.awscli2
    pkgs.kubectl # same as kubernetes-cli
    pkgs.libaom
    pkgs.libass
    pkgs.libassuan
    pkgs.oath-toolkit
    pkgs.openjdk11 # Why do I need version 11? What is this for?
    pkgs.uv # Python Env/Pkg Manager
  ];
  assertions =
    let
      forbidden = lib.filter (
        pkg: lib.elem (lib.getName pkg) externallyManagedPackageNames
      ) config.environment.systemPackages;
    in
    [
      {
        assertion = forbidden == [ ];
        message = ''
          These packages are managed by work services and kept up to date FAR sooner than
          nixpkgs-unstable allows, so we cannot install them via Nix so that the security
          of this system remains appropriate to what its owners demand.  You must remove
          the following packages from environment.systemPackages:

          ${lib.concatMapStringsSep "\n" lib.getName forbidden}
        '';
      }
    ];

  system.defaults.dock.autohide = true;
  system.defaults.dock.orientation = "right";
  system.defaults.dock.showhidden = true;
  system.defaults.dock.expose-group-apps = true;
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
