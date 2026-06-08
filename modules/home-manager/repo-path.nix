{
  lib,
  pkgs,
  configVars,
  osConfig ? null,
  ...
}:
# Home-manager mirror of the NixOS / nix-darwin `repoPath` option.
# When running as a module of NixOS or nix-darwin (the common case here),
# defaults to the parent system's `osConfig.repoPath` so per-host overrides
# at the system level automatically flow through to HM.
# For HM-only hosts (e.g. steamdeck), falls back to deriving from
# `configVars.nixConfigPath.{darwin|linux}` directly.
{
  options.repoPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default =
      let
        fromSystem = if osConfig != null then osConfig.repoPath or null else null;
        fromVars =
          if pkgs.stdenv.isDarwin then
            configVars.nixConfigPath.darwin or null
          else
            configVars.nixConfigPath.linux or null;
      in
      if fromSystem != null then fromSystem else fromVars;
    defaultText = lib.literalExpression "osConfig.repoPath ?? configVars.nixConfigPath.{darwin|linux}";
    description = ''
      Absolute path to the nix-config working-tree checkout on this host.
      Used by tooling and widgets that want to link to editable source
      files instead of the read-only `/nix/store` source.

      Inherits from the parent system module's `config.repoPath` via
      `osConfig` when available; otherwise derives from
      `configVars.nixConfigPath.<darwin|linux>` (defined in
      `vars/default.nix`).
    '';
    example = "/Users/foo/Projects/nix-config";
  };
}
