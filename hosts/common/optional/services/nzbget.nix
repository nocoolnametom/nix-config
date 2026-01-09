{
  pkgs,
  lib,
  config,
  ...
}:
let
  rndb = "rndb.net";
  hdb = "hdb.org";
  sdb = "sdb.cc";
  ash = "ash.org";
  stashApiKeySecretName = "${config.networking.hostName}-stashapp-api-key";
  updateStashScript =
    apiKeyPath: paths:
    pkgs.writeShellScriptBin "updateStash.sh" (
      let
        pathsString = lib.concatMapStringsSep ", " (x: "\"${x}\"") paths;
      in
      ''
        ${pkgs.curl}/bin/curl --silent --output /dev/null -X POST \
          -H "ApiKey: $(cat ${apiKeyPath})" \
          -H "Content-Type: application/json" \
          --data-raw $'{ "operationName": "MetadataIdentify", "variables": { "input": { "sources": [{"source": { "stash_box_endpoint": "https://fan${sdb}/graphql" }}, {"source": { "stash_box_endpoint": "https://pmvst${ash}/graphql" }}, { "source": { "stash_box_endpoint": "https://stas${hdb}/graphql" }}, {"source": { "stash_box_endpoint": "https://thepo${rndb}/graphql" }}, {"source": {"scraper_id": "builtin_autotag" }}], "options": { "fieldOptions": [{ "field": "title", "strategy": "OVERWRITE" }, { "field": "studio", "strategy": "MERGE", "createMissing": true }, { "field": "performers", "strategy": "MERGE", "createMissing": true }, { "field": "tags", "strategy": "MERGE", "createMissing": true }], "setCoverImage": true, "setOrganized": false, "includeMalePerformers": false }, "paths": [${pathsString}] } }, "query": "mutation MetadataIdentify($input: IdentifyMetadataInput\u0021) { metadataIdentify(input: $input) } "}' \
          $NZBPO_STASHHOST:$NZBPO_STASHPORT/graphql ;
      ''
    );
in
{
  # Hostname-specific API key secret
  sops.secrets.${stashApiKeySecretName} = { };
  sops.secrets."${stashApiKeySecretName}-for-nzbget" = {
    key = stashApiKeySecretName;
    owner = config.services.nzbget.user;
    group = config.services.nzbget.group;
  };
  # NzbGet Server
  services.nzbget.enable = true;
  services.nzbget.group = "media"; # Use media group instead of nzbget

  # Set umask so files are group-writable (0002 = rwxrwxr-x for dirs, rw-rw-r-- for files)
  systemd.services.nzbget.serviceConfig.UMask = "0002";

  systemd.services.nzbget.path = with pkgs; [
    unrar
    unzip
    gzip
    xz
    bzip2
    gnutar
    p7zip
    py7zr
    (pkgs.python3.withPackages (
      p: with p; [
        requests
        pandas
        configparser
        py7zr
        standard-imghdr
      ]
    ))
    ffmpeg
  ];
  systemd.services.nzbget.preStart =
    let
      nzbToStashApp = pkgs.writeShellScriptBin "nzbToStashApp.sh" ''
        ###########################################
        ### NZBGET POST-PROCESSING SCRIPT       ###
         
        # Start StashApp Scanning
        #
        # Once a file has finished downloading we
        # want to have Stash start scanning it

        ###########################################
        ### OPTIONS                             ###

        # StashApp Host
        #Stashhost=localhost

        # StashApp Port
        #Stashport=9999

        ### NZBGET POST-PROCESSING SCRIPT       ###
        ###########################################
        StashPath="$NZBOP_DESTDIR/$NZBPP_CATEGORY";
        ${pkgs.curl}/bin/curl \
          -H "ApiKey: $(cat ${config.sops.secrets."${stashApiKeySecretName}-for-nzbget".path})" \
          -H "Content-Type: application/json" \
          --data "{\"query\":\"mutation{metadataScan(input:{paths:[\\\"$StashPath\\\"],scanGenerateCovers:true,scanGeneratePreviews:true,scanGenerateSprites:true,scanGeneratePhashes:true,scanGenerateThumbnails:true})}\"}" \
          $NZBPO_STASHHOST:$NZBPO_STASHPORT/graphql && exit 93 || exit 94;
      '';
    in
    ''
      rm -f /arkenstone/nzbget/scripts/nzbToStashApp.sh && ln -s ${nzbToStashApp}/bin/nzbToStashApp.sh /arkenstone/nzbget/scripts/nzbToStashApp.sh;
    '';
  systemd.timers.nzbget-morning-refresh = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:45:00";
      Unit = "nzbget-morning-refresh.service";
    };
  };
  systemd.services.nzbget-morning-refresh = {
    script = "systemctl restart nzbget.service";
    serviceConfig = {
      Type = "oneshot";
    };
  };
  systemd.timers.stash-morning-software-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:55:00";
      Unit = "stash-morning-software-update.service";
    };
  };
  systemd.timers.stash-morning-unknown-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:56:00";
      Unit = "stash-morning-unknown-update.service";
    };
  };
  systemd.services.stash-morning-software-update = {
    environment = {
      NZBPO_STASHHOST = "127.0.0.1";
      NZBPO_STASHPORT = "9999";
    };
    script = "${
      updateStashScript config.sops.secrets."${stashApiKeySecretName}-for-nzbget".path [
        "/arkenstone/stash/library/unorganized/"
      ]
    }/bin/updateStash.sh";
    serviceConfig = {
      Type = "oneshot";
    };
  };
  systemd.services.stash-morning-unknown-update = {
    environment = {
      NZBPO_STASHHOST = "127.0.0.1";
      NZBPO_STASHPORT = "9999";
    };
    script = "${
      updateStashScript config.sops.secrets."${stashApiKeySecretName}-for-nzbget".path [
        "/arkenstone/stash/library/needswork"
      ]
    }/bin/updateStash.sh";
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # Ensure the nzbget user is in the shared media group
  users.groups.media = { };
  users.users.nzbget.extraGroups = [ "media" ];
}
