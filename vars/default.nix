{ inputs, ... }:
{
  inherit (inputs.nix-secrets)
    userFullName
    handles
    domain
    homeDomain
    statusDomain
    email
    networking
    work
    ;
  friendBlogDomain = inputs.nix-secrets.networking.blog.friends.domain;

  username = "tdoggett";
  handle = "nocoolnametom";
  gitHubEmail = "810877+nocoolnametom@users.noreply.github.com";
  gitLabEmail = "2724098-nocoolnametom@users.noreply.gitlab.com";
  persistFolder = "/persist";
  use-hy3 = true;
}
