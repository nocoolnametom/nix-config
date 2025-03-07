{ inputs, lib, ... }:
{
  nix.settings.trusted-substituters = [ "https://ai.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
  ];

  imports = [ inputs.nixified-ai.nixosModules.comfyui ];

  services.comfyui.enable = lib.mkDefault true;
}
