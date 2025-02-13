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
      "hosts/common/optional/cross-compiling.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/sauron.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  services.ollama.enable = true;
  services.ollama.package = pkgs.unstable.ollama;
  services.ollama.loadModels = [
    # Models higher than 9GB will use CPU with GPU, less will be entirely on GPU
    # You CAN get a model up to ~40GB, but it'll mostly be CPU driven and slow.
    #  4.9 GB  2025-01-25
    "huihui_ai/deepseek-r1-abliterated:8b"
    #  9.0 GB  2025-01-24
    "huihui_ai/deepseek-r1-abliterated:14b"
    #  4.9 GB  2025-01-08
    "huihui_ai/dolphin3-abliterated:8b"
    #  9.1 GB  2025-01-09
    "huihui_ai/phi4-abliterated:14b" # Requires ollama 0.5.5+, which is why we're using unstable
    #  4.7 GB  2025-01-28
    "huihui_ai/qwen2.5-1m-abliterated:7b"
    #  9.0 GB  2025-01-28
    "huihui_ai/qwen2.5-1m-abliterated:14b"
    #  8.6 GB  2024-05-01
    "superdrew100/phi3-medium-abliterated"
    #  4.9 GB  2025-01-21
    "deepseek-r1:8b"
    #  9.0 GB  2025-01-21
    "deepseek-r1:14b"
    #  4.9 GB  2024-12-29
    "dolphin3:8b"
    #  4.7 GB  2024-05-20
    "dolphin-llama3:8b"
    #  4.1 GB  2024-03-01
    "dolphin-mistral:7b"
    #  1.6 GB  2023-12-24
    "dolphin-phi:2.7b"
    #  5.0 GB  2025-01-18
    "granite3.1-dense:8b"
    #  4.9 GB  2024-11-01
    "llama3.1:8b"
    #  2.0 GB  2024-09-01
    "llama3.2:3b"
    #  4.1 GB  2023-12-12
    "mistral:7b"
    #  7.1 GB  2024-07-18
    "mistral-nemo:12b"
    # 13.0 GB  2024-09-01
    "mistral-small:22b"
    #  8.4 GB 2025-01-16
    "olmo2:13b"
    #  9.1 GB  2025-01-01
    "phi4:14b"
  ];
  services.ollama.acceleration = "cuda";
  # The existing systemd job is SO tightened down that it can't read the WSL drivers AT ALL
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
