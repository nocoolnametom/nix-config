{ lib, pkgs, ... }: {
  virtualisation.arion.projects."invokeai" = {
    settings = {
      services.invokeai = {
        image = "ghcr.io/invoke-ai/invokeai:latest";
        container_name = "invokeai";
        ports = [ "9090:9090" ];
        volumes = [ "/some/local/path:/invokeai" ];
        restart = "unless-stopped";

        # GPU support equivalent to --device=nvidia.com/gpu=all
        deploy.resources.reservations.devices = [
          {
            driver = "nvidia";
            count = "all";
            capabilities = [ "gpu" ];
          }
        ];
      };
    };

    # Optional: enable automatic systemd service
    service = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    };
  };

  # Optional system-wide Docker settings
  virtualisation.docker.enable = lib.mkForce true;
  virtualisation.docker.enableOnBoot = lib.mkDefault true;
  hardware.nvidia-container-toolkit.enable = lib.mkForce true;
  virtualisation.docker.daemon.settings = {
    # Recommended for GPU access
    "default-runtime" = "nvidia";
    runtimes.nvidia = {
      path = "${pkgs.nvidia-container-runtime}/bin/nvidia-container-runtime";
    };
  };
}