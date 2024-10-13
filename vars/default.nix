{ inputs, ... }:
{
  inherit (inputs.nix-secrets)
    userFullName
    domain
    email
    networking
    ;

  username = "tdoggett";
  handle = "nocoolnametom";
  gitHubEmail = "tom@nocoolnametom.com";
  gitLabEmail = "tom@nocoolnametom.com";
  persistFolder = "/persist";
}
