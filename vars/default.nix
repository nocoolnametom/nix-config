{ inputs, ... }:
{
  inherit (inputs.nix-secrets)
    userFullName
    handles
    domain
    homeDomain
    healthDomain
    email
    networking
    work
    sso
    ;
  friendBlogDomain = inputs.nix-secrets.networking.blog.friends.domain;

  username = "tdoggett";
  handle = "nocoolnametom";
  gitHubEmail = "810877+nocoolnametom@users.noreply.github.com";
  gitLabEmail = "2724098-nocoolnametom@users.noreply.gitlab.com";
  persistFolder = "/persist";
  # Fake DNS domain assigned by the home router to local hostnames
  # (e.g., smeagol.doggett.home, estel.doggett.home)
  homeLanDomain = "doggett.home";
  use-hy3 = true;
  enableKanidmSSO = false; # Kanidm and OAuth2-proxy services

  # SSO Proxy type constants - use these instead of magic strings
  proxyTypes = {
    authentik = "authentik";  # Authentik's built-in proxy provider
    oauth2 = "oauth2";        # Generic OAuth2-proxy (works with any OIDC provider like Kanidm, Keycloak, etc.)
    oidc = "oidc";            # Direct OIDC integration (service handles auth internally)
    none = null;              # No SSO/proxy
  };
}
