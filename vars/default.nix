{ inputs, ... }:
{
  inherit (inputs.nix-secrets)
    userFullName
    domain
    email
    networking
    work
    ;

  username = "tdoggett";
  handle = "nocoolnametom";
  gitHubEmail = "810877+nocoolnametom@users.noreply.github.com";
  gitLabEmail = "2724098-nocoolnametom@users.noreply.gitlab.com";
  persistFolder = "/persist";
}
