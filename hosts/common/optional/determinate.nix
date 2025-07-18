{
  inputs,
  lib,
  configVars,
  ...
}:
{
  imports = [
    # Use the determinate module
    inputs.determinate.nixosModules.default
  ];

  # Needed since Determinate Nix manages the main config file for system.
  environment.etc."nix/nix.custom.conf".text = lib.mkDefault ''
    # Written by https://github.com/DeterminateSystems/nix-installer.
    # The contents below are based on options specified at installation time.
    trusted-users = ${configVars.username}
    lazy-trees = true
  '';
}
