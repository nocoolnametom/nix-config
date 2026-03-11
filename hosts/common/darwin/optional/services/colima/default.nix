{ configVars, ... }:
{
  # Fix /var/run/docker.sock to point to colima's socket instead of the
  # broken Docker Desktop symlink. Containers that bind-mount
  # /var/run/docker.sock (e.g. docker-in-docker dashboards) require this
  # path to resolve to the running colima daemon's socket.
  system.activationScripts.extraActivation.text = ''
    _colima_sock="/Users/${configVars.username}/.colima/default/docker.sock"
    if [ -L /var/run/docker.sock ] || [ -e /var/run/docker.sock ]; then
      rm -f /var/run/docker.sock
    fi
    ln -sf "$_colima_sock" /var/run/docker.sock
  '';
}
