###############################################################################
#
#  Smeagol - Desktop
#  NixOS running on Personal AMD Desktop Machine - Dual Booting
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
      ./hardware-configuration.nix # Note that this only describes WSL stuff!

      ########################## Hardware Modules ###############################
      # No hardware to define!

      ########################### Impermanence ##################################
      # ./persistence.nix

      ############################## Stylix #####################################
      inputs.stylix.nixosModules.stylix
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      # "hosts/common/optional/boot/plymouth.nix"
      "hosts/common/optional/boot/regular_boot.nix" # Don't use with Lanzaboote!
      "hosts/common/optional/services/comfyui/default.nix"
      "hosts/common/optional/services/flatpak.nix"
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/ollama.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/services/pipewire.nix" # audio
      "hosts/common/optional/services/printing.nix"
      "hosts/common/optional/alvr.nix"
      "hosts/common/optional/cross-compiling.nix"
      "hosts/common/optional/gnome.nix"
      "hosts/common/optional/nvidia.nix"
      "hosts/common/optional/steam.nix"
      "hosts/common/optional/vr.nix"

      #################### Users to Create ####################
      # "home/${configVars.username}/persistence/smeagol.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  # Comfy Models
  # You must on the initial usage of the comfyui optional module NOT load any remote models
  # so that the tokens are injected into the nix-daemon systemd job
  # services.comfyui.models = lib.mkForce []; # Use this before the sops-nix secrets are loaded
  services.comfyui.symlinkPaths = {
    checkpoints = "/var/lib/stable-diffusion/models/linked/checkpoints";
    loras = "/var/lib/stable-diffusion/models/linked/loras";
  };
  services.comfyui.comfyuimini.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # Open-WebUI is a web-frontend for chatting with ollama
  services.open-webui.enable = true;
  services.open-webui.host = "0.0.0.0";

  # Prevent GreetD from using Hyprland as it's not being used right now
  services.greetd.settings.default_session.command =
    "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --time";

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "smeagol";
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall.enable = false;
  };

  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    glibcLocales
    gparted
    gnumake
    nodejs
    p7zip
    yt-dlp
    samba
    screen
    unrar
    unzip
    vim
    wget
  ];

  # Run AppImages directly
  programs.appimage.binfmt = true;

  # Security
  security.sudo.wheelNeedsPassword = false;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
