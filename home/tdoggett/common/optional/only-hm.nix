{
  config,
  inputs,
  lib,
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
}
