{
  pkgs,
  lib,
  ...
}:
{
  # Colima container runtime, managed as a home-manager launchd service
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

  # Remove stale broken symlinks left over from Docker Desktop uninstallation
  home.activation.cleanDockerDesktopPlugins = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    for _plugin in \
      ".docker/cli-plugins/docker-ai" \
      ".docker/cli-plugins/docker-buildx" \
      ".docker/cli-plugins/docker-cloud" \
      ".docker/cli-plugins/docker-debug" \
      ".docker/cli-plugins/docker-desktop" \
      ".docker/cli-plugins/docker-dev" \
      ".docker/cli-plugins/docker-extension" \
      ".docker/cli-plugins/docker-feedback" \
      ".docker/cli-plugins/docker-init" \
      ".docker/cli-plugins/docker-mcp" \
      ".docker/cli-plugins/docker-model" \
      ".docker/cli-plugins/docker-sbom" \
      ".docker/cli-plugins/docker-scout"
    do
      _path="$HOME/$_plugin"
      if [ -L "$_path" ] && [ ! -e "$_path" ]; then
        $DRY_RUN_CMD rm -- "$_path"
      fi
    done
  '';
}
