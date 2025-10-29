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
{
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
    # We're using brew to manage dnsmasq
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

  environment.systemPackages = [
    pkgs.awscli2
    pkgs.kubectl # same as kubernetes-cli
    pkgs.libaom
    pkgs.libass
    pkgs.libassuan
    pkgs.oath-toolkit
    pkgs.openjdk11 # Why do I need version 11? What is this for?
    pkgs.uv # Python Env/Pkg Manager
  ];

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
