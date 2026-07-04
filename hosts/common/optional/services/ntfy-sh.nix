{
  lib,
  inputs,
  config,
  pkgs,
  configVars,
  ...
}:
let
  # Derive ntfy users from the existing SSO user list in nix-secrets.
  # Passwords come from nix-secrets SOPS as ntfy/<username>.
  # Admin role is granted to anyone in the server-admins SSO group.
  ntfyUsers = lib.mapAttrsToList (name: user: {
    inherit name;
    role = if lib.elem "server-admins" user.groups then "admin" else "user";
  }) inputs.nix-secrets.sso.users;

  authFile = "/var/lib/ntfy-sh/user.db";
  ntfyBin = "${pkgs.ntfy-sh}/bin/ntfy";
in
{
  services.ntfy-sh.enable = lib.mkDefault true;
  services.ntfy-sh.settings.listen-http = "127.0.0.1:${builtins.toString configVars.networking.ports.tcp.ntfy}";
  services.ntfy-sh.settings.base-url = "https://${configVars.networking.subdomains.ntfy}.${configVars.homeDomain}";
  services.ntfy-sh.settings.behind-proxy = true;
  # When auth-file is present (set automatically by the NixOS module), ntfy denies
  # anonymous access by default. Explicit read-write allows unauthenticated fallback
  # while still enforcing credentials when provided.
  services.ntfy-sh.settings.auth-default-access = "read-write";

  # One sops secret per SSO user — each file contains only the plaintext password.
  # In nix-secrets, add these under the ntfy key in the relevant SOPS YAML, e.g.:
  #   ntfy:
  #     username1: "somepassword"
  #     username2: "somepassword"
  # Extra ntfy/* secrets beyond the SSO user list are ignored.
  sops.secrets = lib.listToAttrs (map (u: lib.nameValuePair "ntfy/${u.name}" { }) ntfyUsers);

  # Sync declared users into ntfy's SQLite DB on every boot/rebuild.
  # Idempotent: creates users that don't exist, updates passwords and roles for those that do.
  systemd.services.ntfy-user-sync = {
    description = "Sync ntfy users from declarative config";
    after = [
      "ntfy-sh.service"
      "sops-install-secrets.service"
    ];
    wants = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ntfy-user-sync" ''
        set -euo pipefail
        export NTFY_AUTH_FILE="${authFile}"

        setup_user() {
          local user=$1 role=$2 pass_file=$3
          local pass
          pass=$(cat "$pass_file")
          # Try to add; if user already exists, update password and role instead.
          if ! printf '%s\n%s\n' "$pass" "$pass" | ${ntfyBin} user add --role="$role" "$user" 2>/dev/null; then
            printf '%s\n%s\n' "$pass" "$pass" | ${ntfyBin} user change-pass "$user"
            ${ntfyBin} user change-role "$user" "$role"
          fi
        }

        ${lib.concatMapStrings (u: ''
          setup_user "${u.name}" "${u.role}" "${config.sops.secrets."ntfy/${u.name}".path}"
        '') ntfyUsers}
      '';
      User = "root";
    };
  };
}
