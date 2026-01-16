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
    "google-chrome"
    "google-chrome-beta"
    "google-chrome-canary"
  ];
in {
  imports = [
    ######################## Direct Imports for MBP ############################
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/darwin/core"

    #################### Host-specific Optional Configs ####################
    # Be very careful, most of these are meant for NixOS, not Darwin!
    "hosts/common/optional/direnv.nix"
    "hosts/common/optional/tmux.nix"
    "hosts/common/optional/yubikey.nix"
    "hosts/common/darwin/optional/homebrew"
    "hosts/common/darwin/optional/services/aerospace"
    "hosts/common/darwin/optional/services/dnsmasq"
    # This can be re-enabled once nixpkgs gets the new Mac compilation stuff for Tahoe working
    # "hosts/common/darwin/optional/services/jankyborders"
    "hosts/common/darwin/optional/services/sketchybar"
    "hosts/common/darwin/optional/services/synergy"
    "hosts/common/darwin/optional/services/tailscale"

    #################### Users to Manage ####################
    "home/${configVars.username}/persistence/macbookpro.nix"
    "hosts/common/users/${configVars.username}/darwin.nix"
  ]);

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
    pkgs.unstable.code-cursor
    pkgs.unstable.iterm2
    pkgs.unstable.obsidian
    pkgs.unstable.podman-desktop
    pkgs.unstable.postman
    pkgs.unstable.protonmail-bridge
    pkgs.unstable.protonmail-desktop
    pkgs.unstable.sequelpro
    pkgs.unstable.slack
    pkgs.unstable.tableplus
    pkgs.unstable.vscode
    pkgs.unstable.zed-editor
    pkgs.unstable.zoom-us

    # Terminal Programs
    pkgs.unstable.claude-code
    pkgs.awscli2
    pkgs.kubectl # same as kubernetes-cli
    pkgs.libaom
    pkgs.libass
    pkgs.libassuan
    pkgs.oath-toolkit
    pkgs.openjdk11 # Why do I need version 11? What is this for?
    pkgs.uv # Python Env/Pkg Manager
  ];
  assertions = let
    forbidden = lib.filter (pkg: lib.elem (lib.getName pkg) externallyManagedPackageNames) config.environment.systemPackages;
  in [{
    assertion = forbidden == [];
    message = ''
      These packages are managed by work services and kept up to date FAR sooner than
      nixpkgs-unstable allows, so we cannot install them via Nix so that the security
      of this system remains appropriate to what its owners demand.  You must remove
      the following packages from environment.systemPackages:

      ${lib.concatMapStringsSep "\n" lib.getName forbidden}
    '';
  }];

  # There is no system-level vim management for NixOS, only darwin
  # TODO: See if I can move this into home-manager instead
  programs.vim.enable = true;
  programs.vim.enableSensible = true;

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
