{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  # Transform nix-secrets users structure to Kanidm persons format
  personsFromSecrets = lib.mapAttrs (username: userData: {
    displayName = userData.displayName;
    mailAddresses = [ userData.email ];
    groups = userData.groups ++ [ "service_users" ]; # Add service_users to all users
    # Note: Passwords must be set via Kanidm web UI or CLI after provisioning
    # Declarative provisioning doesn't support passwordFile
  }) configVars.sso.users;

  # Transform nix-secrets groups structure to Kanidm groups format
  groupsFromSecrets = lib.mapAttrs (groupName: groupData: {
    # Groups can have additional metadata if needed
  }) configVars.sso.groups;

  # Helper function to get groups for a service from nix-secrets
  getServiceGroups =
    serviceName:
    let
      # Find all groups that grant access to this service
      matchingGroups = lib.filter (
        groupName:
        let
          group = configVars.sso.groups.${groupName};
        in
        builtins.elem serviceName group.services
      ) (builtins.attrNames configVars.sso.groups);
    in
    matchingGroups;

  # Helper to generate scopeMaps for a service
  # If service has specific group requirements, only those groups get access
  # Otherwise, service_users (default) gets access
  makeScopeMaps =
    serviceName:
    let
      requiredGroups = getServiceGroups serviceName;
      scopes = [
        "openid"
        "email"
        "profile"
      ];
    in
    if requiredGroups == [ ] then
      # No specific groups required - use service_users (default access)
      { service_users = scopes; }
    else
      # Specific groups required - only those groups get access
      lib.listToAttrs (
        map (group: {
          name = group;
          value = scopes;
        }) requiredGroups
      );
in
{
  # Per-host opt-in: import this module anywhere, then set services.kanidmSso.enable = true.
  # Using a dedicated option (rather than the global configVars.enableKanidmSSO flag) prevents
  # oauth2-proxy.nix from activating on estel/durin before their SOPS secrets are provisioned.
  options.services.kanidmSso.enable = lib.mkEnableOption "Kanidm SSO server";

  config = lib.mkIf config.services.kanidmSso.enable {
    # Kanidm SSO Provider with declarative provisioning
    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_11;

      server.enable = true;

      server.settings = {
        bindaddress = "0.0.0.0:${toString configVars.networking.ports.tcp.kanidm}";
        origin = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
        domain = configVars.homeDomain;
        log_level = "info";
        # Kanidm insists on TLS, but nobody verifies this cert: estel's Caddy is
        # the public TLS terminator and proxies here with verification off. So
        # the host's existing homelab-CA cert does (tested 2026-10-03 on 1.11.2),
        # and no public cert or DNS-provider API key is needed on this host.
        tls_chain = config.sops.secrets."kanidm/tls-chain".path;
        tls_key = config.sops.secrets."kanidm/tls-key".path;
      };

      # Declarative provisioning via kanidm-provision
      provision = {
        enable = true;
        idmAdminPasswordFile = config.sops.secrets."homelab/kanidm/admin-password".path;

        # Define groups - combining system groups with groups from nix-secrets
        groups = {
          kanidm_admins = { };
          service_users = { }; # Base group - all users get access to most services
        }
        // groupsFromSecrets;

        # Define persons (users) - imported from nix-secrets
        persons = personsFromSecrets;

        # OAuth2 client definitions for all 15 services
        systems.oauth2 = {
          navidrome = {
            displayName = "Navidrome Music Server";
            originUrl = "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/navidrome/client-secret".path;
            scopeMaps = makeScopeMaps "navidrome";
          };

          seerr = {
            displayName = "Seerr Request System";
            originUrl = "https://${configVars.networking.subdomains.seerr}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.seerr}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/seerr/client-secret".path;
            scopeMaps = makeScopeMaps "seerr";
          };

          comfyui = {
            displayName = "ComfyUI";
            originUrl = "https://${configVars.networking.subdomains.comfyui}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.comfyui}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret".path;
            scopeMaps = makeScopeMaps "comfyui";
          };

          comfyuimini = {
            displayName = "ComfyUI Mini";
            originUrl = "https://${configVars.networking.subdomains.comfyuimini}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.comfyuimini}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret".path;
            scopeMaps = makeScopeMaps "comfyuimini";
          };

          invokeai = {
            displayName = "InvokeAI";
            originUrl = "https://${configVars.networking.subdomains.invokeai}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.invokeai}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret".path;
            scopeMaps = makeScopeMaps "invokeai";
          };

          archerstashvr = {
            displayName = "Archer Stash VR";
            originUrl = "https://${configVars.networking.subdomains.archerstashvr}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.archerstashvr}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret".path;
            scopeMaps = makeScopeMaps "archerstashvr";
          };

          delugeweb = {
            displayName = "Deluge Web UI";
            originUrl = "https://${configVars.networking.subdomains.delugeweb}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.delugeweb}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret".path;
            scopeMaps = makeScopeMaps "delugeweb";
          };

          flood = {
            displayName = "Flood Torrent UI";
            originUrl = "https://${configVars.networking.subdomains.flood}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.flood}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/flood/client-secret".path;
            scopeMaps = makeScopeMaps "flood";
          };

          nzbget = {
            displayName = "NZBGet";
            originUrl = "https://${configVars.networking.subdomains.nzbget}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.nzbget}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret".path;
            scopeMaps = makeScopeMaps "nzbget";
          };

          nzbhydra = {
            displayName = "NZBHydra2";
            originUrl = "https://${configVars.networking.subdomains.nzbhydra}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.nzbhydra}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret".path;
            scopeMaps = makeScopeMaps "nzbhydra";
          };

          pinchflat = {
            displayName = "Pinchflat";
            originUrl = "https://${configVars.networking.subdomains.pinchflat}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.pinchflat}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret".path;
            scopeMaps = makeScopeMaps "pinchflat";
          };

          radarr = {
            displayName = "Radarr";
            originUrl = "https://${configVars.networking.subdomains.radarr}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.radarr}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/radarr/client-secret".path;
            scopeMaps = makeScopeMaps "radarr";
          };

          sonarr = {
            displayName = "Sonarr";
            originUrl = "https://${configVars.networking.subdomains.sonarr}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.sonarr}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret".path;
            scopeMaps = makeScopeMaps "sonarr";
          };

          stashvr = {
            displayName = "Stash VR";
            originUrl = "https://${configVars.networking.subdomains.stashvr}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.stashvr}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret".path;
            scopeMaps = makeScopeMaps "stashvr";
          };

          # Native OIDC services (services with built-in OIDC support)
          actual = {
            displayName = "Actual Budget";
            originUrl = "https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/actual/client-secret".path;
            scopeMaps = makeScopeMaps "actual";
          };

          hedgedoc = {
            displayName = "HedgeDoc";
            originUrl = "https://${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/hedgedoc/client-secret".path;
            scopeMaps = makeScopeMaps "hedgedoc";
          };

          mealie = {
            displayName = "Mealie";
            originUrl = "https://${configVars.networking.subdomains.mealie}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.mealie}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/mealie/client-secret".path;
            scopeMaps = makeScopeMaps "mealie";
          };

          miniflux = {
            displayName = "Miniflux RSS Reader";
            originUrl = "https://${configVars.networking.subdomains.miniflux}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.miniflux}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/miniflux/client-secret".path;
            scopeMaps = makeScopeMaps "miniflux";
          };

          paperless = {
            displayName = "Paperless-ngx";
            originUrl = "https://${configVars.networking.subdomains.paperless}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.paperless}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/paperless/client-secret".path;
            scopeMaps = makeScopeMaps "paperless";
          };

          karakeep = {
            displayName = "KaraKeep Karaoke";
            originUrl = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/karakeep/client-secret".path;
            scopeMaps = makeScopeMaps "karakeep";
          };

          # Immich only supports one OAuth provider at a time. Switching from
          # Authentik: set Immich's signing algorithm to ES256 (Kanidm's
          # default) and its mobile redirect override to the
          # /api/oauth/mobile-redirect URL below, so no app.immich:// scheme
          # has to be registered here.
          immich =
            let
              immichUrl = "https://${configVars.networking.subdomains.immich}.${configVars.homeDomain}";
            in
            {
              displayName = "Immich Photos";
              originUrl = [
                "${immichUrl}/auth/login"
                "${immichUrl}/user-settings"
                "${immichUrl}/api/oauth/mobile-redirect"
              ];
              originLanding = immichUrl;
              basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/immich/client-secret".path;
              scopeMaps = makeScopeMaps "immich";
            };

          # PodFetch's SPA does the code flow in the browser, so this is a
          # public client (PKCE, no secret). Short usernames make the
          # preferred_username claim `tdoggett`, which PodFetch matches against
          # its existing users. See hosts/feanor/podfetch.nix for the
          # /ui/token rewrite this flow depends on.
          podfetch = {
            displayName = "PodFetch Podcasts";
            public = true;
            preferShortUsername = true;
            originUrl = "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}/ui/login";
            originLanding = "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}";
            scopeMaps = makeScopeMaps "podfetch";
          };

          kavita = {
            displayName = "Kavita Reader";
            originUrl = "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/kavita/client-secret".path;
            scopeMaps = makeScopeMaps "kavita";
          };

          kavitan = {
            displayName = "Kavita N";
            originUrl = "https://${configVars.networking.subdomains.kavitan}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.kavitan}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/kavitan/client-secret".path;
            scopeMaps = makeScopeMaps "kavitan";
          };

          openwebui = {
            displayName = "Open WebUI";
            originUrl = "https://${configVars.networking.subdomains.openwebui}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.openwebui}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/openwebui/client-secret".path;
            scopeMaps = makeScopeMaps "openwebui";
          };

          nas = {
            displayName = "Cirdan NAS (DSM)";
            originUrl = "https://${configVars.networking.subdomains.nas}.${configVars.homeDomain}";
            originLanding = "https://${configVars.networking.subdomains.nas}.${configVars.homeDomain}";
            basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/nas/client-secret".path;
            scopeMaps = makeScopeMaps "nas";
          };
        };
      };
    };

    # Kanidm's own read-only copies of the host's homelab-ssl secret (the
    # status page keeps the caddy-owned ones). Kanidm warns unless these are
    # readable only by its uid.
    sops.secrets."kanidm/tls-chain" = {
      key = "homelab-ssl/${config.networking.hostName}/cert";
      owner = "kanidm";
      mode = "0400";
    };
    sops.secrets."kanidm/tls-key" = {
      key = "homelab-ssl/${config.networking.hostName}/key";
      owner = "kanidm";
      mode = "0400";
    };

    # Open Kanidm's HTTPS port so estel's Caddy can proxy to it over the LAN.
    networking.firewall.allowedTCPPorts = [ configVars.networking.ports.tcp.kanidm ];

    # SOPS secret definitions
    sops.secrets."homelab/kanidm/admin-password" = {
      owner = "kanidm";
    };

    # OAuth2 client secrets for OAuth2-proxy services (15 services)
    # Must be readable by both kanidm (for provisioning) and oauth2-proxy (for runtime)
    sops.secrets."homelab/kanidm/oauth2/navidrome/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/seerr/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/flood/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/radarr/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };
    sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret" = {
      owner = "kanidm";
      group = "keys";
      mode = "0440";
    };

    # OIDC client secrets for native OIDC services (11 services)
    # Must be readable by kanidm for provisioning
    sops.secrets."homelab/kanidm/oidc/actual/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/hedgedoc/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/mealie/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/immich/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/miniflux/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/paperless/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/karakeep/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/kavita/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/kavitan/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/openwebui/client-secret" = {
      owner = "kanidm";
    };
    sops.secrets."homelab/kanidm/oidc/nas/client-secret" = {
      owner = "kanidm";
    };

    # Note: User passwords must be set via Kanidm web UI at https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}
    # or via kanidm CLI after initial provisioning. Declarative passwordFile is not supported.
  };
}
