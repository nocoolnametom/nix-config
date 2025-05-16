{
  inputs,
  config,
  lib,
  ...
}:
{
  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # See https://jackson.dev/post/nix-reasonable-defaults/
      connect-timeout = 5;
      log-lines = 25;
      min-free = 128000000; # 128MB
      max-free = 1000000000; # 1GB

      # You can override the default download buffer size in a host default config.
      # example of 64MB, the original default:
      # nix.settings.download-buffer-size = 67108864;
      download-buffer-size = lib.mkDefault 536870912; # 512MB

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      trusted-users = [
        "@wheel"
      ];
      warn-dirty = false;
    };

  };

  # Needed since Determinate Nix manages the main config file for system.
  environment.etc."nix/nix.custom.conf".text = lib.mkDefault ''
    # Written by https://github.com/DeterminateSystems/nix-installer.
    # The contents below are based on options specified at installation time.
    trusted-users = ${configVars.username}
    lazy-trees = true
  '';
}
