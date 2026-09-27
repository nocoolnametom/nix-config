{
  pkgs,
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/sops.nix
    common/optional/flatpak.nix
    common/optional/git.nix
    common/optional/jj.nix
    common/optional/devenv.nix
    common/optional/notification-leds.nix
    common/optional/smolcoder.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/atuin.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  programs.atuin.settings.sync_address = "http://${configVars.networking.subnets.estel.ip}:${
    toString configVars.networking.ports.tcp."atuin-sync"
  }";

  programs.git.settings.user.email = configVars.gitHubEmail;

  # Custom packages are already overlaid into the provided `pkgs`
  home.packages = with pkgs; [
    handbrake
  ];

  # Flatpaks
  services.flatpak.packages = [
    # Until I figure out how to do this headlessly, this is like Flowframes
    {
      appId = "io.github.tntwise.REAL-Video-Enhancer";
      origin = "flathub";
    }
    # Flat seal can help with file permissions
    {
      appId = "com.github.tchx84.Flatseal";
      origin = "flathub";
    }
  ];

  # smolcoder web UI — runs on barliman as a persistent user service.
  # Listens on 127.0.0.1 only; access from other machines via SSH tunnel:
  #   ssh -N -L 7433:127.0.0.1:7433 barliman
  # The auth URL changes every restart; retrieve it with `smolcoder-url`.
  systemd.user.services.smolcoder-web = {
    Unit = {
      Description = "smolcoder web UI (local LLM coding agent)";
      # Wait for Ollama to be ready before starting
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "${pkgs.smolcoder}/bin/smolcoder --web ${toString configVars.networking.ports.tcp.smolcoder} --mode edit";
      WorkingDirectory = "%h";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Quick alias to find the current URL+auth-token from the service journal
  home.shellAliases.smolcoder-url =
    "journalctl --user -u smolcoder-web --no-pager | grep 'smolcoder web UI' | tail -1 | grep -oP 'http://\\S+'";

  home = {
    stateVersion = "26.05";
    username = configVars.username;
    homeDirectory = lib.mkForce "/home/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
