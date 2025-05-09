{ pkgs, config, inputs, lib, ... }:
{
  nix.settings.trusted-substituters = [
    "https://ai.cachix.org"
    "https://cuda-maintainers.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];

  # Ensure Huggingface and Civitai keys are present for nix daemon
  sops.secrets."huggingface_key" = {};
  sops.secrets."civitai_key" = {};
  sops.templates."ai_site_env_keys" = {
    content = ''
      CIVITAI_API_TOKEN=${config.sops.placeholder."civitai_key"}
      HF_TOKEN=${config.sops.placeholder."huggingface_key"}
    '';
    mode = "0755";
  };
  # This allows us to use these environment variables when running
  # `nixos-rebuild switch --use-remote-sudo` as non-root
  systemd.services.nix-daemon.serviceConfig.EnvironmentFile = [
    config.sops.templates."ai_site_env_keys".path
  ];

  imports = [ inputs.nixified-ai.nixosModules.comfyui ];

  services.comfyui.enable = lib.mkDefault true;
  services.comfyui.host = lib.mkDefault "0.0.0.0";

  nixpkgs.config.cudaSupport = lib.mkDefault true;
  nixpkgs.config.cudnnSupport = lib.mkDefault true;
}
