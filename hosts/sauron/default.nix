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
  services.ollama.loadModels = [ "mistral-large" ];
  services.ollama.acceleration = "cuda";

  # I'm not currently running persistence on the RasPi! RAM is too limited.
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
