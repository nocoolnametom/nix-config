#################### DevShell ####################
#
# Custom shell for bootstrapping on new hosts, modifying nix-config, and secrets management

{
  pkgs ? # If pkgs is not defined, instantiate nixpkgs from locked commit
    let
      lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
      nixpkgs = fetchTarball {
        url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
        sha256 = lock.narHash;
      };
    in
    import nixpkgs { overlays = [ ]; },
  # Pre-commit check derivation from checks/default.nix — provides shellHook to install git hooks.
  # Defaults to a no-op when shell.nix is used standalone (without the flake).
  pre-commit-check ? {
    shellHook = "";
  },
  ...
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    nativeBuildInputs = builtins.attrValues {
      inherit (pkgs)
        # Required for pre-commit hook 'nixpkgs-fmt' only on Darwin
        # REF: <https://discourse.nixos.org/t/nix-shell-rust-hello-world-ld-linkage-issue/17381/4>
        libiconv

        nix
        home-manager
        git
        just
        pre-commit

        age
        ssh-to-age
        sops
        ;
    };
    # Installs .git/hooks/pre-commit pointing to the Nix-managed hook script.
    # Running `nix develop` once per clone is all that's needed.
    shellHook = pre-commit-check.shellHook;
  };
}
