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
    ++ [
      # Ensure we've loaded the Home Manager module
      inputs.home-manager.nixosModules.home-manager

      # Use the determinate module
      inputs.determinate.nixosModules.default
    ]
    ++
      # Custom nixosModules as defined in the root flake
      (builtins.attrValues outputs.nixosModules);

  # Use the Community and Hyprland Cache
  nix.settings.substituters = [
    "https://hyprland.cachix.org"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-substituters = [
    "https://hyprland.cachix.org"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Deduplicate and optimize nix store
  nix.optimise.automatic = true;

  # Garbage Collection
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 10d";

  # Set the nix builder to always use the daemon so that any environment
  # variables on nix-daemon are present for builders
  # If this seems to be causing issues, change it to empty string
  environment.sessionVariables.NIX_REMOTE = lib.mkDefault "daemon";

  # Set up the root user (uses secrets from nix-secrets and ./sops.nix)
  users.users.root = {
    # Use the same hashedPassword or defined password as the main username has
    hashedPassword = config.users.users.${configVars.username}.hashedPassword;
    password = lib.mkForce config.users.users.${configVars.username}.password;
    openssh.authorizedKeys.keys = config.users.users.${configVars.username}.openssh.authorizedKeys.keys;
  };

  # Ensure these tools are available for all users, even if it's just root on the system
  programs.zsh.enable = true;
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

  # Turn on the firewall by default
  networking.firewall.enable = lib.mkDefault true;

  # Restrict sudo to only the wheel group by default
  security.sudo.execWheelOnly = lib.mkDefault true;

  # Only allow sudoers to use nix
  # This is here and not in nix.nix because I don't know if it works with darwin, which autoloads nix.nix
  nix.settings.allowed-users = [ "@wheel" ];

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
