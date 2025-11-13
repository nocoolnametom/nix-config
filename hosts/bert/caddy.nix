{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  services.caddy.enable = true;

  # Virtual hosts configuration
  services.caddy.virtualHosts = {
    "${configVars.homeDomain}" = {
      # Redirect empty main domain to the auth page
      extraConfig = ''
        redir https://${configVars.networking.subdomains.authentik}.{host}{uri}
      '';
    };
    "${configVars.healthDomain}" = {
      extraConfig = ''
        respond / "Service is UP" 200
      '';
    };
    "${configVars.networking.subdomains.authentik}.${configVars.homeDomain}" = {
      extraConfig = ''
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }
        reverse_proxy @websockets ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };
    "${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}
      '';
    };
    "${configVars.networking.subdomains.budget}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget}
      '';
    };
    "${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}
      '';
    };
    "${configVars.networking.subdomains.comfyui}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy ${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyui}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.comfyuimini}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy ${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyuimini}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.delugeweb}.${configVars.domain}" =
      lib.mkIf config.services.deluge.web.enable
        {
          extraConfig = ''
            # reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.delugeweb}
            reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
          '';
        };
    "${configVars.networking.subdomains.flood}.${configVars.domain}" =
      lib.mkIf config.services.flood.enable
        {
          extraConfig = ''
            # reverse_proxy 127.0.0.1:${builtins.toString config.services.flood.port}
            reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
          '';
        };
    "${configVars.networking.subdomains.nzbhydra}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.nzbhydra}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.immich}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}
      '';
    };
    "${configVars.networking.subdomains.immich-share}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich-share}
      '';
    };
    "${configVars.networking.subdomains.jellyfin}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}
      '';
    };
    "${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}
      '';
    };
    "${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.karakeep}
      '';
    };
    "${configVars.networking.subdomains.kavita}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}
      '';
    };
    "${configVars.networking.subdomains.kavitan}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}
      '';
    };
    "${configVars.networking.subdomains.mylar}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.mylar}
      '';
    };
    "${configVars.networking.subdomains.nas}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.nas}
      '';
    };
    "${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString config.services.navidrome.settings.Port}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.nzbget}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.nzbget}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.ombi}.${configVars.homeDomain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString config.services.ombi.port}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.openwebui}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.openwebui}
      '';
    };
    "${configVars.networking.subdomains.pinchflat}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.podfetch}
      '';
    };
    "${configVars.networking.subdomains.portainer}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.portainer}
      '';
    };
    "${configVars.networking.subdomains.radarr}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.radarr}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sickgear}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString config.services.sickbeard.port}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sonarr}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString configVars.networking.ports.tcp.sonarr}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.standardnotes}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes}
      '';
    };
    "${configVars.networking.subdomains.standardnotes-files}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-files}
      '';
    };
    "${configVars.networking.subdomains.standardnotes-server}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-server}
      '';
    };
    "${configVars.networking.subdomains.stash}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy 127.0.0.1:${builtins.toString config.services.stashapp.port}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.stashvr}.${configVars.domain}" = {
      extraConfig = ''
        # reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.stashvr}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.tubearchivist}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.tubearchivist}
      '';
    };
  };
}
