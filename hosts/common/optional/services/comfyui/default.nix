{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
{
  # This is intended for updating the version, but it has some odd requirements issues, so we might
  # need to overlay more than just this one package...
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     comfyuiPackages = prev.comfyuiPackages // {
  #       comfyui-unwrapped = prev.comfyuiPackages.comfyui-unwrapped.overridePythonAttrs (old: rec {
  #         version = "0.3.33";
  #         src = prev.fetchFromGitHub {
  #           owner = "comfyanonymous";
  #           repo = "ComfyUI";
  #           rev = "v${version}";
  #           hash = "sha256-nqYVrkkog4We6DmnV2Qb+xncHqpSnFGQnSQjZUBb33Y=";
  #         };
  #       });
  #     };
  #   })
  # ];

  nixpkgs.config.cudaSupport = lib.mkDefault true;
  nixpkgs.config.cudnnSupport = lib.mkDefault true;

  nix.settings.trusted-substituters = [
    "https://ai.cachix.org"
    "https://cuda-maintainers.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];

  # Ensure Huggingface and Civitai keys are present for nix daemon
  sops.secrets."huggingface_key" = { };
  sops.secrets."civitai_key" = { };
  sops.templates."ai_site_env_keys" = {
    content = ''
      CIVITAI_API_TOKEN=${config.sops.placeholder."civitai_key"}
      HF_TOKEN=${config.sops.placeholder."huggingface_key"}
    '';
    mode = "0755";
  };
  # This allows us to use these environment variables when trying to download models
  systemd.services.nix-daemon.serviceConfig.EnvironmentFile = [
    config.sops.templates."ai_site_env_keys".path
  ];

  imports = [
    inputs.nixified-ai.nixosModules.comfyui
    ./comfyuimini.nix
    ./symlinker.nix
  ];

  services.comfyui.enable = lib.mkDefault true;
  services.comfyui.host = lib.mkDefault "0.0.0.0";
  networking.firewall.allowedTCPPorts = [ 8188 ];
  services.comfyui.models = lib.mkDefault (
    pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineModels
  );
  services.comfyui.customNodes = lib.mkDefault (
    pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineNodes
  );
}
