###############################################################################
#
#  Pangolin11 - Laptop
#  NixOS running on System76 Pangolin11 AMD Laptop
#
###############################################################################

{
  inputs,
  pkgs,
  configLib,
  config,
  ...
}:
{
  imports =
    [
      ######################## Every Host Needs This ############################
      ./hardware-configuration.nix

      ########################## Hardware Modules ###############################
      inputs.hardware.nixosModules.system76

      ########################### Impermanence ##################################
      ./persistence.nix

      ############################## Stylix #####################################
      inputs.stylix.nixosModules.stylix # Must also use the config below

      ##################### Cosmic Desktop Enviornment ##########################
      inputs.nixos-cosmic.nixosModules.default # Must also use the config below

      #TODO move pangolin11 to disko
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/boot/hibernation.nix"
      "hosts/common/optional/boot/plymouth.nix"
      "hosts/common/optional/boot/silent.nix"
      # "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/services/pipewire.nix" # audio
      "hosts/common/optional/services/printing.nix"
      "hosts/common/optional/services/flatpak.nix"
      "hosts/common/optional/blinkstick.nix"
      "hosts/common/optional/cosmic.nix" # System76 Cosmis Desktop Environment
      "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it
      # "hosts/common/optional/hyprland.nix" # Hyprland, includes some related services
      "hosts/common/optional/light.nix" # Monitor brightness
      # "hosts/common/optional/plasma6.nix"
      # "hosts/common/optional/sddm.nix"
      "hosts/common/optional/steam.nix"
      "hosts/common/optional/stylix.nix" # System-wide styling
      # "hosts/common/optional/sway.nix"
      "hosts/common/optional/yubikey.nix"
      # "hosts/common/optional/xfce.nix"

      #################### Users to Create ####################
      "hosts/common/users/tdoggett"
      "home/tdoggett/pangolin11/persistence.nix"
    ]);

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

  # Auto-login through Greetd and TuiGreet to Hyprland
  # autoLogin.enable = true;
  # autoLogin.username = "tdoggett";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # Hardware
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Enable Powertop
  powerManagement.enable = true;
  powerManagement.powertop.enable = true; # Should work fine with system76-power

  # Security
  security.sudo.wheelNeedsPassword = false;
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

  system.stateVersion = "24.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}