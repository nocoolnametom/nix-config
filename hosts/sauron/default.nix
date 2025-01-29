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
      ./hardware-configuration.nix # Note that this only describes WSL stuff!

      ########################## Hardware Modules ###############################
      # No hardware to define!

      ########################### Impermanence ##################################
      ./persistence.nix

      ############################## Stylix #####################################
      # inputs.stylix.nixosModules.stylix # No GUI on the RasPi
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/services/openssh.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/sauron.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  services.ollama.enable = true;
  services.ollama.loadModels = [
    # I have around 31GB of vram, so only use models less than 28-29GB
    "deepseek-r1-abliterated:14b"
    "deepseek-r1-abliterated:32b"
    "deepseek-r1:32b"
    "phi4:14b"
    "llama3.2:3b"
    "mistral-nemo:12b"
    "dolphin3:8b"
    "dolphin-mixtral:8x7b"
    "dolphin-llama3:8b"
    "dolphin-phi:2.7b"
  ];
  services.ollama.acceleration = "cuda";
  # The existing system is SO tightened down that it can't read the WSL drivers AT ALL
  systemd.services.ollama.serviceConfig = lib.mkForce {
    Type = "exec";
    ExecStart = "/run/current-system/sw/bin/ollama serve";
    WorkingDirectory = "/var/lib/ollama";
  };

  # I'm not currently running persistence on Sauron: the WSL aspect makes disk management hard
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "sauron";
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall.enable = false;
  };

  environment.systemPackages = with pkgs; [
    glibcLocales
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

  # Security
  security.sudo.wheelNeedsPassword = false;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "24.11";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
