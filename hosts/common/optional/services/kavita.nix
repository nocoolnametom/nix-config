{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
let
  kavitaSsoProvider = config.services.ssoProvider.kavita or "authentik";
  kavitanSsoProvider = config.services.ssoProvider.kavitan or "authentik";
  kavitaUseKanidm = kavitaSsoProvider == "kanidm-oidc";
  kavitanUseKanidm = kavitanSsoProvider == "kanidm-oidc";

  # How Kavita (0.9.x) splits its OIDC configuration, which decides what Nix
  # can own:
  #   - appsettings.json `OpenIdConnectSettings` {Authority, ClientId, Secret,
  #     CustomScopes} is read at startup to build the OIDC handler, and
  #     Seed.SetOidcSettingsFromDisk copies those four fields over the database
  #     copy on every start. The file wins, so these are declarative here.
  #     (There is no `Enabled` key: Kavita derives it from the three strings.)
  #   - Everything else (ProvisionAccounts, AutoLogin, DisablePasswordAuthentication,
  #     DefaultRoles/Libraries, ...) lives only in the ServerSetting table and is
  #     set in the admin UI. Nix cannot see or reset it.
  #   - Editing Authority/ClientId/Secret in the UI writes appsettings.json, but
  #     preStart overwrites the file from Nix, so the UI edit reverts on the next
  #     restart. Change them here instead.
  #   - Changing Authority from the UI clears every user's stored OIDC id;
  #     changing it through this file does NOT. After switching providers, clear
  #     AspNetUsers.OidcId (with the service stopped) or the first login fails
  #     with "email-in-use", because the new provider's subject differs.
  #   - HostName and BaseUrl-in-UI are ServerSetting rows; a HostName key in
  #     appsettings.json is ignored, so it is not set here.
  mkOidcSettings =
    {
      useKanidm,
      clientName,
      authentikClient,
    }:
    {
      Authority = lib.mkDefault (
        if useKanidm then
          "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/${clientName}"
        else
          "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${clientName}/"
      );
      CustomScopes = lib.mkDefault [ ];
      ClientId = lib.mkDefault (if useKanidm then clientName else authentikClient.ClientId);
      # With Kanidm the secret comes from sops at service start (see
      # mkOidcSecretInjection), so it never lands in the Nix store.
      Secret = lib.mkDefault (if useKanidm then "@OIDC_SECRET@" else authentikClient.Secret);
    };

  # Replace the @OIDC_SECRET@ placeholder after the module's preStart has
  # installed appsettings.json (mkAfter orders it behind the @TOKEN@ step).
  mkOidcSecretInjection = service: dataDir: {
    systemd.services.${service} = {
      serviceConfig.LoadCredential = [
        "oidc-secret:${config.sops.secrets."kanidm-oidc-${service}-client-secret".path}"
      ];
      preStart = lib.mkAfter ''
        ${pkgs.replace-secret}/bin/replace-secret '@OIDC_SECRET@' \
          ''${CREDENTIALS_DIRECTORY}/oidc-secret \
          '${dataDir}/config/appsettings.json'
      '';
    };
    # Same value Kanidm provisions the client with, exposed a second time so
    # the Kavita service user can read it.
    sops.secrets."kanidm-oidc-${service}-client-secret" = {
      key = "homelab/kanidm/oidc/${service}/client-secret";
      owner = config.systemd.services.${service}.serviceConfig.User;
    };
  };
in
{
  config = lib.mkMerge [
    {
      services.kavita.enable = lib.mkDefault true;
      services.kavita.package = lib.mkDefault pkgs.unstable.kavita;
      services.kavita.settings.BaseUrl = lib.mkDefault null;
      services.kavita.settings.Cache = lib.mkDefault 75;
      services.kavita.settings.AllowIFraming = lib.mkDefault false;
      services.kavita.settings.Port = lib.mkDefault configVars.networking.ports.tcp.kavita;
      services.kavita.settings.OpenIdConnectSettings = mkOidcSettings {
        useKanidm = kavitaUseKanidm;
        clientName = "kavita";
        authentikClient = configVars.networking.oidc.kavita;
      };
      services.kavita.tokenKeyFile = lib.mkDefault config.sops.secrets."kavita-token".path;
      sops.secrets."kavita-token".owner =
        if config.services.kavita.enable then config.systemd.services.kavita.serviceConfig.User else "root";

      services.kavitan.enable = lib.mkDefault true;
      services.kavitan.package = lib.mkDefault pkgs.unstable.kavita;
      services.kavitan.settings.BaseUrl = lib.mkDefault null;
      services.kavitan.settings.Cache = lib.mkDefault 75;
      services.kavitan.settings.AllowIFraming = lib.mkDefault false;
      services.kavitan.settings.Port = lib.mkDefault configVars.networking.ports.tcp.kavitan;
      services.kavitan.settings.OpenIdConnectSettings = mkOidcSettings {
        useKanidm = kavitanUseKanidm;
        clientName = "kavitan";
        authentikClient = configVars.networking.oidc.kavitan;
      };
      services.kavitan.tokenKeyFile = lib.mkDefault config.sops.secrets."kavitan-token".path;
      sops.secrets."kavitan-token".owner =
        if config.services.kavitan.enable then
          config.systemd.services.kavitan.serviceConfig.User
        else
          "root";
      users.users.kavitan.extraGroups = [ config.users.groups.datadat.name ];

      # Caddy runs on estel, so the readers must be reachable over the LAN.
      networking.firewall.allowedTCPPorts =
        lib.optional config.services.kavita.enable config.services.kavita.settings.Port
        ++ lib.optional config.services.kavitan.enable config.services.kavitan.settings.Port;
    }

    (lib.mkIf (kavitaUseKanidm && config.services.kavita.enable) (
      mkOidcSecretInjection "kavita" config.services.kavita.dataDir
    ))
    (lib.mkIf (kavitanUseKanidm && config.services.kavitan.enable) (
      mkOidcSecretInjection "kavitan" config.services.kavitan.dataDir
    ))

    # Kavita fetches the provider's discovery document while building the OIDC
    # handler at startup. If that fails it logs an error and skips scope
    # filtering, so Kanidm then rejects the unsupported offline_access/roles
    # scopes Kavita always asks for. When Kanidm runs on the same host, start
    # after it.
    (lib.mkIf (config.services.kanidmSso.enable or false) {
      systemd.services.kavita = lib.mkIf kavitaUseKanidm {
        after = [ "kanidm.service" ];
        wants = [ "kanidm.service" ];
      };
      systemd.services.kavitan = lib.mkIf kavitanUseKanidm {
        after = [ "kanidm.service" ];
        wants = [ "kanidm.service" ];
      };
    })
  ];
}
