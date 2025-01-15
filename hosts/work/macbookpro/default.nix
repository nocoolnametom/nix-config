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
  imports =
    [
      ######################## Direct Imports for MBP ############################
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/darwin"

      #################### Host-specific Optional Configs ####################
      # Be very careful, most of these are meant for NixOS, not Darwin!
      "hosts/common/optional/direnv.nix"
      "hosts/common/optional/tmux.nix"
      "hosts/common/optional/yubikey.nix"

      #################### Users to Manage ####################
      "home/${configVars.username}/persistence/macbookpro.nix"
      "hosts/common/users/${configVars.username}/darwin.nix"
    ]);

  networking.hostName = configVars.networking.work.macbookpro.name;

  homebrew.enable = true;
  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "uninstall";
  homebrew.onActivation.upgrade = true;
  homebrew.brews = [
    { name = "openssh"; } # Need to make sure launchctl is switched first!
    { name = "tfenv"; } # No current nixpkgs
  ];
  homebrew.casks = [ ];
  homebrew.taps = [
    { name = "amar1729/formulae"; }
    { name = "homebrew/services"; }
  ];
  environment.systemPackages = [
    pkgs.awscli2
    pkgs.kubectl # same as kubernetes-cli
    pkgs.libaom
    pkgs.libass
    pkgs.libassuan
    pkgs.oath-toolkit
    pkgs.openjdk11 # Why do I need version 11? What is this for?
  ];

  # There is no system-level vim management for NixOS, only darwin
  # TODO: See if I can move this into home-manager instead
  programs.vim.enable = true;
  programs.vim.enableSensible = true;

  services.dnsmasq.enable = false; # Find out if we want this as a service or if teleport runs it manually
  services.dnsmasq.addresses = {
  } // configVars.work.dnsmasq.addresses;

  system.defaults.dock.autohide = false;
  system.defaults.dock.orientation = "right";
  system.defaults.dock.showhidden = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
