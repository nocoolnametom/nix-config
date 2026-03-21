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
    common/optional/desktops/kitty.nix
    common/optional/desktops/bluetooth-applet.nix
    common/optional/claude.nix
    common/optional/devenv.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  programs.git.settings.user.email = configVars.gitHubEmail;

  # Custom packages are already overlaid into the provided `pkgs`
  home.packages = with pkgs; [
    bottles
    handbrake
  ];

  # Flatpaks
  services.flatpak.packages = [
    # Until I figure out how to do this headlessly, this is like Flowframes
    {
      appId = "io.github.tntwise.REAL-Video-Enhancer";
      origin = "flathub";
    }
    {
      appId = "com.github.iwalton3.jellyfin-media-player";
      origin = "flathub";
    }
    # mupen64 frontend for N64 Emulation
    {
      appId = "com.github.Rosalie241.RMG";
      origin = "flathub";
    }
    # mGBA emulator
    {
      appId = "io.mgba.mGBA";
      origin = "flathub";
    }
    # PSP Emulator
    {
      appId = "org.ppsspp.PPSSPP";
      origin = "flathub";
    }
    # Flat seal can help with file permissions
    {
      appId = "com.github.tchx84.Flatseal";
      origin = "flathub";
    }
    # Doplhin Wii Emulation
    {
      appId = "org.DolphinEmu.dolphin-emu";
      origin = "flathub";
    }
    # Cemu WiiU Emulation
    {
      appId = "info.cemu.Cemu";
      origin = "flathub";
    }
    # NES Emulator
    {
      appId = "ca._0ldsk00l.Nestopia";
      origin = "flathub";
    }
    # Snes9x Emulator
    {
      appId = "com.snes9x.Snes9x";
      origin = "flathub";
    }
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = lib.mkForce "/home/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
