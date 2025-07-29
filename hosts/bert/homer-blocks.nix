{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  homerBlocks = internal: {
    vscode = [
      {
        name = "VSCode";
        icon = "fas fa-code";
        url = "https://vscode.dev/+ms-vscode.remote-server/zg15993vmu";
        target = "_blank";
      }
    ];
    deluge = lib.lists.optionals config.services.deluge.web.enable [
      {
        name = "Deluge Torrents";
        icon = "fas fa-broadcast-tower";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString configVars.networking.ports.tcp.delugeweb}/"
          else
            "https://${configVars.networking.subdomains.deluge}.${configVars.domain}";
        target = "_blank";
      }
    ];
    flood = lib.lists.optionals config.services.flood.enable [
      {
        name = "Flood Torrents";
        icon = "fas fa-tasks";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.flood.port}/"
          else
            "https://${configVars.networking.subdomains.flood}.${configVars.domain}";
        target = "_blank";
      }
    ];
    authentik = [
      {
        name = "Single sign-on";
        icon = "fas fa-sign-in";
        url = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}";
        target = "_blank";
      }
    ];
    jellyfin = [
      {
        name = "Jellyfin Media Server";
        icon = "fas fa-television";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}/"
          else
            "https://${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}";
        target = "_blank";
        type = "Emby";
        libraryType = "series";
      }
    ];
    podfetch = [
      {
        name = "PodFetch gPodder";
        icon = "fas fa-podcast";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.podfetch}/"
          else
            "https://${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}";
        target = "_blank";
      }
    ];
    ombi = lib.lists.optionals config.services.ombi.enable [
      {
        name = "Ombi Requests";
        icon = "fas fa-people-carry";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.ombi.port}/"
          else
            "https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}";
        target = "_blank";
      }
    ];
    navidrome = lib.lists.optionals config.services.navidrome.enable [
      {
        name = "Music Streaming";
        icon = "fas fa-music";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.navidrome.settings.Port}/"
          else
            "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}";
        target = "_blank";
      }
    ];
    nzbget = lib.lists.optionals config.services.nzbget.enable [
      {
        name = "NZBGet";
        icon = "fas fa-cloud-download";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString configVars.networking.ports.tcp.nzbget}/"
          else
            "https://${configVars.networking.subdomains.nzbget}.${configVars.domain}";
        target = "_blank";
      }
    ];
    calibreweb = [
      {
        name = "Books";
        icon = "fas fa-book";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}"
          else
            "https://${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    standardnotes = [
      {
        name = "Notes";
        icon = "fas fa-file-alt";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes}"
          else
            "https://${configVars.networking.subdomains.standardnotes}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    immich = [
      {
        name = "Photos";
        icon = "fas fa-camera-retro";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}"
          else
            "https://${configVars.networking.subdomains.immich}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    kavita = [
      {
        name = "Comics";
        icon = "fas fa-book-reader";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}"
          else
            "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    kavitan = [
      {
        name = "Manga";
        icon = "fas fa-book-dead";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}"
          else
            "https://${configVars.networking.subdomains.kavitan}.${configVars.domain}/";
        target = "_blank";
      }
    ];
    audiobookshelf = [
      {
        name = "Audiobooks";
        icon = "fas fa-headphones";
        url =
          if internal then
            "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}"
          else
            "https://${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    comfyui = [
      {
        name = "Stable Diffusion";
        icon = "fas fa-fighter-jet";
        url =
          if internal then
            "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyui}"
          else
            "https://${configVars.networking.subdomains.comfyui}.${configVars.domain}/";
        target = "_blank";
      }
    ];
    comfyuimini = [
      {
        name = "Stable Diffusion Mobile";
        icon = "fas fa-paper-plane";
        url =
          if internal then
            "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyuimini}"
          else
            "https://${configVars.networking.subdomains.comfyuimini}.${configVars.domain}/";
        target = "_blank";
      }
    ];
    stashapp = lib.lists.optionals config.services.stashapp.enable [
      {
        name = "Stash Data";
        icon = "fas fa-user-lock";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.stashapp.port}/"
          else
            "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
        target = "_blank";
      }
    ];
    # stashvr is on cirdan, but points to bert, so we use bert's enabling for if it's active
    stashvr = lib.lists.optionals config.services.stashapp.enable [
      {
        name = "Stash Data Headset";
        icon = "fas fa-vr-cardboard";
        # Service is ONLY accessible from bert, so hitting it with a port won't work unless you ARE bert
        url = "https://${configVars.networking.subdomains.stashvr}.${configVars.domain}";
        target = "_blank";
      }
    ];
    phanpy = [
      {
        name = "Phanpy";
        icon = "fas fa-gears";
        url = "https://${configVars.networking.subdomains.phanpy}.${configVars.domain}/";
        target = "_blank";
      }
    ];
    budget-me = [
      {
        name = "Budget Dad";
        icon = "fas fa-piggy-bank";
        url = "https://${configVars.networking.subdomains.budget-me}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    budget-partner = [
      {
        name = "Budget Mom";
        icon = "fas fa-piggy-bank";
        url = "https://${configVars.networking.subdomains.budget-partner}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    budget-kid1 = [
      {
        name = "Budget Kid #1";
        icon = "fas fa-piggy-bank";
        url = "https://${configVars.networking.subdomains.budget-kid1}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    budget-kid2 = [
      {
        name = "Budget Kid #2";
        icon = "fas fa-piggy-bank";
        url = "https://${configVars.networking.subdomains.budget-kid2}.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
    sickgear = lib.lists.optionals config.services.sickbeard.enable [
      {
        name = "Sickgear TV";
        icon = "fas fa-file-video";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.sickbeard.port}/tv/"
          else
            "https://${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}/tv/";
        target = "_blank";
      }
    ];
    radarr = lib.lists.optionals config.services.radarr.enable [
      {
        name = "Radarr Movies";
        icon = "fas fa-film";
        url =
          if internal then
            "http://${configVars.networking.subnets.bert.ip}:${builtins.toString configVars.networking.ports.tcp.radarr}/"
          else
            "https://${configVars.networking.subdomains.radarr}.${configVars.homeDomain}";
        target = "_blank";
      }
    ];
    kanidm = lib.lists.optionals config.services.kanidm.enableServer [
      {
        name = "Kanidm SSO";
        icon = "fas fa-shield-alt";
        url = if internal then "http://127.0.0.1:8443/" else "https://kanidm.${configVars.homeDomain}/";
        target = "_blank";
      }
    ];
  };

  # Helper functions for different dashboard configurations
  proxyPaths = internal: {
    "/".root = pkgs.homer;
    "= /assets/config.yml".alias = pkgs.writeText "homerConfig.yml" (
      builtins.toJSON {
        title = "Dashboard";
        header = false;
        footer = false;
        connectivityCheck = false;
        columns = "auto";
        services = [
          {
            name = "Services";
            items =
              with homerBlocks internal;
              vscode
              ++ authentik
              ++ deluge
              ++ flood
              ++ jellyfin
              ++ podfetch
              ++ ombi
              ++ navidrome
              ++ nzbget
              ++ calibreweb
              ++ standardnotes
              ++ immich
              ++ kavita
              ++ kavitan
              ++ audiobookshelf
              ++ comfyui
              ++ comfyuimini
              ++ stashapp
              ++ stashvr
              ++ phanpy
              ++ budget-me
              ++ sickgear
              ++ radarr
              ++ kanidm;
          }
        ];
      }
    );
  };

  homeProxyPaths = internal: {
    "/".root = pkgs.homer;
    "= /assets/config.yml".alias = pkgs.writeText "homerConfig.yml" (
      builtins.toJSON {
        title = "Dashboard";
        header = false;
        footer = false;
        connectivityCheck = false;
        columns = "auto";
        services = [
          {
            name = "Services";
            items =
              with homerBlocks internal;
              jellyfin
              ++ authentik
              ++ ombi
              ++ navidrome
              ++ calibreweb
              ++ standardnotes
              ++ immich
              ++ kavita
              ++ audiobookshelf
              ++ podfetch
              ++ budget-me
              ++ budget-partner
              ++ budget-kid1
              ++ budget-kid2
              ++ sickgear
              ++ radarr
              ++ kanidm;
          }
        ];
      }
    );
  };

  privateProxyPaths = internal: {
    "/".root = pkgs.homer;
    "= /assets/config.yml".alias = pkgs.writeText "homerConfig.yml" (
      builtins.toJSON {
        title = "Dashboard";
        header = false;
        footer = false;
        connectivityCheck = false;
        columns = "auto";
        services = [
          {
            name = "Services";
            items =
              with homerBlocks internal;
              vscode
              ++ authentik
              ++ deluge
              ++ flood
              ++ nzbget
              ++ kavitan
              ++ budget-me
              ++ comfyui
              ++ comfyuimini
              ++ stashapp
              ++ stashvr
              ++ phanpy
              ++ budget-me
              ++ sickgear
              ++ radarr
              ++ kanidm;
          }
        ];
      }
    );
  };
in
{
  inherit
    homerBlocks
    proxyPaths
    homeProxyPaths
    privateProxyPaths
    ;
}
