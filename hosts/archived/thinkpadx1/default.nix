###############################################################################
#
#  Thinkpadx1 - Laptop (ARCHIVED)
#  NixOS running on Lenovo Thinkpad X1 Extreme 1st Generation
#
#  This configuration is archived and no longer in active use.
#  It is maintained for reference purposes only.
#
###############################################################################

{
  inputs,
  pkgs,
  lib,
  configLib,
  config,
  configVars,
  ...
}:
{
  imports = [
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ########################## Hardware Modules ###############################
    inputs.hardware.nixosModules.lenovo-thinkpad-x1-extreme

    ########################### Impermanence ##################################
    ./persistence.nix

    ############################ Lanzaboote ###################################
    inputs.lanzaboote.nixosModules.lanzaboote # Must also use the config below

    ############################## Stylix #####################################
    inputs.stylix.nixosModules.stylix
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/boot/hibernation.nix"
    "hosts/common/optional/boot/plymouth.nix"
    "hosts/common/optional/boot/silent.nix"
    "hosts/common/optional/services/greetd.nix"
    "hosts/common/optional/services/openssh.nix" # allow remote SSH access
    "hosts/common/optional/services/pipewire.nix" # audio
    "hosts/common/optional/services/printing.nix"
    "hosts/common/optional/blinkstick.nix"
    "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
    "hosts/common/optional/light.nix" # Monitor brightness
    "hosts/common/optional/steam.nix"
    "hosts/common/optional/thunar.nix" # Thunar File-Browser
    "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it
    "hosts/common/optional/yubikey.nix"
    "hosts/common/optional/stylix.nix" # System-wide styling

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/thinkpadx1.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Mark this system as deprecated
  system.deprecation = {
    isDeprecated = true;
    reason = "Hardware no longer in use";
    deprecatedSince = "2024-06";
    lastKnownGoodBuild = "c3cb053";
    replacedBy = "";
  };

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "thinkpadx1";
    networkmanager.enable = true;
    enableIPv6 = true;
  };

  # Stylix theme
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/github-dark.yaml";

  # Hardware
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Security
  security.apparmor.enable = true;

  # Optional, hint electron apps to use wayland:
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Use Gnomestuff outside of gnome (okay to enable this if gnome is enabled, too)
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
