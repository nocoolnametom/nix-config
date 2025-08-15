{
  pkgs,
  lib,
  config,
  inputs,
  outputs,
  configLib,
  configVars,
  configurationRevision,
  ...
}:

{
  imports =
    # Load all sibling .nix files from hosts/common/core
    (configLib.scanPaths ./.)
    ++
      # Load specific common core modules (sops must be handled in home-manager!)
      (map configLib.relativeToRoot [
        "hosts/common/core/bash.nix"
        "hosts/common/core/nix.nix"
        "hosts/common/core/zsh.nix"
      ])
    ++ [
      # Ensure we've loaded the Home Manager module
      inputs.home-manager.darwinModules.home-manager

      # Load the sops module
      inputs.sops-nix.darwinModules.sops
    ]
    ++
      # Custom darwinModules as defined in the root flake
      (builtins.attrValues outputs.darwinModules);

  # Note that we do not do user management on our darwin systems!

  # Ensure these tools are available for all users, even if it's just root on the system
  environment.systemPackages = [
    pkgs.wget
    pkgs.git # Needed for flakes!
    pkgs.git-lfs
    pkgs.nixfmt-rfc-style
    pkgs.dnsmasq
    pkgs.docutils
    pkgs.mkcert
    # pkgs.openssh # Need to make sure launchctl is switched first!
  ];

  programs.zsh.interactiveShellInit = ''
    bindkey '^[[1;5D' backward-word
    bindkey '^[[1;5C' forward-word
  '';

  environment.shellAliases = {
    darwin-rebuild-switch = "darwin-rebuild switch --flake ~/.config/nix-darwin";
    darwin-rebuild-build = "darwin-rebuild build --flake ~/.config/nix-darwin";
    darwin-rebuild-check = "darwin-rebuild build --flake ~/.config/nix-darwin";
    rm = "rm -i";
    cp = "cp -i";
    ls = "ls -G";
  };

  # Ensure HM has access to all outputs of the root flake (like configVars)
  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };

  nixpkgs = {
    overlays =
      # We can add global overlays here
      [ ]
      # Include the overlays from the root flake
      ++ builtins.attrValues outputs.overlays;

    config.allowUnfree = lib.mkDefault true;
  };

  # System settings
  system.defaults.dock.show-recents = lib.mkDefault false;
  system.defaults.finder.AppleShowAllExtensions = lib.mkDefault true;
  system.defaults.finder.ShowPathbar = lib.mkDefault true;
  system.keyboard.enableKeyMapping = lib.mkDefault true;
  system.keyboard.remapCapsLockToControl = lib.mkDefault true;

  # We use the determinate installer for nix on darwin
  # It lasts/recovers far more easily through OS updates
  nix.enable = false;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = configurationRevision;
}
