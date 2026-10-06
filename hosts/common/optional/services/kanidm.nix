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

  # Tile images on the Kanidm apps page: kanidm-icons/<client name>.<ext>
  # becomes that OAuth2 client's imageFile (svg, png, jpg, gif or webp; raster
  # images at most 1024x1024). Drop in a file named after a client to add one;
  # a file without a matching client would provision an incomplete client.
  # Most came from the retired Authentik instance's application icons.
  # Clients for services that run on this (the Kanidm) host are shown only
  # while their service is enabled here: disable one in this host's config
  # and its tile disappears at the next rebuild, re-enable it and it returns.
  # Clients for services on other hosts are always shown.
  # The arion-based apps have no enable option; their project existing is it.
  arionProjects = config.virtualisation.arion.projects or { };
  localServiceEnabled = {
    audiobookshelf = config.services.audiobookshelf.enable;
    autocaliweb = arionProjects ? autocaliweb;
    immich = config.services.immich.enable;
    jellyfin = config.services.jellyfin.enable;
    kavita = config.services.kavita.enable;
    kavitan = config.services.kavitan.enable or false;
    navidrome = config.services.navidrome.enable;
    pinchflat = config.services.pinchflat.enable or false; # would run here if revived
    podfetch = arionProjects ? podfetch;
    tubearchivist = arionProjects ? tubearchivist;
    komodo = arionProjects ? komodo;
  };

  # Disabled clients stay in Kanidm with no scope map, so nobody may use them
  # and they are off every apps page; kanidm-inactive-clients (below) removes
  # the scope maps provisioning leaves behind. (Not `present = false`:
  # deleting a client makes kanidm-provision record a placeholder uuid in
  # ext_idm_provisioned_entities, Kanidm rejects it, and kanidm.service fails
  # to start - seen with 1.11.2 on 2026-10-06.)
  inactiveClients = lib.attrNames (lib.filterAttrs (_: enabled: !enabled) localServiceEnabled);

  clientIcons = lib.mapAttrs' (
    file: _:
    lib.nameValuePair (builtins.head (builtins.match "(.*)\\.[^.]+" file)) (./kanidm-icons + "/${file}")
  ) (builtins.readDir ./kanidm-icons);
in
{
  # Per-host opt-in: import this module anywhere, then set services.kanidmSso.enable = true.
  # Using a dedicated option (rather than the global configVars.enableKanidmSSO flag) prevents
  # oauth2-proxy.nix from activating on estel/durin before their SOPS secrets are provisioned.
  options.services.kanidmSso.enable = lib.mkEnableOption "Kanidm SSO server";

  config = lib.mkIf config.services.kanidmSso.enable (
    lib.mkMerge [
      {
        # Credential reset links (Kanidm 1.11's web UI cannot create these):
        #
        #   kanidm-reset <username> [lifetime-seconds]     # default 86400 = 24h
        #
        # Run it on the Kanidm host (re-runs itself under sudo to read the
        # idm_admin password). It prints a one-time https://<sso>/ui/reset?token=
        # link; whoever opens it sets their own password / TOTP / passkey.
        #
        # Password-only vs MFA is an account policy stored in Kanidm's database,
        # not here. As set up 2026-10-05: idm_all_persons = "any" (password-only
        # allowed, which forces a 15-character minimum) and adults = "mfa". The
        # strictest policy across a person's groups wins, so only people outside
        # `adults` may skip the second factor. To inspect or change it:
        #   kanidm group get <group> -D idm_admin
        #   kanidm group account-policy credential-type-minimum <group> any|mfa|passkey -D idm_admin
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "kanidm-reset";
            text = ''
              if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
                echo "usage: kanidm-reset <username> [lifetime-seconds]" >&2
                exit 64
              fi
              if [ "$(id -u)" -ne 0 ]; then
                exec sudo "$0" "$@"
              fi

              # Throwaway HOME: the CLI caches its session token under ~/.cache.
              HOME="$(mktemp -d)"
              export HOME
              trap 'rm -rf "$HOME"' EXIT
              export KANIDM_URL=${lib.escapeShellArg config.services.kanidm.server.settings.origin}
              KANIDM_PASSWORD="$(cat ${config.sops.secrets."homelab/kanidm/admin-password".path})"
              export KANIDM_PASSWORD

              kanidm=${config.services.kanidm.package}/bin/kanidm
              "$kanidm" login -D idm_admin >/dev/null
              "$kanidm" person credential create-reset-token "$1" --ttl "''${2:-86400}" -D idm_admin
            '';
          })
        ];

        # Kanidm SSO Provider with declarative provisioning
        services.kanidm = {
          package = pkgs.kanidmWithSecretProvisioning_1_11;

          server.enable = true;

          # `kanidm` CLI on PATH, pointed at this server (for the account-policy
          # commands noted above; log in first with `kanidm login -D idm_admin`).
          client.enable = true;
          client.settings.uri = config.services.kanidm.server.settings.origin;

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
            # The module defaults to versions = 0, which disables online backups.
            # Nightly JSON dumps land in /var/lib/kanidm/backups (default path).
            online_backup.versions = 7;
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
              # Behind oauth2-proxy on estel; Navidrome itself runs on feanor.
              navidrome = {
                displayName = "Navidrome Music Server";
                originUrl = "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}";
                preferShortUsername = true;
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
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.comfyui}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.comfyui}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret".path;
                scopeMaps = makeScopeMaps "comfyui";
              };

              comfyuimini = {
                displayName = "ComfyUI Mini";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.comfyuimini}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.comfyuimini}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret".path;
                scopeMaps = makeScopeMaps "comfyuimini";
              };

              invokeai = {
                displayName = "InvokeAI";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.invokeai}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.invokeai}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret".path;
                scopeMaps = makeScopeMaps "invokeai";
              };

              # Fronted by oauth2-proxy on smeagol. Served on `domain` (not
              # homeDomain) per estel's caddy.nix, and Kanidm matches the
              # redirect exactly, so the full callback path is required.
              archerstashvr = {
                displayName = "Archer Stash VR";
                originUrl = "https://${configVars.networking.subdomains.archerstashvr}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.archerstashvr}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret".path;
                scopeMaps = makeScopeMaps "archerstashvr";
              };

              delugeweb = {
                displayName = "Deluge Web UI";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.delugeweb}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.delugeweb}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret".path;
                scopeMaps = makeScopeMaps "delugeweb";
              };

              flood = {
                displayName = "Flood Torrent UI";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.flood}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.flood}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/flood/client-secret".path;
                scopeMaps = makeScopeMaps "flood";
              };

              nzbget = {
                displayName = "NZBGet";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.nzbget}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.nzbget}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret".path;
                scopeMaps = makeScopeMaps "nzbget";
              };

              nzbhydra = {
                displayName = "NZBHydra2 NZB Search";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.nzbhydra}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.nzbhydra}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret".path;
                scopeMaps = makeScopeMaps "nzbhydra";
              };

              pinchflat = {
                displayName = "Pinchflat YouTube Download";
                originUrl = "https://${configVars.networking.subdomains.pinchflat}.${configVars.homeDomain}";
                originLanding = "https://${configVars.networking.subdomains.pinchflat}.${configVars.homeDomain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret".path;
                scopeMaps = makeScopeMaps "pinchflat";
              };

              radarr = {
                displayName = "Radarr Movies";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.radarr}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.radarr}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/radarr/client-secret".path;
                scopeMaps = makeScopeMaps "radarr";
              };

              sonarr = {
                displayName = "Sonarr TV";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.sonarr}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.sonarr}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret".path;
                scopeMaps = makeScopeMaps "sonarr";
              };

              stashvr = {
                displayName = "Stash VR";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.stashvr}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.stashvr}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret".path;
                scopeMaps = makeScopeMaps "stashvr";
              };

              whisparr = {
                displayName = "Whisparr";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${configVars.networking.subdomains.whisparr}.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains.whisparr}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/whisparr/client-secret".path;
                scopeMaps = makeScopeMaps "whisparr";
              };

              "whisparr-eros" = {
                displayName = "Whisparr Eros";
                # Behind oauth2-proxy on estel; served on `domain`, exact callback required.
                originUrl = "https://${
                  configVars.networking.subdomains."whisparr-eros"
                }.${configVars.domain}/oauth2/callback";
                originLanding = "https://${configVars.networking.subdomains."whisparr-eros"}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/whisparr-eros/client-secret".path;
                scopeMaps = makeScopeMaps "whisparr-eros";
              };

              # Native OIDC services (services with built-in OIDC support)
              # Actual matches users by preferred_username against its own user
              # names, so send the short name. Its openid-client keeps the RS256
              # default for ID tokens, hence legacy crypto (RS256) for this client.
              actual =
                let
                  url = "https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}";
                in
                {
                  displayName = "Actual Budget";
                  originUrl = "${url}/openid/callback";
                  originLanding = url;
                  preferShortUsername = true;
                  enableLegacyCrypto = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/actual/client-secret".path;
                  scopeMaps = makeScopeMaps "actual";
                };

              # HedgeDoc's generic OAuth2 login keys accounts on preferred_username
              # and its passport-oauth2 strategy sends no PKCE.
              hedgedoc =
                let
                  url = "https://${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}";
                in
                {
                  displayName = "HedgeDoc Notes Writer";
                  originUrl = "${url}/auth/oauth2/callback";
                  originLanding = url;
                  preferShortUsername = true;
                  allowInsecureClientDisablePkce = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/hedgedoc/client-secret".path;
                  scopeMaps = makeScopeMaps "hedgedoc";
                };

              # Mealie finishes the OIDC flow on its /login page and matches users
              # by email.
              mealie =
                let
                  url = "https://${configVars.networking.subdomains.mealie}.${configVars.homeDomain}";
                in
                {
                  displayName = "Mealie";
                  originUrl = "${url}/login";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/mealie/client-secret".path;
                  scopeMaps = makeScopeMaps "mealie";
                };

              miniflux =
                let
                  url = "https://${configVars.networking.subdomains.miniflux}.${configVars.homeDomain}";
                in
                {
                  displayName = "Miniflux RSS Reader";
                  originUrl = "${url}/oauth2/oidc/callback";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/miniflux/client-secret".path;
                  scopeMaps = makeScopeMaps "miniflux";
                };

              # django-allauth's callback path contains the provider_id set in
              # paperless.nix ("kanidm").
              paperless =
                let
                  url = "https://${configVars.networking.subdomains.paperless}.${configVars.homeDomain}";
                in
                {
                  displayName = "Paperless-ngx";
                  originUrl = "${url}/accounts/oidc/kanidm/login/callback/";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/paperless/client-secret".path;
                  scopeMaps = makeScopeMaps "paperless";
                };

              # Karakeep (next-auth + openid-client) keeps the RS256 default for ID
              # tokens, hence legacy crypto (RS256) for this client.
              karakeep =
                let
                  url = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
                in
                {
                  displayName = "Karakeep Bookmarks";
                  originUrl = "${url}/api/auth/callback/custom";
                  originLanding = url;
                  enableLegacyCrypto = true;
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
                  # Kanidm requires every redirect to be a secure origin once one is
                  # https, so http LAN addresses (feanor:<port>) cannot be added
                  # here; app schemes ("opaque origins") can.
                  originUrl = [
                    "${immichUrl}/auth/login"
                    "${immichUrl}/user-settings"
                    "${immichUrl}/api/oauth/mobile-redirect"
                    "app.immich:///oauth-callback"
                  ];
                  originLanding = immichUrl;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/immich/client-secret".path;
                  scopeMaps = makeScopeMaps "immich";
                };

              # Autocaliweb (Calibre-Web fork) has a single "generic" OAuth slot and
              # matches logins to existing users by username, so short usernames
              # land each person on their existing account. Its OAuth library
              # (flask-dance) does not send PKCE; this is a confidential client
              # authenticating with its secret, so PKCE is disabled for it alone.
              autocaliweb =
                let
                  url = "https://${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}";
                in
                {
                  displayName = "Calibre Web eBooks";
                  originUrl = "${url}/login/generic/authorized";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/autocaliweb/client-secret".path;
                  preferShortUsername = true;
                  allowInsecureClientDisablePkce = true;
                  scopeMaps = makeScopeMaps "autocaliweb";
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
                # Must equal PodFetch's OIDC_REDIRECT_URI exactly (see docker/podfetch.nix
                # for why it is /ui/ and not /ui/login).
                originUrl = "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}/ui/";
                originLanding = "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}";
                scopeMaps = makeScopeMaps "podfetch";
              };

              # Kavita's OIDC callback is the fixed path /signin-oidc, and Kanidm
              # matches redirect URIs exactly.
              kavita = {
                displayName = "Kavita Comics";
                originUrl = "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}/signin-oidc";
                originLanding = "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/kavita/client-secret".path;
                scopeMaps = makeScopeMaps "kavita";
              };

              # Served on the personal domain (see estel's caddy.nix), not homeDomain.
              kavitan = {
                displayName = "Kavita Private Comics";
                originUrl = "https://${configVars.networking.subdomains.kavitan}.${configVars.domain}/signin-oidc";
                originLanding = "https://${configVars.networking.subdomains.kavitan}.${configVars.domain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/kavitan/client-secret".path;
                scopeMaps = makeScopeMaps "kavitan";
              };

              # Served on the personal domain (see estel's caddy.nix), not homeDomain.
              openwebui =
                let
                  url = "https://${configVars.networking.subdomains.openwebui}.${configVars.domain}";
                in
                {
                  displayName = "Open WebUI";
                  originUrl = "${url}/oauth/oidc/callback";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/openwebui/client-secret".path;
                  scopeMaps = makeScopeMaps "openwebui";
                };

              # Audiobookshelf keeps its OIDC settings in its own database (set in
              # its admin UI); the secret there must equal this sops one.
              # The mobile app comes back through the server's mobile-redirect.
              audiobookshelf =
                let
                  url = "https://${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}";
                in
                {
                  displayName = "Audiobookshelf";
                  # App schemes are "opaque origins" to Kanidm and allowed beside
                  # https; plain http (LAN) ones are not (see Immich).
                  originUrl = [
                    "${url}/auth/openid/callback"
                    "${url}/auth/openid/mobile-redirect"
                    "audiobookshelf://oauth"
                    "lissen://oauth" # Lissen, a third-party Android client
                  ];
                  originLanding = url;
                  preferShortUsername = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/audiobookshelf/client-secret".path;
                  scopeMaps = makeScopeMaps "audiobookshelf";
                };

              nas = {
                displayName = "Cirdan NAS (DSM)";
                originUrl = "https://${configVars.networking.subdomains.nas}.${configVars.homeDomain}";
                originLanding = "https://${configVars.networking.subdomains.nas}.${configVars.homeDomain}";
                basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/nas/client-secret".path;
                scopeMaps = makeScopeMaps "nas";
              };

              # Behind oauth2-proxy on estel, which passes the short username on
              # for TubeArchivist's forward-auth login.
              tubearchivist =
                let
                  url = "https://${configVars.networking.subdomains.tubearchivist}.${configVars.domain}";
                in
                {
                  displayName = "TubeArchivist";
                  originUrl = "${url}/oauth2/callback";
                  originLanding = url;
                  preferShortUsername = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oauth2/tubearchivist/client-secret".path;
                  scopeMaps = makeScopeMaps "tubearchivist";
                };

              # Beszel (PocketBase) keeps its OAuth2 provider settings in its own
              # database; the client secret is the sops one below.
              beszel =
                let
                  url = "https://${configVars.networking.subdomains.beszel}.${configVars.homeDomain}";
                in
                {
                  displayName = "Beszel Dashboards";
                  originUrl = "${url}/api/oauth2-redirect";
                  originLanding = url;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/beszel/client-secret".path;
                  scopeMaps = makeScopeMaps "beszel";
                };

              # Link-only tiles: Kanidm lists only OAuth2 clients, so these exist
              # to put a launcher on the apps page. Nothing logs in through them
              # (no basicSecretFile; Kanidm generates an unused secret).
              stash =
                let
                  url = "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
                in
                {
                  displayName = "Stash";
                  originUrl = url;
                  originLanding = url;
                  scopeMaps = makeScopeMaps "stash";
                };
              archerstash =
                let
                  url = "https://${configVars.networking.subdomains.archerstash}.${configVars.domain}";
                in
                {
                  displayName = "Archer Stash";
                  originUrl = url;
                  originLanding = url;
                  scopeMaps = makeScopeMaps "archerstash";
                };

              # Container manager on feanor, LAN-only behind estel's Caddy.
              komodo =
                let
                  url = "https://${configVars.networking.subdomains.komodo}.${configVars.homeDomain}";
                in
                {
                  displayName = "Komodo Containers";
                  originUrl = "${url}/auth/oidc/callback";
                  originLanding = url;
                  preferShortUsername = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/komodo/client-secret".path;
                  scopeMaps = makeScopeMaps "komodo";
                };

              # Shown to everyone now; the redirect is the one the Jellyfin SSO
              # plugin uses for a provider named "kanidm", ready for when Jellyfin
              # itself is wired up (its secret is the sops one below).
              jellyfin =
                let
                  url = "https://${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}";
                in
                {
                  displayName = "Jellyfin";
                  # The SSO plugin builds the callback from the provider's name,
                  # and Kanidm matches it case-sensitively; the provider in
                  # Jellyfin is named "Kanidm".
                  originUrl = [
                    "${url}/sso/OID/redirect/Kanidm"
                    "${url}/sso/OID/redirect/kanidm"
                  ];
                  originLanding = url;
                  preferShortUsername = true;
                  basicSecretFile = config.sops.secrets."homelab/kanidm/oidc/jellyfin/client-secret".path;
                  scopeMaps = makeScopeMaps "jellyfin";
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
        sops.secrets."homelab/kanidm/oauth2/whisparr-eros/client-secret" = {
          owner = "kanidm";
          group = "keys";
          mode = "0440";
        };
        sops.secrets."homelab/kanidm/oauth2/whisparr/client-secret" = {
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
        sops.secrets."homelab/kanidm/oidc/autocaliweb/client-secret" = {
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
        sops.secrets."homelab/kanidm/oidc/beszel/client-secret" = {
          owner = "kanidm";
        };
        sops.secrets."homelab/kanidm/oidc/komodo/client-secret" = {
          owner = "kanidm";
        };
        sops.secrets."homelab/kanidm/oidc/audiobookshelf/client-secret" = {
          owner = "kanidm";
        };
        sops.secrets."homelab/kanidm/oidc/jellyfin/client-secret" = {
          owner = "kanidm";
        };
        sops.secrets."homelab/kanidm/oauth2/tubearchivist/client-secret" = {
          owner = "kanidm";
        };

        # Note: User passwords must be set via Kanidm web UI at https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}
        # or via kanidm CLI after initial provisioning. Declarative passwordFile is not supported.
      }

      {
        services.kanidm.provision.systems.oauth2 =
          lib.mapAttrs (_: image: { imageFile = image; }) clientIcons
          // lib.genAttrs inactiveClients (name: {
            imageFile = clientIcons.${name} or null;
            # No scope map: nobody may use it, so it is off every apps page.
            scopeMaps = lib.mkForce { };
          });
      }

      # Apps-page order. Kanidm lists a user's apps in creation order (its
      # list_applinks does no sorting) and has no categories, so the order is
      # imposed by creation: configVars.sso.appCategories gives the category
      # order, apps sort by display name within a category, uncategorised
      # clients go last. When that order changes (or on first run), every
      # client is deleted and re-created bare in order, then Kanidm restarts
      # so provisioning fills in the rest. Costs of a re-order: a few seconds
      # of SSO downtime, and every app's grants/refresh tokens are dropped, so
      # users pass through Kanidm (and may see a consent page) once per app.
      # Secrets survive because every client in use has a basicSecretFile;
      # the link-only Stash tiles just get new, unused ones.
      # (Deleting through provisioning, `present = false`, crashes it; see
      # inactiveClients above.)
      (
        let
          clients = config.services.kanidm.provision.systems.oauth2;
          lower = lib.toLower;
          byDisplayName =
            names: lib.sort (a: b: lower clients.${a}.displayName < lower clients.${b}.displayName) names;
          categorised = lib.concatMap (cat: byDisplayName (lib.filter (n: clients ? ${n}) cat.apps)) (
            configVars.sso.appCategories or [ ]
          );
          ordered = categorised ++ byDisplayName (lib.subtractLists categorised (lib.attrNames clients));
          # One line per client: name, kind, display name, landing URL.
          plan = lib.concatMapStringsSep "\n" (
            n:
            lib.concatStringsSep "\t" [
              n
              (if clients.${n}.public then "public" else "basic")
              clients.${n}.displayName
              clients.${n}.originLanding
            ]
          ) ordered;
          planFile = pkgs.writeText "kanidm-app-order" (plan + "\n");
          stateFile = "/var/lib/kanidm/.app-order"; # in the persisted state dir
        in
        lib.mkIf (configVars.sso ? appCategories) {
          systemd.services.kanidm-app-order = {
            description = "Re-create Kanidm OAuth2 clients in apps-page order when it changes";
            after = [ "kanidm.service" ];
            wants = [ "kanidm.service" ];
            wantedBy = [
              "kanidm.service"
              "multi-user.target"
            ];
            restartTriggers = [ planFile ];
            path = [
              config.services.kanidm.package
              pkgs.coreutils
              pkgs.diffutils
              config.systemd.package
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              RuntimeDirectory = "kanidm-app-order";
              RuntimeDirectoryMode = "0700";
            };
            script = ''
              if cmp -s ${planFile} ${stateFile}; then
                echo "Apps-page order unchanged."
                exit 0
              fi
              export HOME="$RUNTIME_DIRECTORY"
              KANIDM_PASSWORD=$(< ${config.services.kanidm.provision.idmAdminPasswordFile})
              export KANIDM_PASSWORD
              kanidm login -D idm_admin >/dev/null

              # If anything below fails, provisioning (run by a Kanidm restart)
              # re-creates whatever is missing, just not in order; the order file
              # is not written, so the next start tries again.
              trap 'echo "re-ordering failed; restarting Kanidm to restore clients" >&2; systemctl --no-block restart kanidm.service' ERR

              echo "Apps-page order changed; re-creating clients in order."
              while IFS=$'\t' read -r name _ _ _; do
                kanidm system oauth2 delete "$name" -D idm_admin >/dev/null 2>&1 || true
              done < ${planFile}
              while IFS=$'\t' read -r name kind display landing; do
                if [ "$kind" = public ]; then
                  kanidm system oauth2 create-public "$name" "$display" "$landing" -D idm_admin >/dev/null
                else
                  kanidm system oauth2 create "$name" "$display" "$landing" -D idm_admin >/dev/null
                fi
                echo "  $name"
              done < ${planFile}
              kanidm logout -D idm_admin >/dev/null || true

              cp ${planFile} ${stateFile}
              # Provisioning runs as part of kanidm.service's start.
              systemctl --no-block restart kanidm.service
            '';
          };
        }
      )

      # Provisioning adds declared scope maps but never removes others, so a
      # client that was just disabled would keep its old ones. Strip them
      # after each start (as idm_admin, like provisioning itself).
      (lib.mkIf (inactiveClients != [ ]) {
        systemd.services.kanidm-inactive-clients = {
          description = "Remove scope maps from Kanidm clients of disabled services";
          after = [ "kanidm.service" ];
          requires = [ "kanidm.service" ];
          wantedBy = [
            "kanidm.service"
            "multi-user.target"
          ];
          restartTriggers = inactiveClients;
          path = [
            config.services.kanidm.package
            pkgs.gawk
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "kanidm";
            Group = "kanidm";
            RuntimeDirectory = "kanidm-inactive-clients";
            RuntimeDirectoryMode = "0700";
          };
          script = ''
            export HOME="$RUNTIME_DIRECTORY"
            KANIDM_PASSWORD=$(< ${config.services.kanidm.provision.idmAdminPasswordFile})
            export KANIDM_PASSWORD
            kanidm login -D idm_admin >/dev/null
            for client in ${lib.escapeShellArgs inactiveClients}; do
              # "oauth2_rs_scope_map: <group>@<domain>: {...}"
              for group in $(kanidm system oauth2 get "$client" -D idm_admin |
                awk -F': ' '/^oauth2_rs_scope_map:/ { sub(/@.*/, "", $2); print $2 }'); do
                echo "$client: removing scope map for $group"
                kanidm system oauth2 delete-scope-map "$client" "$group" -D idm_admin
              done
            done
            kanidm logout -D idm_admin >/dev/null || true
          '';
        };
      })

      # Domain display name and login-page logo. kanidm-provision cannot set
      # these, and only the system `admin` account may (idm_admin cannot even
      # read them). The values live in nix-secrets (sso.branding) because they
      # name the family; nothing is applied until they exist there.
      #
      # Each run gives `admin` a fresh random password through kanidmd's
      # recover-account (the same mechanism the NixOS module uses for idm_admin),
      # logs in with it and applies both settings. Nothing else signs in as
      # admin; to use it by hand, recover it the same way:
      #   sudo -u kanidm kanidmd recover-account -c <server.toml> admin
      (lib.mkIf (configVars.sso ? branding) (
        let
          branding = configVars.sso.branding;
          # The module's generated server.toml, as kanidm.service is started with.
          serverConfigFile = builtins.head (
            builtins.match ".* -c ([^ ]+).*" config.systemd.services.kanidm.serviceConfig.ExecStart
          );
        in
        {
          systemd.services.kanidm-branding = {
            description = "Apply Kanidm domain display name and logo";
            after = [ "kanidm.service" ];
            requires = [ "kanidm.service" ];
            # Re-apply whenever Kanidm (re)starts, and when the branding changes.
            wantedBy = [ "kanidm.service" ];
            restartTriggers = [
              branding.displayName
              branding.image
            ];
            path = [
              config.services.kanidm.package
              pkgs.openssl
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "kanidm";
              Group = "kanidm";
              RuntimeDirectory = "kanidm-branding";
              RuntimeDirectoryMode = "0700";
            };
            script = ''
              export HOME="$RUNTIME_DIRECTORY"
              KANIDM_RECOVER_ACCOUNT_PASSWORD=$(openssl rand -base64 36)
              export KANIDM_RECOVER_ACCOUNT_PASSWORD
              kanidmd scripting recover-account -c ${serverConfigFile} admin --from-environment >/dev/null

              KANIDM_PASSWORD=$KANIDM_RECOVER_ACCOUNT_PASSWORD
              export KANIDM_PASSWORD
              kanidm login -D admin >/dev/null
              kanidm system domain set-displayname -D admin ${lib.escapeShellArg branding.displayName}
              kanidm system domain set-image -D admin ${branding.image}
              kanidm logout -D admin >/dev/null || true
            '';
          };
        }
      ))
    ]
  );
}
