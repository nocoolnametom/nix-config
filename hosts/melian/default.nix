###############################################################################
#
#  Melian - Laptop
#  NixOS running on Asus Zenbook 13 UX331U Utrabook
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
  imports =
    [
      ######################## Every Host Needs This ############################
      ./hardware-configuration.nix

      ########################## Hardware Modules ###############################
      inputs.hardware.nixosModules.asus-zenbook-ux371
      # Double-check this? There's no other zenbook module, but this is a different model

      ########################### Impermanence ##################################
      ./persistence.nix

      ############################## Stylix #####################################
      inputs.stylix.nixosModules.stylix
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/boot/plymouth.nix"
      "hosts/common/optional/boot/silent.nix"
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/services/pipewire.nix" # audio
      "hosts/common/optional/services/printing.nix"
      "hosts/common/optional/blinkstick.nix"
      "hosts/common/optional/light.nix" # Monitor brightness
      "hosts/common/optional/steam.nix"
      "hosts/common/optional/thunar.nix" # Thunar File-Browser
      "hosts/common/optional/hyprland.nix" # Hyprland, includes some related services
      "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/stylix.nix" # System-wide styling

      #################### Users to Create ####################
      "hosts/common/users/${configVars.username}"
      "home/${configVars.username}/melian/persistence.nix"
    ]);

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "melian";
    networkmanager.enable = true;
    enableIPv6 = true;
  };

  # Stylix wallpaper
  stylix.image = pkgs.fetchurl {
    url = "https://codeberg.org/exorcist/wallpapers/raw/branch/master/gruvbox/cottage.jpg";
    sha256 = "sha256-NUDGJ13fF+0AZAFcN6HoiuaPhewsfwQ65FRXvuB7rKo=";
  };
  #stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/monokai.yaml";
  #stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";

  # Auto-login through Greetd and TuiGreet to Hyprland
  autoLogin.enable = true;
  autoLogin.username = configVars.username;

  # Use the systemd-boot EFI boot loader. Remove when lanzaboot is set up.
  boot.loader.systemd-boot.enable = true;
  boot.lanzaboote.enable = false; # Still need to set up keys and such for Secure Boot
  # boot.loader.systemd-boot.enable = false; # We're using Lanzaboote for Secure Boot
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

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

  system.stateVersion = "24.11";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
