# ntfy-sh Service + Move fmd to bombadil

Adds an ntfy-sh (UnifiedPush) host module and relocates the fmd service
from estel to bombadil, so both services are hosted on the VPS without
being reverse-proxied through estel.

## Non-goals

- No new NixOS module for ntfy-sh — nixpkgs already provides
  `services.ntfy-sh`.
- No auth-file on ntfy-sh; UnifiedPush relies on topic-name obscurity.
- No data migration of fmd from estel — instance was freshly stood up
  today with no accounts registered.

## New file: `hosts/common/optional/services/ntfy-sh.nix`

Behavior-only host module, mirroring `audiobookshelf.nix`:

```nix
{ lib, configVars, ... }:
{
  services.ntfy-sh.enable = lib.mkDefault true;
  services.ntfy-sh.settings.listen-http =
    lib.mkDefault "127.0.0.1:${builtins.toString configVars.networking.ports.tcp.nfty}";
  services.ntfy-sh.settings.base-url =
    lib.mkDefault "https://${configVars.networking.subdomains.nfty}.${configVars.homeDomain}";
  services.ntfy-sh.settings.behind-proxy = lib.mkDefault true;
}
```

Everything else keeps the nixpkgs defaults (auth-file, attachment-cache-dir,
cache-file all under `/var/lib/ntfy-sh`). `behind-proxy = true` tells ntfy
to honour `X-Forwarded-For` from nginx.

The `nfty` (n-f-t-y) key comes from nix-secrets and is used verbatim —
subdomain becomes `nfty.doggett.family`.

## bombadil edits

**`hosts/bombadil/default.nix`**
- Add to `configLib.relativeToRoot` imports:
  - `"hosts/common/optional/services/fmd.nix"`
  - `"hosts/common/optional/services/ntfy-sh.nix"`
- Add to `services.systemd-failure-alert.additional-services`:
  - `"fmd"`
  - `"ntfy-sh"`

**`hosts/bombadil/nginx.nix`** — add two virtualHosts (uptime-kuma pattern):

```nix
services.nginx.virtualHosts."${configVars.networking.subdomains.fmd}.${configVars.homeDomain}" =
  lib.mkIf config.services.fmd.enable {
    enableACME = true;
    http2 = true;
    forceSSL = true;
    locations."/".proxyPass =
      "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.fmd}";
  };

services.nginx.virtualHosts."${configVars.networking.subdomains.nfty}.${configVars.homeDomain}" =
  lib.mkIf config.services.ntfy-sh.enable {
    enableACME = true;
    http2 = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.nfty}";
      proxyWebsockets = true;
    };
  };
```

`proxyWebsockets = true` on ntfy so the `/topic/ws` subscriber endpoint
works.

**`hosts/bombadil/persistence.nix`** — add:
- `"/var/lib/fmd"`
- `"/var/lib/ntfy-sh"`

## HAProxy ACLs — required

`hosts/common/optional/services/haproxy-sni-router.nix`: without new
ACLs, `fmd.doggett.family` and `nfty.doggett.family` fall through to the
default backend (estel via WireGuard). Add exact-match ACLs (not
`hdr_beg`/`-m beg`) using nix-secrets values, and route to bombadil's
local nginx.

**http_frontend** (:80):
```
acl is_fmd_home  hdr(host) -i ${configVars.networking.subdomains.fmd}.${configVars.homeDomain}
acl is_nfty_home hdr(host) -i ${configVars.networking.subdomains.nfty}.${configVars.homeDomain}
use_backend bombadil_http if is_fmd_home
use_backend bombadil_http if is_nfty_home
```

**https_frontend** (:443):
```
acl is_fmd_home  req_ssl_sni -i ${configVars.networking.subdomains.fmd}.${configVars.homeDomain}
acl is_nfty_home req_ssl_sni -i ${configVars.networking.subdomains.nfty}.${configVars.homeDomain}
use_backend bombadil_https if is_fmd_home
use_backend bombadil_https if is_nfty_home
```

The module is already gated `lib.mkIf isBombadil`, so only bombadil is affected.

## estel cleanup

- `hosts/estel/default.nix`: remove the
  `"hosts/common/optional/services/fmd.nix"` import and remove `"fmd"`
  from `services.systemd-failure-alert.additional-services`.
- `hosts/estel/caddy.nix`: remove the
  `{ host = "estel"; service = "fmd"; domain = "homeDomain"; }`
  entry from `simpleServices`.
- `hosts/estel/persistence.nix`: remove `"/var/lib/fmd"`.
- `/persist/var/lib/fmd` on estel remains on disk but is no longer
  bind-mounted. User can `rm -rf` at their leisure.

## Rollout

1. Push nix-config to origin.
2. `nixos-rebuild switch` on bombadil first — services come up, nginx
   requests ACME certs for both subdomains via HTTP-01, HAProxy ACLs
   direct challenge traffic to local nginx.
3. `nixos-rebuild switch` on estel to drop fmd.
4. Repoint phone apps at the new URLs.
