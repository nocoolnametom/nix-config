{
  pkgs,
  lib,
  config,
  inputs,
  outputs,
  configLib,
  configVars,
  ...
}:

{
  imports =
    # Load all sibling .nix files from hosts/common/core
    (configLib.scanPaths ./.)
    ++
      # Ensure we've loaded the Home Manager module
      [ inputs.home-manager.nixosModules.home-manager ]
    ++
      # Custom nixosModules as defined in the root flake
      (builtins.attrValues outputs.nixosModules);

  # Set up the root user (uses secrets from nix-secrets and ./sops.nix)
  users.users.root = {
    # Use the same hashedPassword or defined password as the main username has
    hashedPassword = config.users.users.${configVars.username}.hashedPassword;
    password = lib.mkForce config.users.users.${configVars.username}.password;
  };

  # Ensure these tools are available for all users, even if it's just root on the system
  programs.zsh.enable = true;
  programs.git.enable = true;
  environment.systemPackages = [
    pkgs.rsync
    pkgs.wget
    pkgs.vim
    pkgs.git # Needed for flakes!
    pkgs.nixfmt-rfc-style
    pkgs.nil
    pkgs.screen
    pkgs.unrar
    pkgs.unzip
  ];

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

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
