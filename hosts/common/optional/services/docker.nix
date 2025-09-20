{ lib, configVars, ... }:
{
  virtualisation.docker.enable = lib.mkDefault true;
  virtualisation.docker.listenOptions = lib.mkDefault [
    "0.0.0.0:2375"
    "/run/docker.sock"
  ];
  networking.firewall.allowedTCPPorts = [ 2375 ];

  users.users."${configVars.username}".extraGroups = [ "docker" ];
}
