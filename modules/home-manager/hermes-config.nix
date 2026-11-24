{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.hermes;

  # Generate a Python script that merges plugin config into Hermes config files
  hermesPluginMerge = pkgs.writeScript "hermes-plugin-merge" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import sys
    import json
    import yaml
    from pathlib import Path

    config_path = Path(sys.argv[1])
    plugins_enabled = json.loads(sys.argv[2])

    # Read existing config or start with empty dict
    if config_path.exists():
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f) or {}
    else:
        config = {}

    # Update plugins section
    if 'plugins' not in config:
        config['plugins'] = {}
    config['plugins']['auto_apply'] = True
    config['plugins']['enabled'] = plugins_enabled

    # Write back
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    config_path.chmod(0o600)
  '';
in
{
  options.programs.hermes = {
    enable = lib.mkEnableOption "Hermes agent configuration management";

    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            plugins = {
              enabled = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "List of plugins to enable for this profile";
                example = [
                  "next-prompt"
                  "herald-push"
                ];
              };
            };
          };
        }
      );
      default = { };
      description = "Hermes profile configurations (declaratively manages plugins)";
      example = {
        default.plugins.enabled = [
          "next-prompt"
          "herald-push"
        ];
        worker.plugins.enabled = [
          "next-prompt"
          "herald-push"
          "extra-work-budget"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # Map each profile to its config file location
      profileConfigs = {
        default = "${config.home.homeDirectory}/.hermes/config.yaml";
      }
      // lib.mapAttrs (_name: _: "${config.home.homeDirectory}/.hermes/profiles/${_name}/config.yaml") (
        lib.filterAttrs (name: _: name != "default") cfg.profiles
      );

      # Build activation commands to merge plugin config into existing configs
      activationCommands = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          profileName: profileCfg:
          let
            configPath = profileConfigs.${profileName};
            pluginsJson = builtins.toJSON profileCfg.plugins.enabled;
          in
          "run ${hermesPluginMerge} ${lib.escapeShellArg configPath} ${lib.escapeShellArg pluginsJson}"
        ) cfg.profiles
      );
    in
    {
      home.activation.hermesPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] activationCommands;
    }
  );
}
