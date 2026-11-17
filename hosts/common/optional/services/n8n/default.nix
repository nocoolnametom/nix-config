###############################################################################
#
#  n8n workflow automation, provisioned entirely from Nix
#
#  Public ingress follows the usual path (bombadil -> estel Caddy -> this
#  host over the LAN), but estel only lets /webhook/* and /healthz through
#  from outside; the editor is LAN-only (see hosts/estel/caddy.nix).
#
#  Kanidm login (declarative.oidc): n8n's free edition has no SSO, so this
#  loads the community kavdau/n8n-oidc external hook (MIT; packaged in
#  pkgs/n8n-oidc, bump it after checking its changelog against n8n). It
#  adds a "Sign in with SSO" button and the /auth/oidc/{login,callback}
#  routes, and matches Kanidm users to n8n users by verified email, so the
#  owner signs in as the owner. Its own caveats: it uses n8n internals rather
#  than a public API, so an n8n upgrade can break it - it then logs why,
#  disables itself, and password login keeps working (look for
#  "[OIDC Hook] ... active on n8n <version>" in the journal after upgrades).
#  Signing out of n8n does not sign out of Kanidm, and n8n's own SSO
#  settings page stays locked (this is not the licensed feature).
#
#  Everything below is applied on every start of n8n.service, before n8n
#  itself runs:
#    - the owner account comes from N8N_INSTANCE_OWNER_* (email from
#      configVars, bcrypt hash from sops); n8n rewrites it on each start,
#      so there is no first-run signup page.
#    - `credentials` are written into n8n's encrypted credential store with
#      `n8n import:credentials` (upsert by id).
#    - `workflows` are imported with `n8n import:workflow` (upsert by id) and
#      then published with `n8n publish:workflow`, which is what activates
#      them in n8n 2.x.
#  Credentials and workflows are rendered as sops templates, so either may
#  embed `config.sops.placeholder.<key>` values and nothing secret reaches
#  the Nix store. Placeholders are pasted into JSON verbatim: keep those
#  secret values free of `"` and `\`.
#
#  Consequences of that:
#    - Editing a declared workflow in the UI works until the next restart,
#      which puts the Nix version back (each import adds a history version).
#      Workflows created only in the UI are never touched.
#    - Removing a workflow from Nix leaves it in n8n's database; archive or
#      delete it in the UI.
#
#  Workflow modules live in ./workflows/ and register themselves through
#  services.n8n.declarative.*; a host imports this file plus the workflow
#  files it wants.
#
#  sops keys:
#    homelab/n8n/owner-password-hash   bcrypt hash of the owner's password
#    homelab/kanidm/oidc/n8n/client-secret
#                                      Kanidm client secret (with oidc.enable;
#                                      the same key kanidm.nix provisions)
#    homelab/n8n/registration-key      free "registered Community" licence key
#                                      (with registrationKeySecret set)
#
###############################################################################

{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
let
  cfg = config.services.n8n;
  decl = cfg.declarative;

  publicUrl = "https://${configVars.networking.subdomains.n8n}.${configVars.homeDomain}/";

  # n8n reads these from $CREDENTIALS_DIRECTORY. Workflow files must end in
  # .json (import:workflow --separate globs for them); the credentials file
  # must not, or it would be read as a workflow.
  workflowCredName = name: "n8n-workflow-${name}.json";
  credentialsCredName = "n8n-provision-credentials";

  credentialType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        id = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9]{1,36}";
          description = "Stable credential id; workflow nodes reference it, and re-imports upsert on it.";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Display name in n8n.";
        };
        type = lib.mkOption {
          type = lib.types.str;
          example = "httpHeaderAuth";
          description = "n8n credential type name.";
        };
        data = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          description = "Decrypted credential fields; values may be sops placeholders.";
        };
      };
    }
  );

  workflowType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        id = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9]{1,36}";
          description = "Stable workflow id; re-imports upsert on it.";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Display name in n8n.";
        };
        active = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Publish (activate) the workflow after importing it.";
        };
        nodes = lib.mkOption {
          type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
          description = "n8n node definitions, as in an exported workflow's `nodes`.";
        };
        connections = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "n8n connections, as in an exported workflow's `connections`.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {
            executionOrder = "v1";
          };
          description = "n8n workflow settings.";
        };
      };
    }
  );

  workflowJson =
    wf:
    builtins.toJSON {
      inherit (wf)
        id
        name
        nodes
        connections
        settings
        ;
      active = false; # import always deactivates; publish:workflow activates
    };

  credentialsJson = builtins.toJSON (
    map (c: {
      inherit (c)
        id
        name
        type
        data
        ;
    }) (lib.attrValues decl.credentials)
  );

  activeIds = map (wf: wf.id) (lib.filter (wf: wf.active) (lib.attrValues decl.workflows));

  allIds = map (wf: wf.id) (lib.attrValues decl.workflows);

  # Credentials go first: workflow nodes refer to them by id.
  # Workflows are unpublished before the import: importing over a published
  # workflow makes n8n deactivate it through its user-permission layer, which
  # refuses from the CLI ("You do not have permission to deactivate this
  # workflow"), while unpublish:workflow writes the database directly.
  # Unpublishing fails for an id that is not in the database yet (first
  # start, or a newly added workflow), so that step alone may fail; anything
  # really wrong with the database fails the import right after it.
  provisionScript = pkgs.writeShellScript "n8n-provision" ''
    set -euo pipefail
    n8n=${lib.getExe cfg.package}
    ${lib.optionalString (decl.credentials != { }) ''
      "$n8n" import:credentials --input="$CREDENTIALS_DIRECTORY/${credentialsCredName}"
    ''}
    for id in ${lib.escapeShellArgs allIds}; do
      "$n8n" unpublish:workflow --id="$id" || echo "n8n-provision: $id not unpublished (not imported yet?)"
    done
    ${lib.optionalString (decl.workflows != { }) ''
      "$n8n" import:workflow --separate --input="$CREDENTIALS_DIRECTORY"
    ''}
    for id in ${lib.escapeShellArgs activeIds}; do
      "$n8n" publish:workflow --id="$id"
    done
  '';
in
{
  options.services.n8n.declarative = {
    ownerEmail = lib.mkOption {
      type = lib.types.str;
      default = configVars.email.user;
      defaultText = lib.literalExpression "configVars.email.user";
      description = "Login email of the n8n owner account.";
    };

    credentials = lib.mkOption {
      type = lib.types.attrsOf credentialType;
      default = { };
      description = "Credentials written into n8n's store on every start.";
    };

    workflows = lib.mkOption {
      type = lib.types.attrsOf workflowType;
      default = { };
      description = "Workflows imported (and optionally published) on every start.";
    };

    registrationKeySecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "homelab/n8n/registration-key";
      description = ''
        sops key holding the free licence key n8n emails when an instance is
        registered (Settings > Plan & usage > Unlock); it unlocks folders,
        debug in editor and custom execution data. n8n activates it once, on
        a start with no licence stored yet, and keeps the licence in its data
        directory after that. Null leaves the instance unregistered.
      '';
    };

    oidc = {
      enable = lib.mkEnableOption "Kanidm (OIDC) login through the community n8n-oidc hook";

      package = lib.mkPackageOption pkgs "n8n-oidc" { };

      issuerUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/${decl.oidc.clientId}";
        defaultText = lib.literalExpression ''"https://<kanidm>/oauth2/openid/''${clientId}"'';
        description = "OIDC issuer; Kanidm's is per client.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "n8n";
        description = "OIDC client id (the Kanidm client name).";
      };

      clientSecretKey = lib.mkOption {
        type = lib.types.str;
        default = "homelab/kanidm/oidc/${decl.oidc.clientId}/client-secret";
        description = "sops key holding the client secret.";
      };

      autoProvision = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Create n8n accounts for Kanidm users who have none. Off: only people
          whose verified email already matches an n8n user (the owner, or
          someone invited in the UI) can sign in this way.
        '';
      };
    };
  };

  config = {
    sops.secrets = {
      "homelab/n8n/owner-password-hash" = { };
    }
    // lib.optionalAttrs (decl.registrationKeySecret != null) {
      ${decl.registrationKeySecret} = { };
    }
    // lib.optionalAttrs decl.oidc.enable {
      # Shared with kanidm.nix when Kanidm runs on this host (it sets the
      # owner); n8n reads it through LoadCredential, as root, either way.
      ${decl.oidc.clientSecretKey} = { };
    };

    sops.templates =
      lib.mapAttrs' (
        name: wf:
        lib.nameValuePair (workflowCredName name) {
          content = workflowJson wf;
          restartUnits = [ "n8n.service" ];
        }
      ) decl.workflows
      // lib.optionalAttrs (decl.credentials != { }) {
        ${credentialsCredName} = {
          content = credentialsJson;
          restartUnits = [ "n8n.service" ];
        };
      };

    services.n8n = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault true; # estel's Caddy connects over the LAN
      environment = {
        N8N_PORT = configVars.networking.ports.tcp.n8n;
        N8N_HOST = "${configVars.networking.subdomains.n8n}.${configVars.homeDomain}";
        N8N_PROTOCOL = "https";
        N8N_EDITOR_BASE_URL = publicUrl;
        WEBHOOK_URL = publicUrl;
        N8N_PROXY_HOPS = 1; # estel's Caddy; bombadil's HAProxy only routes by SNI

        N8N_INSTANCE_OWNER_MANAGED_BY_ENV = true;
        N8N_INSTANCE_OWNER_EMAIL = decl.ownerEmail;
        N8N_INSTANCE_OWNER_FIRST_NAME = configVars.username;
        N8N_INSTANCE_OWNER_LAST_NAME = "(n8n)";
        N8N_INSTANCE_OWNER_PASSWORD_HASH_FILE = config.sops.secrets."homelab/n8n/owner-password-hash".path;
      }
      // lib.optionalAttrs (decl.registrationKeySecret != null) {
        N8N_LICENSE_ACTIVATION_KEY_FILE = config.sops.secrets.${decl.registrationKeySecret}.path;
      }
      // lib.optionalAttrs decl.oidc.enable {
        EXTERNAL_HOOK_FILES = "${decl.oidc.package}/lib/n8n-oidc/hooks.js";
        # The hook serves this script itself; n8n injects it into the editor.
        EXTERNAL_FRONTEND_HOOKS_URLS = "/assets/oidc-frontend-hook.js";
        N8N_ADDITIONAL_NON_UI_ROUTES = "auth";
        # The hook looks for n8n's package by walking up from the binary; on
        # Nix that is packages/cli inside the store path, so say so outright.
        OIDC_N8N_PACKAGE_DIR = "${cfg.package}/lib/n8n/packages/cli";
        OIDC_ISSUER_URL = decl.oidc.issuerUrl;
        OIDC_CLIENT_ID = decl.oidc.clientId;
        OIDC_CLIENT_SECRET_FILE = config.sops.secrets.${decl.oidc.clientSecretKey}.path;
        OIDC_AUTO_PROVISION = decl.oidc.autoProvision;
        # The owner's name and email come from N8N_INSTANCE_OWNER_* on every
        # start; copying Kanidm's on each sign-in would just fight that.
        OIDC_SYNC_PROFILE = false;
      };
    };

    systemd.services.n8n = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        LoadCredential =
          lib.mapAttrsToList (
            name: _: "${workflowCredName name}:${config.sops.templates.${workflowCredName name}.path}"
          ) decl.workflows
          ++
            lib.optional (decl.credentials != { })
              "${credentialsCredName}:${config.sops.templates.${credentialsCredName}.path}";

        # Same user, environment and credentials as n8n itself. Each CLI call
        # boots n8n's core, so this adds tens of seconds to a start.
        ExecStartPre = lib.mkIf (decl.workflows != { } || decl.credentials != { }) [ provisionScript ];
        TimeoutStartSec = "5min";
      };
    };

    services.systemd-failure-alert.additional-services =
      lib.mkIf config.services.systemd-failure-alert.enable
        [ "n8n" ];
  };
}
