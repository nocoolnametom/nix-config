{ inputs, lib }:
# TODO This is _not_ how I'm supposed to get secrets from sops for this file! Look up how to do this.
{
  username = "tdoggett";
  # domain = inputs.nix-secrets.domain;
  # userFullName = inputs.nix-secrets.full-name;
  handle = "nocoolnametom";
  # userEmail = inputs.nix-secrets.user-email;
  gitHubEmail = "tom@nocoolnametom.com";
  gitLabEmail = "tom@nocoolnametom.com";
  # workEmail = inputs.nix-secrets.work-email;
  persistFolder = "/persist";
  bertIpAddress = "192.168.0.20";
  sauronIpAddress = "192.168.0.168";
  invokeaiPort = "9090";
  cirdanIpAddress = "192.168.0.45";
  elrondIpAddress = "45.33.53.132";
  glorfindelIpAddress = "72.14.183.148";
  bombadilIpAddress = "172.234.207.124";
}
