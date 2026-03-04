{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  # Transform nix-secrets users structure to Kanidm persons format
  personsFromSecrets = lib.mapAttrs (
    username: userData: {
      displayName = userData.displayName;
      mailAddresses = [ userData.email ];
      groups = userData.groups ++ [ "service_users" ]; # Add service_users to all users
      # Note: Passwords must be set via Kanidm web UI or CLI after provisioning
      # Declarative provisioning doesn't support passwordFile
    }
  ) configVars.sso.users;

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
      lib.listToAttrs (map (group: {
        name = group;
        value = scopes;
      }) requiredGroups);
in
{
  # Kanidm SSO Provider with declarative provisioning
  services.kanidm = {
    enableServer = true;
    package = pkgs.kanidmWithSecretProvisioning_1_8;

    serverSettings = {
      bindaddress = "127.0.0.1:${toString configVars.networking.ports.tcp.kanidm}";
      origin = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      domain = configVars.homeDomain;
      log_level = "info";
      tls_chain = "/var/lib/acme/${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/fullchain.pem";
      tls_key = "/var/lib/acme/${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/key.pem";
    };

    # Declarative provisioning via kanidm-provision
    provision = {
      enable = true;
      idmAdminPasswordFile = config.sops.secrets."homelab/kanidm/admin-password".path;

      # Define groups - combining system groups with groups from nix-secrets
      groups =
        {
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

        ombi = {
          displayName = "Ombi Request System";
          originUrl = "https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}";
          originLanding = "https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}";
          basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/ombi/client-secret".path;
          scopeMaps = makeScopeMaps "ombi";
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

        sickgear = {
          displayName = "SickGear TV Shows";
          originUrl = "https://${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}";
          originLanding = "https://${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}";
          basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sickgear/client-secret".path;
          scopeMaps = makeScopeMaps "sickgear";
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

  # Ensure kanidm can read ACME certificates managed by caddy
  users.users.kanidm.extraGroups = [ "caddy" ];

  # SOPS secret definitions
  sops.secrets."homelab/kanidm/admin-password" = {
    owner = "kanidm";
  };

  # OAuth2 client secrets for OAuth2-proxy services (15 services)
  sops.secrets."homelab/kanidm/oauth2/navidrome/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/ombi/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/flood/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/radarr/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/sickgear/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret" = { };
  sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret" = { };

  # OIDC client secrets for native OIDC services (10 services)
  sops.secrets."homelab/kanidm/oidc/actual/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/hedgedoc/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/mealie/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/miniflux/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/paperless/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/karakeep/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/kavita/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/kavitan/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/openwebui/client-secret" = { };
  sops.secrets."homelab/kanidm/oidc/nas/client-secret" = { };

  # Note: User passwords must be set via Kanidm web UI at https://sso.doggett.family
  # or via kanidm CLI after initial provisioning. Declarative passwordFile is not supported.
}
