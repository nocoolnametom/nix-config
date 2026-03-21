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

      # Load the stylix module - To use import the
      # common/optional/stylix.nix in your hosts file.
      inputs.stylix.nixosModules.stylix
    ]
    ++
      # Custom nixosModules as defined in the root flake
      (builtins.attrValues outputs.nixosModules);

  # Deduplicate and optimize nix store
  nix.optimise.automatic = true;

  # Garbage Collection
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 10d";

  # Console font - use Terminus for better readability in VT.
  # Use full store path so NixOS adds it to boot.initrd.systemd.storePaths,
  # making it available before activation sets up /etc/kbd (which happens ~5s
  # after systemd-vconsole-setup runs early in boot).
  console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
  console.packages = lib.mkDefault [ pkgs.terminus_font ];

  # Set the nix builder to always use the daemon so that any environment
  # variables on nix-daemon are present for builders
  # If this seems to be causing issues, change it to empty string
  environment.sessionVariables.NIX_REMOTE = lib.mkDefault "daemon";

  # Allow USB mounting
  services.udisks2.enable = true;

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
    pkgs.tmux
    pkgs.unrar
    pkgs.unzip
  ];

  # Ensure HM has access to all outputs of the root flake (like configVars)
  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };

  # Automatically import stylix home-manager module for all users
  home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];

  # If impermanence is enabled, force clobber conflicting files (safe since non-persisted files are wiped on boot)
  # Otherwise, use normal backup behavior
  # Check if persistence is enabled and the persist folder path exists
  home-manager.backupFileExtension = lib.mkIf (
    config.environment ? persistence && config.environment.persistence ? ${configVars.persistFolder}
  ) "backup";
  home-manager.backupCommand = lib.mkIf (
    config.environment ? persistence && config.environment.persistence ? ${configVars.persistFolder}
  ) "rm -f \"$1\"";

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

  # Allow wheel members to sudo without a password (can be overridden per-host)
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  # Enable AppArmor for mandatory access control (can be disabled per-host if it causes issues)
  security.apparmor.enable = lib.mkDefault true;

  # Don't build NixOS documentation — saves disk space and build time on all machines
  documentation.nixos.enable = lib.mkDefault false;

  # Only allow sudoers to use nix
  # This is here and not in nix.nix because I don't know if it works with darwin, which autoloads nix.nix
  nix.settings.allowed-users = [ "@wheel" ];

  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
