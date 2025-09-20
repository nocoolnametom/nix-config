{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  services.caddy.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
    2019
  ];

  # Virtual hosts configuration
  services.caddy.virtualHosts = {
    "${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      # Redirect empty main domain to the auth page
      extraConfig = ''
        redir https://${configVars.networking.subdomains.authentik}.{host}{uri}
      '';
    };
    "${configVars.healthDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        respond / "Service is UP" 200
      '';
    };
    "${configVars.networking.subdomains.authentik}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
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
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}
      '';
    };
    "${configVars.networking.subdomains.budget}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.budget}
      '';
    };
    "${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}
      '';
    };
    "${configVars.networking.subdomains.comfyui}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan from archer/smeagol
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.comfyuimini}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan from archer/smeagol
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.delugeweb}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.flood}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan from bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.nzbhydra}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan from bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.immich}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      # I haven't gotten immich working locally on estel yet, so it's on cirdan's Podtainer for now
      # reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.immich}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}
      '';
    };
    "${configVars.networking.subdomains.immich-share}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.immich-share}
      '';
    };
    "${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.hedgedoc}
      '';
    };
    "${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}
      '';
    };
    "${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.karakeep}
      '';
    };
    "${configVars.networking.subdomains.kavitan}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}
      '';
    };
    "${configVars.networking.subdomains.kavita}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}
      '';
    };
    "${configVars.networking.subdomains.mealie}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.mealie}
      '';
    };
    "${configVars.networking.subdomains.mylar}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.mylar}
      '';
    };
    "${configVars.networking.subdomains.nas}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.nas}
      '';
    };
    "${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      # Served through cirdan for estel
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.nzbget}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.ombi}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      # Servied through cirdan for estel
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.openwebui}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Will move to barliman soon
      # reverse_proxy ${configVars.networking.subnets.archer.ip}:${builtins.toString configVars.networking.ports.tcp.openwebui}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.archer.ip}:${builtins.toString configVars.networking.ports.tcp.openwebui}
      '';
    };
    "${configVars.networking.subdomains.paperless}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      # I can't get paperless to work on estel yet, so it's on cirdan's portainer
      # reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.paperless}
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.paperless}
      '';
    };
    "${configVars.networking.subdomains.pinchflat}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # For some reason the proxy provider for authentik does NOT work with pinchflat!
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.bert.ip}:${builtins.toString configVars.networking.ports.tcp.pinchflat}
      '';
    };
    "${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.podfetch}
      '';
    };
    "${configVars.networking.subdomains.portainer}.${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.portainer}
      '';
    };
    "${configVars.networking.subdomains.radarr}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sickgear}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.sonarr}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.stash}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan for bert
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.stashvr}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      # Served through cirdan from cirdan (because we can't compile it on bert/estel)
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
      '';
    };
    "${configVars.networking.subdomains.tubearchivist}.${configVars.domain}" = {
      useACMEHost = configVars.domain;
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.tubearchivist}
      '';
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = configVars.email.letsencrypt;
  sops.secrets."porkbun/dns-failover/key" = { };
  sops.secrets."porkbun/dns-failover/secret" = { };
  sops.templates."acme-porkbun-secrets.env" = {
    content = ''
      PORKBUN_API_KEY=${config.sops.placeholder."porkbun/dns-failover/key"}
      PORKBUN_SECRET_API_KEY=${config.sops.placeholder."porkbun/dns-failover/secret"}
    '';
    owner = if config.services.caddy.enable then "caddy" else "root";
  };
  security.acme.certs = {
    "${configVars.domain}" = {
      domain = "*.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "${configVars.homeDomain}" = {
      domain = "*.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
  };
}
