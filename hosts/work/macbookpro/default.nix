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
      slack.bundleIds = [ "com.tinyspeck.slackmacgap" ];
      email.bundleIds = [ "com.apple.mail" ];
      calendar.bundleIds = [
        "com.apple.iCal"
        "com.TickTick.task.mac"
      ];
    };
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
    pkgs.bleeding.vscode
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
