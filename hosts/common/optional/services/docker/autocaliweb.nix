###############################################################################
#
#  Autocaliweb - Calibre-Web fork with automatic ingest/conversion (arion)
#
#  Not packaged in nixpkgs (nixpkgs has plain calibre-web), so it runs as a
#  container. Mounts:
#    <stateDir>/config  -> /config            (app.db, acw.db, settings)
#    <ingestDir>        -> /acw-book-ingest   (drop books here to import)
#    <libraryDir>       -> /calibre-library   (Calibre library + metadata.db)
#
#  Ownership: the image remaps its internal `abc` user to PUID/PGID and
#  recursively chowns the library to it whenever it ingests or converts
#  books, and its default UMASK is 0002. If something else also writes the
#  library (e.g. Syncthing), share access through `group`: keep the library
#  setgid + group-writable for that group and have the other writer join it.
#  (ACW_CHOWN_LIBRARY stays unset: no blanket chown at container start.)
#
#  Directories at custom paths (libraryDir/ingestDir outside stateDir) are
#  left to the host to create and permission; only the defaults are created
#  here, so the two never fight over ownership.
#
#  The container only sees the three mounts above, regardless of what groups
#  `user` has on the host.
#
#  OAuth/OIDC settings live in app.db (Admin > Configuration > OAuth). The
#  app does read OAUTH_* environment variables in cps/oauth_bb.py, but the
#  image's s6 services start cps.py with a clean environment, so container
#  `environment` / `env_file` values never reach it (checked 2026-10-05).
#  Logins match existing users by preferred_username, so the Kanidm client
#  sends short usernames (see kanidm.nix).
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  ...
}:
let
  cfg = config.services.autocaliweb;
  defaultIngestDir = "${cfg.stateDir}/ingest";
  defaultLibraryDir = "/var/lib/autocaliweb/library";
  uid = config.users.users.${cfg.user}.uid;
  gid = config.users.groups.${cfg.group}.gid;
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.autocaliweb = {
    libraryDir = lib.mkOption {
      type = lib.types.path;
      default = defaultLibraryDir;
      description = "Calibre library directory (the one containing metadata.db).";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/autocaliweb";
      description = "Holds config/ (app.db, acw.db).";
    };

    ingestDir = lib.mkOption {
      type = lib.types.path;
      default = defaultIngestDir;
      defaultText = lib.literalExpression ''"''${config.services.autocaliweb.stateDir}/ingest"'';
      description = ''
        Watched drop folder: supported files written here are imported into
        the library and then deleted. Anything with an unsupported extension
        is ignored by the watcher, so sync tools' temporary files are safe.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.calibreweb;
      description = "Host port the web UI is published on.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "autocaliweb";
      description = "Host user the container runs as (PUID). Must have a fixed uid.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "autocaliweb";
      description = "Host group the container runs as (PGID). Must have a fixed gid.";
    };

  };

  config = {
    assertions = [
      {
        assertion = uid != null && gid != null;
        message = "services.autocaliweb: user `${cfg.user}` and group `${cfg.group}` need fixed uid/gid (they become the container's PUID/PGID).";
      }
    ];

    users.users = lib.mkIf (cfg.user == "autocaliweb") {
      autocaliweb = {
        isSystemUser = true;
        uid = 8083;
        group = cfg.group;
      };
    };
    users.groups = lib.mkIf (cfg.group == "autocaliweb") { autocaliweb.gid = 8083; };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/config 0750 ${cfg.user} ${cfg.group} -"
    ]
    ++ lib.optional (
      cfg.ingestDir == defaultIngestDir
    ) "d ${cfg.ingestDir} 2770 ${cfg.user} ${cfg.group} -"
    ++ lib.optional (
      cfg.libraryDir == defaultLibraryDir
    ) "d ${cfg.libraryDir} 2775 ${cfg.user} ${cfg.group} -";

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.autocaliweb = { };

    # If the library sits on a nofail mount, never let the container write to
    # the disk underneath it instead.
    systemd.services.arion-autocaliweb.unitConfig.RequiresMountsFor = [
      cfg.libraryDir
      cfg.stateDir
      cfg.ingestDir
    ];

    virtualisation.arion.projects.autocaliweb.settings.services.autocaliweb.service = {
      image = "gelbphoenix/autocaliweb:latest";
      container_name = "autocaliweb";
      ports = [ "${toString cfg.port}:8083" ];
      environment = {
        TZ = config.time.timeZone;
        PUID = toString uid;
        PGID = toString gid;
      };
      volumes = [
        "${cfg.stateDir}/config:/config"
        "${cfg.ingestDir}:/acw-book-ingest"
        "${cfg.libraryDir}:/calibre-library"
      ];
      stop_signal = "SIGINT";
      stop_grace_period = "15s";
      restart = "unless-stopped";
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
