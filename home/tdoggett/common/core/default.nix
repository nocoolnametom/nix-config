{
  config,
  configVars,
  lib,
  pkgs,
  outputs,
  configLib,
  ...
}:
{
  imports = (configLib.scanPaths ./.) ++ (builtins.attrValues outputs.homeModules);

  home = {
    username = lib.mkDefault configVars.username;
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "25.05";
    sessionPath = [
      # Add to the user's $PATH
      # "$HOME/.local/bin"
    ];
    sessionVariables = {
      TERM = "kitty";
      TERMINAL = "kitty";
      EDITOR = "vim";
    };
  };

  home.packages = builtins.attrValues {
    inherit (pkgs)

      # Packages that don't have custom configs go here
      sops # secrets encryption
      coreutils # basic gnu utils
      nix-tree # nix package tree viewer
      pciutils
      p7zip # compression & encryption
      ripgrep # better grep
      tree # cli dir tree viewer
      unzip # zip extraction
      unrar # rar extraction
      wget # downloader
      zip # zip compression
      gnumake # make
      ;
  };

  # JSON pretty printer and manipulator
  programs.jq.enable = true;

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  # shell aliases for interactive shells (available via Home Manager)
  programs.bash.initExtra = lib.mkDefault ''
    # Provide ag alias that uses rg so my finger memory continues to work
    alias ag='rg --smart-case'
  '';
  programs.zsh.shellAliases.ag = "rg --smart-case";

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  programs = {
    home-manager.enable = true;
  };
}
