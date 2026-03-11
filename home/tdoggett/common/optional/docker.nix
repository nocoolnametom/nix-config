{
  pkgs,
  lib,
  ...
}:
{
  # Colima container runtime, managed as a home-manager launchd/systemd service
  services.colima.enable = true;

  # Docker CLI and compose tooling
  home.packages = [
    pkgs.docker-client
    pkgs.docker-compose
  ];

  # Declaratively manage the docker compose CLI plugin
  home.file.".docker/cli-plugins/docker-compose" = {
    source = "${pkgs.docker-compose}/bin/docker-compose";
  };
}
