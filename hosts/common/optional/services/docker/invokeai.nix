{ inputs, lib, pkgs, ... }: {
  virtualisation.arion.backend = "docker";
  virtualisation.arion.projects."invokeai".settings.services."invokeai".service = {
    image = "ghcr.io/invoke-ai/invokeai:latest";
    container_name = "invokeai";
    ports = [ "9090:9090" ];
    volumes = [ "/some/local/path:/invokeai" ];
    restart = "unless-stopped";
    devices = [ "nvidia.com/gpu=all" ];
  };

  # Optional system-wide Docker settings
  virtualisation.docker.enable = lib.mkForce true;
  virtualisation.docker.enableOnBoot = lib.mkDefault true;
  hardware.nvidia-container-toolkit.enable = lib.mkForce true;
}
