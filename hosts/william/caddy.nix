{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  services.caddy.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 2019 ];

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
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}
      '';
    };
    "${configVars.networking.subdomains.budget}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.budget}
      '';
    };
    "${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}
      '';
    };
    "${configVars.networking.subdomains.comfyui}.${configVars.domain}" = {
      # Served through cirdan from archer/smeagol
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.comfyuimini}.${configVars.domain}" = {
      # Served through cirdan from archer/smeagol
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.delugeweb}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.flood}.${configVars.domain}" = {
      # Served through cirdan from bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.nzbhydra}.${configVars.domain}" = {
      # Served through cirdan from bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.immich}.${configVars.homeDomain}" = {
        # I haven't gotten immich working locally on william yet, so it's on cirdan's Podtainer for now
        # reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.immich}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}
      '';
    };
    "${configVars.networking.subdomains.immich-share}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.immich-share}
      '';
    };
    "${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.hedgedoc}
      '';
    };
    "${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}
      '';
    };
    "${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.karakeep}
      '';
    };
    "${configVars.networking.subdomains.kavitan}.${configVars.domain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}
      '';
    };
    "${configVars.networking.subdomains.kavita}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}
      '';
    };
    "${configVars.networking.subdomains.mealie}.${configVars.homeDomain}" = {
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.mealie}
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
      # Served through cirdan for william
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.nzbget}.${configVars.domain}" = {
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.ombi}.${configVars.homeDomain}" = {
      # Servied through cirdan for william
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.openwebui}.${configVars.domain}" = {
        # Will move to barliman soon
        # reverse_proxy ${configVars.networking.subnets.archer.ip}:${builtins.toString configVars.networking.ports.tcp.openwebui}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.archer.ip}:${builtins.toString configVars.networking.ports.tcp.openwebui}
      '';
    };
    "${configVars.networking.subdomains.paperless}.${configVars.homeDomain}" = {
        # I can't get paperless to work on william yet, so it's on cirdan's portainer
        # reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.paperless}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.william.ip}:${builtins.toString configVars.networking.ports.tcp.paperless}
      '';
    };
    "${configVars.networking.subdomains.pinchflat}.${configVars.domain}" = {
      # Served through cirdan from bert
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
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sickgear}.${configVars.domain}" = {
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sonarr}.${configVars.domain}" = {
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.stash}.${configVars.domain}" = {
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.stashvr}.${configVars.domain}" = {
      # Served through cirdan from cirdan (because we can't compile it on bert/william)
      extraConfig = ''
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
