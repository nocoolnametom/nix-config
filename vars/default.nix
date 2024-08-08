{ inputs, lib }:
{
  username = "tdoggett";
  domain = inputs.nix-secrets.domain;
  userFullName = inputs.nix-secrets.full-name;
  handle = "nocoolnametom";
  userEmail = inputs.nix-secrets.user-email;
  gitHubEmail = "tom@nocoolnametom.com";
  gitLabEmail = "tom@nocoolnametom.com";
  workEmail = inputs.nix-secrets.work-email;
  persistFolder = "/persist";
  isMinimal = false; # Used to indicate nixos-installer build
}
