{
  config,
  lib,
  configVars,
  ...
}:
{
  options.virtualisation.dockerTcpApi.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Publish the Docker API on 0.0.0.0:2375 and open the firewall for it.
      That API is unauthenticated and root-equivalent on the host, so turn
      this off on any machine holding data that matters.
    '';
  };

  config = {
    virtualisation.docker.enable = lib.mkDefault true;
    virtualisation.docker.listenOptions = lib.mkDefault (
      lib.optional config.virtualisation.dockerTcpApi.enable "0.0.0.0:2375" ++ [ "/run/docker.sock" ]
    );
    networking.firewall.allowedTCPPorts = lib.mkIf config.virtualisation.dockerTcpApi.enable [ 2375 ];

    # Automatic cleanup to save disk space
    virtualisation.docker.autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [
        "--all" # Remove all unused images, not just dangling ones
        "--filter"
        "until=168h" # Remove images older than 7 days
      ];
    };

    users.users."${configVars.username}".extraGroups = [ "docker" ];
  };
}
