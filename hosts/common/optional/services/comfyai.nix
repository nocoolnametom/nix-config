{ inputs, lib, ... }:
{
  nix.settings.trusted-substituters = [
    "https://ai.cachix.org"
    "https://cuda-maintainers.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];

  imports = [ inputs.nixified-ai.nixosModules.comfyui ];

  services.comfyui.enable = lib.mkDefault true;

  nixpkgs.config.cudaSupport = lib.mkDefault true;
  nixpkgs.config.cudnnSupport = lib.mkDefault true;
}
