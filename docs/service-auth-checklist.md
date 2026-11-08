# Service and Kanidm Authentication Checklist

Use this in order when adding or troubleshooting a service. Check only the
relevant authentication branch. Keep real domains, IPs, credentials and other
identifying values out of this public repository; use `configVars` and
placeholders. Agents must not create or edit secrets: tell the owner which keys
and value constraints are needed.

## 1. Decide and Inventory

- [ ] Record the service name, hosting machine, public hostname and whether it
  uses `homeDomain` or `domain`. Verify the subdomain, host address, service
  port and, for oauth2-proxy, proxy port exist in the private `configVars`.
- [ ] Choose native OIDC, oauth2-proxy, or no SSO. Check upstream documentation
  and source for the deployed version. A login proxy may break APIs, webhooks,
  mobile clients or public links; document and restrict any necessary bypasses.
- [ ] For OIDC, identify the issuer, client ID, exact redirect URI, scopes,
  confidential vs public client, PKCE support, token signing algorithms,
  account matching, registration policy and local administrator fallback.
- [ ] Decide which Kanidm groups may access the service. In
  `hosts/common/optional/services/kanidm.nix`, `makeScopeMaps` uses groups from
  `configVars.sso.groups` that list the service; absent a match, every
  `service_users` member gets access.

## 2. Secrets

- [ ] Ask the owner to provision the required SOPS keys before deployment;
  do not generate, print, commit or edit secret values. Verify that every host
  needing a key can decrypt the relevant SOPS file.
- [ ] A confidential native client normally uses
  `homelab/kanidm/oidc/<service>/client-secret`; a proxy client normally uses
  `homelab/kanidm/oauth2/<service>/client-secret`. The application or proxy
  must use the exact same value as Kanidm. Public clients and link-only tiles
  do not use a provisioned client secret.
- [ ] For oauth2-proxy, also provision
  `homelab/oauth2/<service>/cookie-secret`: it must decode from base64 to
  16, 24 or 32 bytes. Provision any required upstream credentials separately.
- [ ] Check secret paths and runtime ownership on each consuming host. Do not
  assume declaring a SOPS secret on the Kanidm host declares it on estel.

## 3. Service and Network

- [ ] For a declarative service, use a shared optional module and a thin host
  config. For a Komodo experiment, record its image and version, published
  port, environment, state directory and deployment ownership outside this
  repository; do not put credentials in the public repo.
- [ ] Verify container or service port bindings, host firewall rules, and the
  actual upstream URL from the proxy host. Check the service's own health
  endpoint or root page directly before debugging authentication.
- [ ] Identify persistent state, databases and volumes. On impermanent hosts,
  persist the actual backing directories and confirm backups and restore
  requirements. Do not assume a running container implies persistent data.

## 4. Kanidm Client

- [ ] Add the client in `hosts/common/optional/services/kanidm.nix`: native
  OIDC clients in the native client definitions; proxy clients in `proxyClients`.
  Set the correct domain, landing URL and exact callback. Keep PKCE and ES256
  enabled unless the application's documented limitations require otherwise.
- [ ] Confirm the generated secret path, group scope maps and, if applicable,
  public client or link-only exception. For locally hosted or manually managed
  services, review `localServiceEnabled`; a disabled client has no scope map.
- [ ] Verify the client-specific issuer is
  `https://<sso-host>/oauth2/openid/<client-id>`, not the Kanidm root. The
  discovery document is that issuer followed by
  `/.well-known/openid-configuration`. For native OIDC, configure the same
  issuer, client ID, redirect and secret in the application.
- [ ] Review the apps-page ordering service before deployment: a changed order
  can recreate clients, briefly interrupt SSO and invalidate existing grants
  and refresh tokens. Do not delete provisioned clients to hide them; follow
  the inactive-client mechanism in the module.

## 5. Proxy and Caddy

- [ ] For native OIDC, route Caddy directly to the service and configure OIDC
  in the application. Check reverse-proxy trust settings and preserve a local
  admin login where supported.
- [ ] For oauth2-proxy, add or check the instance and its secret names in
  `hosts/common/optional/services/oauth2-proxy.nix`: upstream host and port,
  issuer, client ID, client secret, cookie secret and any header, health or
  bypass requirements. Add the name to `homeDomainInstances` when appropriate.
- [ ] Enable the instance on its proxy host, normally in
  `hosts/estel/default.nix` under `services.homelab-oauth2-proxy.instances`.
  Defining an instance alone does not start it or declare its runtime secrets.
- [ ] Add or check the entry in `hosts/estel/caddy.nix`: service host, domain
  and `proxy = "oauth2"` when applicable. Confirm Caddy's selected proxy port
  matches the enabled instance. Verify DNS, TLS, firewall and any LAN-only or
  public exposure restrictions.

## 6. Evaluate, Deploy, Verify

- [ ] Evaluate the full configuration for every changed host, for example
  `nix eval .#nixosConfigurations.estel.config.system.build.toplevel --apply 'drv: drv.drvPath'`.
  Evaluate the individual client and proxy options too; compare the proxy
  `externalUrl` with Kanidm's `originLanding`, and ensure `originUrl` is the
  exact callback. Confirm the configuration being evaluated includes the
  intended working-tree changes.
- [ ] Deploy the appropriate committed configuration using the host's normal
  deployment workflow. Provision secrets first; bring up the service and
  Kanidm client before routing users through an enabled proxy. Do not switch a
  production host without accounting for the SSO ordering side effects above.
- [ ] Check the service, proxy, Caddy and Kanidm unit status and logs on their
  respective hosts. For a proxy named `<service>`, inspect
  `systemctl status oauth2-proxy-<service>` and
  `journalctl -u oauth2-proxy-<service>` on the proxy host. Redact secrets,
  cookies, authorization codes and tokens from shared output.
- [ ] Confirm discovery succeeds, then test a real browser login and logout,
  an allowed user and a denied user, and any required API or mobile workflow.
  Check access restrictions and persistence after an appropriate restart.
  An HTTP 200 or successful Nix evaluation alone does not verify login.

## Quick Diagnosis

- **502:** trace Caddy to the actual listener. Check that the selected
  oauth2-proxy instance is enabled and running, its port matches Caddy, and
  the upstream host and port are reachable. A healthy app container does not
  imply its authentication proxy is running.
- **Discovery failure or 404:** check the client exists in the deployed Kanidm
  configuration and use its client-specific issuer.
- **Redirect or token exchange failure:** compare the exact callback, client
  ID and shared secret; inspect PKCE and signing-algorithm compatibility.
- **Access denied:** inspect Kanidm group scope maps and application account,
  registration and email-claim requirements.

## Duplication to Review

Service identity, domain and ports are currently repeated across Caddy,
Kanidm, oauth2-proxy definitions and proxy-host enablement. Client-secret names
also appear in both Kanidm and proxy configuration. These are candidates for a
shared service inventory and generated assertions, but preserve explicit
per-service exceptions, secret ownership and host-specific opt-in. The
Open Resume 502 occurred because its Caddy route and proxy definition existed
while the proxy instance was not enabled.
