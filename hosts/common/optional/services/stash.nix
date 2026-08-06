{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  stash-python3 = pkgs.python3.withPackages (
    ps: with ps; [
      apscheduler
      beautifulsoup4
      cloudscraper
      configparser
      lxml
      progressbar
      requests
      watchdog
    ]
  );
  stashPythonPathString = "${stash-python3}/${stash-python3.sitePackages}";
in
# Configuration for the nixpkgs stash service with VR helper extension
#
# Required sops-nix secrets (extracted from existing config.yml):
# - stash/${hostname}/password: The bcrypted password hash
# - stash/${hostname}/jwt-secret: JWT secret key for authentication tokens
# - stash/${hostname}/session-key: Session store encryption key
#
# Required configVars (stored in flake at build time):
# - configVars.networking.stash.apiKey.${hostname}: API key for VR helper
# - configVars.networking.stash.boxes: (optional) List of stash-box configurations
#
# With mutableSettings = true and an existing config.yml, the service will:
# - Use the existing config.yml file as-is
# - NOT regenerate or modify the config
# - The secrets are required but won't overwrite existing config
{
  # Stash secrets from sops
  sops.secrets."stash-password" = {
    key = "stash/${config.networking.hostName}/password";
    owner = config.services.stash.user;
    group = config.services.stash.group;
    mode = "0400";
  };

  sops.secrets."stash-jwt-secret" = {
    key = "stash/${config.networking.hostName}/jwt-secret";
    owner = config.services.stash.user;
    group = config.services.stash.group;
    mode = "0400";
  };

  sops.secrets."stash-session-key" = {
    key = "stash/${config.networking.hostName}/session-key";
    owner = config.services.stash.user;
    group = config.services.stash.group;
    mode = "0400";
  };

  # Separate sops secret entry owned by the stash user so the scheduler
  # startup service can read it at runtime without elevated privileges.
  # Uses the same underlying secret key as the nzbget stash integration.
  sops.secrets."stash-api-key" = {
    key = "${config.networking.hostName}-stashapp-api-key";
    owner = config.services.stash.user;
    group = config.services.stash.group;
    mode = "0400";
  };

  services.stash.enable = lib.mkDefault true;
  # Bleeding doesn't seem to update nearly enough
  # services.stash.package = lib.mkDefault pkgs.bleeding.stash;
  services.stash.package = lib.mkDefault pkgs.stashapp;

  # Authentication and secrets
  services.stash.username = lib.mkDefault configVars.username;
  services.stash.passwordFile = lib.mkDefault config.sops.secrets."stash-password".path;
  services.stash.jwtSecretKeyFile = lib.mkDefault config.sops.secrets."stash-jwt-secret".path;
  services.stash.sessionStoreKeyFile = lib.mkDefault config.sops.secrets."stash-session-key".path;

  # Allow mutable settings to use existing config.yml
  # When true, the settings below only initialize config if it doesn't exist
  services.stash.mutableSettings = lib.mkDefault true;

  # Allow mutable plugins and scrapers (don't want to list them in source code)
  services.stash.mutablePlugins = lib.mkDefault true;
  services.stash.mutableScrapers = lib.mkDefault true;

  # Make library paths writable to allow file management through UI
  # By default, nixpkgs stash binds library paths as read-only for security
  # We override this to allow deletion/modification of files
  # All other systemd security hardening (ProtectSystem, PrivateDevices, etc.) remains active
  systemd.services.stash.serviceConfig.BindReadOnlyPaths = lib.mkForce [ ];

  # Ensure that plugins have the proper dependencies available
  systemd.services.stash.path = lib.mkBefore (
    with pkgs;
    [
      openssl
      sqlite
      stashapp-tools
      stash-python3
    ]
  );
  systemd.services.stash.environment.STASH_PYTHONPATH = stashPythonPathString;
  systemd.services.stash.serviceConfig.Environment = [
    "PYTHONPATH=${stashPythonPathString}"
  ];

  # Basic settings (used for initialization if config doesn't exist)
  services.stash.settings.host = lib.mkDefault "0.0.0.0";
  services.stash.settings.port = lib.mkDefault configVars.networking.ports.tcp.stash;
  services.stash.settings.stash = [ ];
  services.stash.settings.exclude = [
    "_unpack"
  ];
  services.stash.settings.image_exclude = [
    "_unpack"
  ];
  services.stash.settings.nobrowser = lib.mkDefault true;
  services.stash.settings.ffmpeg.hardware_acceleration = lib.mkDefault true;
  services.stash.settings.max_streaming_transcode_size = lib.mkDefault "FULL_HD";
  services.stash.settings.video_extensions = lib.mkDefault [
    "m4v"
    "mp4"
    "rm"
    "flv"
    "asf"
    "mkv"
    "webm"
    "f4v"
  ];
  services.stash.settings.stash_boxes = (
    if lib.attrsets.hasAttrByPath [ "networking" "stash" "boxes" ] configVars then
      configVars.networking.stash.boxes
    else
      [ ]
  );
  services.stash.settings.api_key = lib.mkIf (lib.attrsets.hasAttrByPath [
    "networking"
    "stash"
    "apiKey"
    config.networking.hostName
  ] configVars) (lib.mkDefault configVars.networking.stash.apiKey.${config.networking.hostName});
  # services.stash.settings.ui.frontPageContent = [];
  services.stash.settings.notifications_enabled = lib.mkDefault false;
  services.stash.settings.parallel_tasks = lib.mkDefault 0;
  services.stash.settings.show_one_time_moved_notification = lib.mkDefault false;

  # Enable VR helper (configure hosts per-machine)
  services.stash.vr-helper.enable = lib.mkDefault true;
  services.stash.vr-helper.hosts.local.stashUrl = lib.mkDefault "http://${
    configVars.networking.subnets.${config.networking.hostName}.ip
  }:${builtins.toString configVars.networking.ports.tcp.stash}";
  services.stash.vr-helper.hosts.local.port =
    lib.mkDefault configVars.networking.ports.tcp.stashvrlocal;

  services.stash.vr-helper.apiEnvironmentVariableFile = lib.mkDefault (
    if
      lib.attrsets.hasAttrByPath [ "networking" "stash" "apiKey" config.networking.hostName ] configVars
    then
      toString (
        pkgs.writeText "stash-vr-api.env" ''
          STASH_API_KEY=${configVars.networking.stash.apiKey.${config.networking.hostName}}
        ''
      )
    else
      ""
  );

  # Ensure the stash user is in the shared media group
  users.groups.media = { };
  users.users.${config.services.stash.user}.extraGroups = [ "media" ];

  # Start the stash-scheduler plugin daemon whenever stash comes online.
  # wantedBy = ["stash.service"] places this unit in stash.service's .wants/
  # directory so systemd activates it on every stash activation — boot,
  # manual start, or after work-block stops.  No changes to work-block needed.
  systemd.services.stash-start-scheduler =
    let
      stashPort = toString configVars.networking.ports.tcp.stash;
      schedulerScript = pkgs.writeShellScript "stash-start-scheduler" ''
        set -euo pipefail

        MAX_ATTEMPTS=30
        attempt=0

        # Poll until stash's GraphQL API is accepting requests before sending
        # the plugin task — stash takes a moment to fully initialise after the
        # systemd unit reports started.
        until ${pkgs.curl}/bin/curl \
            --silent \
            --fail \
            --output /dev/null \
            --max-time 2 \
            -X POST \
            -H "ApiKey: $(cat ${config.sops.secrets."stash-api-key".path})" \
            -H "Content-Type: application/json" \
            --data '{"query":"{ version { version } }"}' \
            "http://localhost:${stashPort}/graphql"; do
          attempt=$((attempt + 1))
          if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
            echo "Stash GraphQL API not ready after $MAX_ATTEMPTS attempts (60s), giving up" >&2
            exit 1
          fi
          echo "Stash not ready yet (attempt $attempt/$MAX_ATTEMPTS), retrying in 2s..."
          sleep 2
        done

        echo "Stash is ready, starting stash-scheduler plugin..."
        ${pkgs.curl}/bin/curl \
          --silent \
          --fail \
          -X POST \
          -H "ApiKey: $(cat ${config.sops.secrets."stash-api-key".path})" \
          -H "Content-Type: application/json" \
          --data '{"operationName":"RunPluginTask","variables":{"plugin_id":"stash-scheduler","task_name":"Start Scheduler"},"query":"mutation RunPluginTask($plugin_id: ID!, $task_name: String!, $args_map: Map) {\n  runPluginTask(plugin_id: $plugin_id, task_name: $task_name, args_map: $args_map)\n}"}' \
          "http://localhost:${stashPort}/graphql"
        echo "stash-scheduler plugin started successfully"
      '';
    in
    {
      description = "Start stash-scheduler plugin after stash comes online";
      after = [ "stash.service" ];
      # Placing this unit in stash.service.wants/ means systemd starts it
      # automatically on every stash activation without any caller needing to
      # know about it.
      wantedBy = [ "stash.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = config.services.stash.user;
        Group = config.services.stash.group;
        ExecStart = "${schedulerScript}";
        # RemainAfterExit = false (the default) means the unit becomes inactive
        # after completion, so systemd will re-run it the next time stash starts.
        RemainAfterExit = false;
      };
    };

  # Set umask so stash creates group-writable files
  systemd.services.stash.serviceConfig.UMask = lib.mkDefault "0002";
}
