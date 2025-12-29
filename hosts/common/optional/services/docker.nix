{ lib, configVars, ... }:
{
  virtualisation.docker.enable = lib.mkDefault true;
  virtualisation.docker.listenOptions = lib.mkDefault [
    "0.0.0.0:2375"
    "/run/docker.sock"
  ];
  networking.firewall.allowedTCPPorts = [ 2375 ];

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
}
