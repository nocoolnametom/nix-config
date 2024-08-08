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
    # Use the same hashedPasswordFile or defined password as the main username has
    hashedPasswordFile = config.users.users.${configVars.username}.hashedPasswordFile;
    password = lib.mkForce config.users.users.${configVars.username}.password;
    # Use the same SSH public keys as the main username if, for some odd reason, SSH root login is active (it shouldn't ever be, though)
    # TODO Not working? openssh.authorizedKeys.keys = config.users.users.${configVars}.openssh.authorizedKeys.keys;
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

  #TODO Maybe font stuff needs to be moved to Home Manager?
  # Font management
  fonts.packages = with pkgs; [
    cascadia-code
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override {
      fonts = [
        "NerdFontsSymbolsOnly"
        "FiraCode"
        "DroidSansMono"
      ];
    })
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

    config.allowUnfree = true;
  };

  hardware.enableRedistributableFirmware = true;
}
