###############################################################################
#
#  Thinkpadx1 - Laptop
#  NixOS running on Lenovo Thinkpad X1 Extreme 1st Generation
#
###############################################################################

{
  inputs,
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
      inputs.hardware.nixosModules.lenovo-thinkpad-x1-extreme

      ########################### Impermanence ##################################
      ./persistence.nix

      #TODO move thinkpadx1 to disko
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/services/pipewire.nix" # audio
      "hosts/common/optional/services/printing.nix"
      "hosts/common/optional/blinkstick.nix"
      "hosts/common/optional/light.nix" # Monitor brightness
      "hosts/common/optional/steam.nix"
      "hosts/common/optional/hyprland.nix" # Hyprland, includes some related services
      "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it

      #################### Users to Create ####################
      "hosts/common/users/tdoggett"
      "home/tdoggett/thinkpadx1/persistence.nix"
    ]);

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "thinkpadx1";
    networkmanager.enable = true;
    enableIPv6 = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  #TODO I'd like to load this from sops-nix nix-secrets instead...
  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
