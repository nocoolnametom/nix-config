{
  config,
  lib,
  configVars,
  ...
}:
with lib; {
  options.services.ssoProvider = mkOption {
    type = types.attrsOf (types.nullOr (types.enum [ "authentik" "kanidm-oauth2" "kanidm-oidc" ]));
    default = { };
    description = ''
      SSO provider configuration per service.
      Maps service names to their SSO provider type:
      - "authentik": Use Authentik proxy (existing)
      - "kanidm-oauth2": Use Kanidm via OAuth2-proxy (for services without native OIDC)
      - "kanidm-oidc": Use Kanidm via native OIDC (for services with OIDC support)
      - null: Direct access, no SSO
    '';
  };

  # Helper functions for SSO provider configuration
  config.lib.sso = {
    # Get proxy user header for a service
    getProxyUserHeader =
      service:
      let
        provider = config.services.ssoProvider.${service} or null;
      in
      if provider == "kanidm-oauth2" then
        "X-Forwarded-User"
      else if provider == "authentik" then
        "X-Authentik-Username"
      else
        null;

    # Get OIDC configuration URL for a service
    getOidcConfigUrl =
      service: provider:
      if provider == "kanidm-oidc" then
        "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/${service}/.well-known/openid-configuration"
      else # authentik
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${service}/.well-known/openid-configuration";

    # Get proxy host IP (where the proxy/SSO server runs)
    getProxyHost =
      service: hostRunningService:
      let
        provider = config.services.ssoProvider.${service} or null;
      in
      if provider == "kanidm-oauth2" then
        configVars.networking.subnets.${hostRunningService}.ip # OAuth2-proxy runs with service
      else if provider == "authentik" then
        configVars.networking.subnets.cirdan.ip # Authentik server
      else
        null;

    # Get SSO provider for a service
    getProvider = service: config.services.ssoProvider.${service} or null;

    # Check if service uses a specific provider
    usesProvider =
      service: providerType:
      (config.services.ssoProvider.${service} or null) == providerType;
  };
}
