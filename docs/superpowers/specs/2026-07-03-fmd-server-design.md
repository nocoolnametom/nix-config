# fmd-server NixOS Module Design

Adds an fmd-server (FindMyDevice) service to the repo: one reusable NixOS
module, one host-style opt-in module, and estel wiring.

`fmd-server` v0.15.0 is already available in nixpkgs. The nixpkgs package
ships only the binary (`bin/fmd-server`, `bin/ctl`) — no NixOS module. This
repo will provide one, modeled on `modules/nixos/kavitan.nix`.

## Non-goals

- No OIDC / SSO wrapping. fmd-server handles its own security via
  the `RegistrationToken` config key.
- No TLS termination in fmd-server itself — Caddy terminates.

## New file: `modules/nixos/fmd.nix`

Owns the user, group, dataDir, config file generation, and systemd unit.

Options under `services.fmd`:

| Option | Type | Default | Notes |
|---|---|---|---|
| `enable` | bool | `false` | Standard `mkEnableOption` |
| `package` | package | `pkgs.fmd-server` | `mkPackageOption` |
| `user` | str | `"fmd"` | System user |
| `group` | str | `"fmd"` | System group |
| `dataDir` | str | `"/var/lib/fmd"` | Home for config, DB, logs |
| `openFirewall` | bool | `false` | If true, opens `settings.PortInsecure` |
| `registrationTokenFile` | nullOr path | `null` | Optional secret file; loaded via `LoadCredential` and interpolated into config at `preStart` |
| `settings` | submodule | see below | YAML config, freeform |

`settings` uses `pkgs.formats.yaml { }` with a freeform type. Typed
sub-options with defaults:

- `PortInsecure` — str, default `"8080"` (fmd-server represents ports as strings)
- `PortSecure` — str, default `""` (disabled; Caddy terminates TLS)
- `DatabaseDir` — str, default `"${cfg.dataDir}/db/"`

All other fmd-server keys (`UnixSocketPath`, `MaxSavedLoc`, `MaxSavedPic`,
`RemoteIpHeader`, `TileServerUrl`, `MetricsAddrPort`, etc.) are settable via
the freeform type without needing explicit sub-options.

### Runtime behavior

- Config file materialization: nix generates a YAML file. If
  `registrationTokenFile != null`, the generated YAML contains
  `RegistrationToken: "@REGISTRATION_TOKEN@"` and `preStart` runs
  `replace-secret` (from `pkgs.replace-secret`) against the credential file
  loaded by systemd. Otherwise `preStart` just installs the file.
- Config is copied to `${cfg.dataDir}/config.yml` at `preStart` (owned by
  the service user, mode 0600). The spec calls for the config living in
  the home directory rather than being referenced from `/nix/store`.
- Systemd unit:
  - `ExecStart = "${lib.getExe cfg.package} serve --config ${cfg.dataDir}/config.yml"`
  - `WorkingDirectory = cfg.dataDir`
  - `User`, `Group`, `Restart = "always"`
  - `LoadCredential = [ "registration-token:${cfg.registrationTokenFile}" ]` when set
  - `wantedBy = [ "multi-user.target" ]`, `after = [ "network.target" ]`
- `systemd.tmpfiles.rules` create `${dataDir}` and `${dataDir}/db` at 0750,
  owned by the service user/group.
- `users.users.${cfg.user}` — system user, group = `cfg.group`, home = `dataDir`.
- `users.groups.${cfg.group}` created.
- Registered in `modules/nixos/default.nix`.

## New file: `hosts/common/optional/services/fmd.nix`

Generic opt-in host module. Sets defaults using `configVars`:

```nix
{ lib, configVars, ... }:
{
  services.fmd.enable = lib.mkDefault true;
  services.fmd.settings.PortInsecure =
    lib.mkDefault (builtins.toString configVars.networking.ports.tcp.fmd);
  services.fmd.settings.RemoteIpHeader = lib.mkDefault "X-Forwarded-For";
  services.fmd.openFirewall = lib.mkDefault true;
}
```

If `configVars.networking.ports.tcp.fmd` is absent from nix-secrets,
evaluation fails with a clear attribute error until the user adds it.

## estel edits

- `hosts/estel/default.nix`: add
  `"hosts/common/optional/services/fmd.nix"` to the imports, add `"fmd"`
  to `services.systemd-failure-alert.additional-services`.
- `hosts/estel/caddy.nix`: append
  `{ host = "estel"; service = "fmd"; domain = "homeDomain"; }`
  to `simpleServices`. The generator emits both `fmd.homeDomain` and
  `fmd.punch.homeDomain` (basic-auth) using the port and subdomain from
  nix-secrets.
- `hosts/estel/persistence.nix`: add `"/var/lib/fmd"` to the persisted
  `/var/lib` list.

## Out-of-band prerequisites

The user must add to nix-secrets before rebuilding estel:
- `networking.ports.tcp.fmd` — a free port
- `networking.subdomains.fmd` — the subdomain string (e.g. `"fmd"`)
