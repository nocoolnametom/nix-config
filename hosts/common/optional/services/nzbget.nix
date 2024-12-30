{
  pkgs,
  lib,
  config,
  ...
}:
let
  rndb = "rndb.net";
  hdb = "hdb.org";
  updateStashScript =
    paths:
    pkgs.writeShellScriptBin "updateStash.sh" (
      let
        pathsString = lib.concatMapStringsSep ", " (x: "\"${x}\"") paths;
      in
      ''
        ${pkgs.curl}/bin/curl --silent --output /dev/null -X POST \
          -H "ApiKey: $(cat ${config.sops.secrets."bert-stashapp-api-key".path})" \
          -H "Content-Type: application/json" \
          --data-raw $'{ "operationName": "MetadataIdentify", "variables": { "input": { "sources": [{ "source": { "stash_box_endpoint": "https://stas${hdb}/graphql" }}, {"source": { "stash_box_endpoint": "https://thepo${rndb}/graphql" }}, {"source": {"scraper_id": "builtin_autotag" }}], "options": { "fieldOptions": [{ "field": "title", "strategy": "OVERWRITE" }, { "field": "studio", "strategy": "MERGE", "createMissing": true }, { "field": "performers", "strategy": "MERGE", "createMissing": true }, { "field": "tags", "strategy": "MERGE", "createMissing": true }], "setCoverImage": true, "setOrganized": false, "includeMalePerformers": false }, "paths": [${pathsString}] } }, "query": "mutation MetadataIdentify($input: IdentifyMetadataInput\u0021) { metadataIdentify(input: $input) } "}' \
          $NZBPO_STASHHOST:$NZBPO_STASHPORT/graphql ;
      ''
    );
in
{
  sops.secrets."bert-stashapp-api-key" = { };
  sops.secrets."bert-stashapp-api-key-for-nzbget" = {
    key = "bert-stashapp-api-key";
    owner = config.services.nzbget.user;
    group = config.services.nzbget.group;
  };
  # NzbGet Server
  services.nzbget.enable = true;
  systemd.services.nzbget.path = with pkgs; [
    unrar
    unzip
    xz
    bzip2
    gnutar
    p7zip
    (pkgs.python3.withPackages (
      p: with p; [
        requests
        pandas
        configparser
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
          -H "ApiKey: $(cat ${config.sops.secrets."bert-stashapp-api-key-for-nzbget".path})" \
          -H "Content-Type: application/json" \
          --data "{\"query\":\"mutation{metadataScan(input:{paths:[\\\"$StashPath\\\"],scanGenerateCovers:true,scanGeneratePreviews:true,scanGenerateSprites:true,scanGeneratePhashes:true,scanGenerateThumbnails:true})}\"}" \
          $NZBPO_STASHHOST:$NZBPO_STASHPORT/graphql && exit 93 || exit 94;
      '';
    in
    ''
      rm -f /media/g_drive/nzbget/scripts/nzbToStashApp.sh && ln -s ${nzbToStashApp}/bin/nzbToStashApp.sh /media/g_drive/nzbget/scripts/nzbToStashApp.sh;
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
      updateStashScript [
        "/media/g_drive/nzbget/dest/software"
        "/mnt/bigssd/data.dat/software"
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
      updateStashScript [
        "/mnt/bigssd/data.dat/vids/unknown_studio"
        "/mnt/bigssd/data.dat/vids/needs_work"
      ]
    }/bin/updateStash.sh";
    serviceConfig = {
      Type = "oneshot";
    };
  };
}
