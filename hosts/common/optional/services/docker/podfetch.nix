###############################################################################
#
#  PodFetch - arion container on the host's native PostgreSQL
#
#  Not packaged in nixpkgs, so the app stays containerised; its database is a
#  `podfetch` DB on the host PostgreSQL rather than a second Postgres
#  container.
#
#  The container runs as the host `podfetch` user and reaches Postgres over
#  the bind-mounted Unix socket, so peer authentication logs it in with no
#  password and no TCP port. Docker without user namespaces passes the real
#  uid through SO_PEERCRED, which is why the uid must be fixed.
#
#  PodFetch uses both libpq (via diesel) and rust-postgres (r2d2_postgres);
#  the percent-encoded socket-directory URL below is understood by both.
#
#  Secrets (nix-secrets): homelab/podfetch/password and
#  homelab/podfetch/podindex/{key,secret}.
#
#  Auth: PodFetch refuses to start with both basic auth and OIDC enabled, so
#  `useKanidm` swaps one for the other. Flipping it is a migration, not a
#  toggle: OIDC users are keyed by preferred_username, and an OIDC-created
#  user has no password, so it cannot log in to the GPodder API. The env
#  admin (USERNAME) is barred from the GPodder API regardless.
#
#  PodFetch's UI ignores OIDC discovery: it sends the browser to
#  `$OIDC_AUTHORITY?client_id=...` and POSTs to `$OIDC_AUTHORITY/../token`.
#  Kanidm's browser authorise endpoint is /ui/oauth2, which makes the token
#  URL /ui/token - estel's Caddy rewrites that to /oauth2/token.
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  ...
}:
let
  cfg = config.services.podfetch;

  publicUrl = "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}";
  kanidmUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
  oidcClientId = "podfetch"; # matches the client in ../kanidm.nix

  # Fixed so the in-container uid maps back to this user for peer auth.
  podfetchUid = 4135;
  gid = toString config.users.groups.users.gid;

  envFile = config.sops.templates."podfetch.env".path;
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.podfetch = {
    podcastsDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/podfetch/podcasts";
      description = "Where downloaded episodes are stored.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.podfetch;
      description = "Host port the web UI is published on.";
    };

    useKanidm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Log in through Kanidm OIDC instead of basic auth (see the header comment).";
    };
  };

  config = {
    users.users.podfetch = {
      isSystemUser = true;
      uid = podfetchUid;
      group = "users";
    };

    services.postgresql = {
      enable = lib.mkDefault true;
      ensureDatabases = [ "podfetch" ];
      ensureUsers = [
        {
          name = "podfetch";
          ensureDBOwnership = true;
        }
      ];
    };

    sops.secrets."homelab/podfetch/password" = { };
    sops.secrets."homelab/podfetch/podindex/key" = { };
    sops.secrets."homelab/podfetch/podindex/secret" = { };
    sops.templates."podfetch.env".content = ''
      PASSWORD=${config.sops.placeholder."homelab/podfetch/password"}
      PODINDEX_API_KEY=${config.sops.placeholder."homelab/podfetch/podindex/key"}
      PODINDEX_API_SECRET=${config.sops.placeholder."homelab/podfetch/podindex/secret"}
    '';

    systemd.tmpfiles.rules = [
      "d ${cfg.podcastsDir} 0775 podfetch users -"
    ];

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.podfetch = { };

    # If podcastsDir sits on a nofail mount, never let downloads land on the
    # disk underneath it instead.
    systemd.services.arion-podfetch = {
      unitConfig.RequiresMountsFor = [ cfg.podcastsDir ];
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };

    virtualisation.arion.projects.podfetch.settings.services.podfetch = {
      service = {
        image = "samuel19982/podfetch:latest";
        container_name = "PodFetch";
        user = "${toString podfetchUid}:${gid}";
        ports = [ "${toString cfg.port}:8000" ];
        environment = {
          DATABASE_URL = "postgresql://podfetch@%2Frun%2Fpostgresql/podfetch";
          SERVER_URL = publicUrl;
          POLLING_INTERVAL = "300"; # minutes
          GPODDER_INTEGRATION_ENABLED = "true";
        }
        // (
          if cfg.useKanidm then
            {
              BASIC_AUTH = "false";
              OIDC_AUTH = "true";
              OIDC_AUTHORITY = "${kanidmUrl}/ui/oauth2";
              OIDC_CLIENT_ID = oidcClientId;
              # NOT /ui/login: the UI skips the whole OIDC code exchange on any
              # path ending in "login", so returning there loops forever.
              OIDC_REDIRECT_URI = "${publicUrl}/ui/";
              OIDC_SCOPE = "openid profile email";
              OIDC_JWKS = "${kanidmUrl}/oauth2/openid/${oidcClientId}/public_key.jwk";
            }
          else
            {
              BASIC_AUTH = "true";
              USERNAME = "admin";
              OIDC_AUTH = "false";
            }
        );
        env_file = [ envFile ];
        volumes = [
          "${cfg.podcastsDir}:/app/podcasts"
          "/run/postgresql:/run/postgresql"
        ];
        restart = "on-failure:5";
      };
      out.service.security_opt = [ "no-new-privileges:true" ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
