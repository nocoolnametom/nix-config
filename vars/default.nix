{ inputs, ... }:
let
  username = "tdoggett";
  handle = "nocoolnametom";
in
{
  inherit (inputs.nix-secrets)
    userFullName
    handles
    domain
    homeDomain
    homelabTld
    homelabDomain
    healthDomain
    email
    networking
    work
    calendars
    sso
    ;
  friendBlogDomain = inputs.nix-secrets.networking.blog.friends.domain;

  inherit username handle;

  # Conventional location of this nix-config working-tree checkout. Both
  # variants are provided because the home-directory prefix differs by OS;
  # consumers pick the right one with e.g. `pkgs.stdenv.isDarwin`. Used by
  # widgets and tooling that want to link to the editable source file
  # rather than the read-only /nix/store path.
  nixConfigPath = {
    darwin = "/Users/${username}/Projects/${handle}/nix-config";
    linux = "/home/${username}/Projects/${handle}/nix-config";
  };
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
    authentik = "authentik"; # Authentik's built-in proxy provider
    oauth2 = "oauth2"; # Generic OAuth2-proxy (works with any OIDC provider like Kanidm, Keycloak, etc.)
    oidc = "oidc"; # Direct OIDC integration (service handles auth internally)
    none = null; # No SSO/proxy
  };

  yubikey.identifiers = {
    ykbackup    = 22910125;
    ykkeychain  = 16961659;
    yklappy     = 22373686;
    ykmbp       = 22373683;
    ykmacbookc  = 35911238;
    yknfc       = 35821306;
  };

  homepage = {
    serviceBlacklist = [
      "archerstashvr"
      "stashvr"
    ];
  };
}
