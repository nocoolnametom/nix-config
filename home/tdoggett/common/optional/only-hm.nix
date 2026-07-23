{
  config,
  inputs,
  lib,
  configVars,
  configLib,
  ...
}:
{
  # For new commands: register only nixpkgs (not all inputs)
  # This ensures `nix shell nixpkgs#foo` uses your flake's nixpkgs
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # For legacy commands: route NIX_PATH through registry
  home.sessionVariables.NIX_PATH =
    let
      nixpkgsRef = if builtins.hasAttr "to" inputs.nixpkgs then inputs.nixpkgs.to.path else inputs.nixpkgs.outPath;
    in
    "nixpkgs=${nixpkgsRef}$\{NIX_PATH:+:$NIX_PATH}";

  # Also ensure experimental features are enabled (required for flakes/registry)
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Authorise every registered key so any YubiKey or personal SSH key can log in.
  # id_nixbuilder is excluded: it's for Nix remote builds only, not interactive login.
  home.file.".ssh/authorized_keys" =
    let
      keyDir = configLib.relativeToRoot "hosts/common/users/${configVars.username}/keys";
      excludedKeys = [ "id_nixbuilder" ];
      keyFiles = builtins.filter
        (f: lib.hasSuffix ".pub" f &&
            !(builtins.elem (lib.removeSuffix ".pub" f) excludedKeys))
        (builtins.attrNames (builtins.readDir keyDir));
    in
    {
      text = lib.concatMapStringsSep "\n" (f: lib.fileContents "${keyDir}/${f}") keyFiles + "\n";
    };
}
