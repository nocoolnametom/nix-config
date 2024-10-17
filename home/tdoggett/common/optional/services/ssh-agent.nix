{ lib, ... }:
{
  services.ssh-agent.enable = lib.mkDefault true;
}
