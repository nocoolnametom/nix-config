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
      "hosts/common/optional/determinate.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/sauron.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  services.ollama.enable = true;
  services.ollama.package = pkgs.unstable.ollama;
  services.ollama.loadModels = [
    # Models higher than 9GB will use CPU with GPU, less will be entirely on GPU
    # You CAN get a model up to ~40GB, but it'll mostly be CPU driven and slow.
    # YC = Can talk about Chinese censored info, NC = Chinese info blocked
    # YA = Can talk about upsetting info, NA = Will refuse talk about it
    #  4.9 GB  2025-02-19  YC  YA - Very talkative
    "huihui_ai/deephermes3-abliterated"
    #  1.5 GB  2025-02-14  NC  NA - Usually refuses, sometimes ignores the upsetting aspects
    "huihui_ai/deepscaler-abliterated"
    #  4.9 GB  2025-01-25  NC  YA - Semi-talktative, talks around upsetting subjects
    "huihui_ai/deepseek-r1-abliterated"
    #  4.9 GB  2025-01-08  YC  YA - Talkative
    "huihui_ai/dolphin3-abliterated"
    #  9.1 GB  2025-01-09  YC  YA - Semi-talkative, talks around and ignores upsetting stuff
    "huihui_ai/phi4-abliterated" # Requires ollama 0.5.5+, which is why we're using unstable
    #  4.7 GB  2025-01-28  YC  YA - Usually refuses, sometimes is talkative
    "huihui_ai/qwen2.5-1m-abliterated"
    #  8.6 GB  2024-05-01  YC  YA - Semi-talkative, often ignores upsetting aspects
    "superdrew100/phi3-medium-abliterated"
    #  4.9 GB  2025-01-21  NC  NA
    "deepseek-r1"
    #  4.9 GB  2024-12-29  YC  YA - Semi-talkative
    "dolphin3"
    #  4.7 GB  2024-05-20  YC  YA - Talkative
    "dolphin-llama3"
    #  4.1 GB  2024-03-01  YC  YA - Talkative
    "dolphin-mistral"
    #  5.0 GB  2025-01-18  YC  YA - Talkative
    "granite3.1-dense"
    #  4.9 GB  2024-11-01  YC  NA
    "llama3.1"
    #  2.0 GB  2024-09-01  YC  NA
    "llama3.2"
    #  7.1 GB  2024-07-18  YC  YA - Very talkative
    "mistral-nemo"
    # 13.0 GB  2024-09-01  YC  NA
    "mistral-small"
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

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
