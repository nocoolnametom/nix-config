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
  # Use unstable to track the most recent stable-ish ntfy version.
  ntfyPackage = pkgs.unstable.ntfy-sh;
  ntfyBin = "${ntfyPackage}/bin/ntfy";

  # Subscriber on the phone: the family admin account, which bypasses ACLs.
  slkUser = configVars.username;
  # Account that owns the Hermes gateway publisher token for the private
  # Slack triage topic (created on bombadil with `ntfy token add`; the token
  # lives in nix-secrets).
  slkPublisherUser = "hermes-alerts";
  slkTopic = configVars.ntfy.topics.important-slacks;
in
{
  services.ntfy-sh.enable = lib.mkDefault true;
  services.ntfy-sh.package = ntfyPackage;
  services.ntfy-sh.settings.listen-http = "127.0.0.1:${builtins.toString configVars.networking.ports.tcp.ntfy}";
  services.ntfy-sh.settings.base-url = "https://${configVars.networking.subdomains.ntfy}.${configVars.homeDomain}";
  services.ntfy-sh.settings.behind-proxy = true;
  # When auth-file is present (set automatically by the NixOS module), ntfy denies
  # anonymous access by default. Explicit read-write allows unauthenticated fallback
  # while still enforcing credentials when provided.
  services.ntfy-sh.settings.auth-default-access = "read-write";

  # Private Slack triage topic: published by the Hermes gateway (barliman)
  # with the publisher token owned by ${slkPublisherUser}; subscribed to
  # on the phone while authenticated as ${slkUser} (ntfy app -> Settings 
  # -> Auth).
  #
  # ntfy's ACL resolver (user/access_cache.go) falls back to the * entry for
  # ANY user without their own entry, before auth-default-access — so the
  # wildcard entry below denies topic to anonymous clients AND to
  # non-admin users without an explicit grant, while auth-default-access
  # keeps read-write for all other topics (UnifiedPush, alerts, ...).
  # Named-user grants cannot be declared here unless the users are also in
  # auth-users, so ntfy-user-sync below applies them to user.db:
  #   ${slkPublisherUser}:topic write-only (the gateway publisher)
  #   ${slkUser}:topic read-write (belt and braces: ${slkUser} is an
  #   admin, which already implies rw)
  # Verified live on ntfy 2.37.2: anon publish/subscribe -> 403,
  # token publish -> 200, anon publish/subscribe on other topics -> 200.
  services.ntfy-sh.settings.auth-access = [
    "*:${slkTopic}:deny-all"
  ];

  # One sops secret per SSO user — each file contains only the plaintext password.
  # In nix-secrets, add these under the ntfy key in the relevant SOPS YAML, e.g.:
  #   ntfy:
  #     username1: "somepassword"
  #     username2: "somepassword"
  # Extra ntfy/* secrets beyond the SSO user list are ignored.
  sops.secrets = lib.listToAttrs (map (u: lib.nameValuePair "ntfy/${u.name}" { }) ntfyUsers);

  # Sync declared users into ntfy's SQLite DB on every boot/rebuild.
  # Idempotent: creates users that don't exist, updates passwords and roles for those that do.
  # Also applies the explicit read-write grant for the private Slack triage
  # topic (complementing the declarative anonymous-deny in auth-access above).
  systemd.services.ntfy-user-sync = {
    description = "Sync ntfy users and the topic grant from declarative config";
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

        # Explicit publisher/subscriber grant for the private Slack triage
        # topic (idempotent): anonymous is denied by auth-access in
        # server.yml, ${slkUser} keeps read-write on ${slkTopic}.
        # The grant is belt-and-braces (${slkUser} is an admin and bypasses
        # ACLs), and ntfy exits 1 with an "admin user" note in that case —
        # tolerate exactly that outcome, fail on anything else.
        if ! grant_out=$(${ntfyBin} access "${slkUser}" "${slkTopic}" read-write 2>&1); then
          if printf '%s\n' "$grant_out" | grep -q 'access control entries have no effect'; then
            echo "note: ${slkUser} is an admin; ACL grant on ${slkTopic} is a no-op (expected)"
          else
            printf 'unexpected failure applying ${slkUser} ACL grant on %s:\n%s\n' "${slkTopic}" "$grant_out" >&2
            exit 1
          fi
        fi

        # The gateway publisher account needs its own grant: ntfy's ACL
        # resolver falls back to the * entry (which denies ${slkTopic}) for
        # any user without an explicit entry, so without this the token
        # publish 403s. ${slkPublisherUser} is a plain (non-admin) user, so
        # the command succeeds normally.
        ${ntfyBin} access "${slkPublisherUser}" "${slkTopic}" read-write
      '';
      User = "root";
    };
  };
}
