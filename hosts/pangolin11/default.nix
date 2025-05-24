###############################################################################
#
#  Pangolin11 - Laptop
#  NixOS running on System76 Pangolin11 AMD Laptop
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
      #inputs.hardware.nixosModules.system76

      ########################### Impermanence ##################################
      ./persistence.nix

      ############################ Lanzaboote ###################################
      inputs.lanzaboote.nixosModules.lanzaboote # Must also use the config below

      ############################## Stylix #####################################
      inputs.stylix.nixosModules.stylix # Must also use the config below
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
      "hosts/common/optional/services/flatpak.nix"
      "hosts/common/optional/adb.nix" # Android Debugging
      "hosts/common/optional/blinkstick.nix"
      "hosts/common/optional/cross-compiling.nix"
      "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it
      "hosts/common/optional/hyprland.nix" # Hyprland, includes some related services
      "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
      "hosts/common/optional/light.nix" # Monitor brightness
      "hosts/common/optional/steam.nix"
      "hosts/common/optional/stylix.nix" # System-wide styling
      "hosts/common/optional/thunar.nix" # Thunar File-Browser
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/vr.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/pangolin11.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  # services.gotosocial.settings.landing-page-user = "tom";

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "pangolin11";
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall = {
      allowedTCPPortRanges = [
        {
          # KDE Connect
          from = 1714;
          to = 1764;
        }
        {
          # mDNS
          from = 5353;
          to = 5353;
        }
      ];
      allowedUDPPorts = [
        51820 # Wireguard
      ];
      allowedUDPPortRanges = [
        {
          # KDE Connect
          from = 1714;
          to = 1764;
        }
      ];
    };
  };

  # Stylix wallpaper
  stylix.image = pkgs.fetchurl {
    url = "https://www.pixelstalk.net/wp-content/uploads/images8/A-nyugalom-sarka-HD-Backgrounds-Green.jpg";
    sha256 = "sha256-sYaK25CuA9EjKJWl3bSJwd3zZypIrx9jx7lepAIjFV0=";
  };
  #stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/monokai.yaml";
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";

  environment.systemPackages = [
    pkgs.gparted
    pkgs.split-my-cbz
    pkgs.update-cbz-tags
  ];

  # Hardware
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Enable Powertop
  powerManagement.enable = true;
  powerManagement.powertop.enable = true; # Should work fine with system76-power

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
