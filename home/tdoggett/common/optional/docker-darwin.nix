{
  pkgs,
  lib,
  ...
}:
{
  # Use macOS Keychain for docker credential storage instead of Docker Desktop
  home.packages = [ pkgs.docker-credential-helpers ];

  # Manage ~/.docker/config.json so Docker Desktop remnants (credsStore: "desktop",
  # plugin hooks) don't persist after uninstallation.
  programs.docker-cli = {
    enable = true;
    settings.credsStore = "osxkeychain";
  };

  # Remove the existing unmanaged config.json (written by Docker Desktop) before
  # home-manager tries to create its managed symlink in its place.
  home.activation.cleanDockerConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -f "$HOME/.docker/config.json" ] && [ ! -L "$HOME/.docker/config.json" ]; then
      $DRY_RUN_CMD rm -f "$HOME/.docker/config.json"
    fi
  '';

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
