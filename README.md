To update only a specific inputs (eg, nix-secrets and nixpkgs-unstable):

```bash
nix flake lock --update-input nix-secrets --update-input nixpkgs-unstable
```
