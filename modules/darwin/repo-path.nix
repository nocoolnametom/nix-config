{
  lib,
  pkgs,
  configVars,
  ...
}:
# Cross-system "where does this machine's nix-config working-tree live?".
# Read it anywhere via `config.repoPath`. Override per-host if the checkout
# is in a non-standard location.
{
  options.repoPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default =
      if pkgs.stdenv.isDarwin then
        configVars.nixConfigPath.darwin or null
      else
        configVars.nixConfigPath.linux or null;
    defaultText = lib.literalExpression "configVars.nixConfigPath.{darwin|linux}";
    description = ''
      Absolute path to the nix-config working-tree checkout on this host.
      Used by tooling and widgets that want to link to editable source
      files (e.g. sketchybar widgets' "view plugin source" buttons)
      instead of the read-only `/nix/store` source.

      Defaults to `configVars.nixConfigPath.<darwin|linux>` (defined in
      `vars/default.nix`); override per-machine if your checkout lives
      somewhere else, or set to `null` to disable working-tree linking
      entirely.
    '';
    example = "/Users/foo/Projects/nix-config";
  };
}
