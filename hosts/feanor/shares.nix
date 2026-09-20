###############################################################################
#
#  Feanor - file sharing (SMB / NFS / WebDAV)
#
#  Replaces cirdan's File Station shares. Share names match the originals so
#  existing consumers keep working after a DNS/IP change:
#    - hosts/common/optional/cirdan-smb-shares.nix (estel, durin, desktops)
#    - Kavita reads Comics over SMB
#    - GrapheneOS writes mobile backups to NetBackup over WebDAV
#
#  TODO before cutover: SMB credentials currently live in sops as
#  `cirdan-smb-primary-secrets` / `cirdan-smb-secondary-secrets`. Either reuse
#  those verbatim (simplest - clients need no change) or mint feanor-specific
#  ones and update the consumer module.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:

let
  pool = "/silmaril";
  # Literal rather than config.users.groups.datadat.name: this file defines a
  # user (webdav) in that group, so reading users.groups here is a cycle.
  dataGroup = "datadat";

  # cirdan served two classes of share: world-writable within the household,
  # and datadat-owned. Mirror that split rather than inventing a new scheme.
  primaryShare = path: {
    inherit path;
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "create mask" = "0664";
    "directory mask" = "0775";
    "force group" = dataGroup;
  };

  readOnlyShare =
    path:
    (primaryShare path)
    // {
      "read only" = "yes";
    };
in
{
  ############################### SMB #######################################

  services.samba = {
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        "server string" = "feanor";
        "workgroup" = "WORKGROUP";
        "security" = "user";
        "map to guest" = "never";

        # SMB3 only. cirdan's DSM defaults allowed SMB1 for ancient clients;
        # nothing in this house needs it and it is a liability.
        "server min protocol" = "SMB3";
        "client min protocol" = "SMB3";

        # Large sequential media reads benefit substantially from these.
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "use sendfile" = "yes";
        "aio read size" = "16384";
        "aio write size" = "16384";

        # No printers on a NAS.
        "load printers" = "no";
        "printing" = "bsd";
        "printcap name" = "/dev/null";
        "disable spoolss" = "yes";
      };

      Comics = readOnlyShare "${pool}/comics"; # Kavita only ever reads
      Jellyfin = primaryShare "${pool}/jellyfin";
      Music = primaryShare "${pool}/music";
      NetBackup = primaryShare "${pool}/netbackup";
      Immich = primaryShare "${pool}/immich";
    };
  };

  # Makes the box show up in Finder/Windows network browsing, as DSM did.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Samba keeps its own password database (passdb.tdb) and NixOS has no
  # declarative option for it, so seed it on activation. Idempotent: smbpasswd
  # updates the entry if the user already exists.
  #
  # Uses the same password as cirdan, so the client-side credential files
  # (feanor-smb-primary-secrets / feanor-smb-secondary-secrets) and every
  # existing SMB mount keep working with nothing but an IP change.
  sops.secrets."samba/feanor-tdoggett-password" = {
    mode = "0400";
  };

  systemd.services.samba-provision-users = {
    description = "Seed Samba passdb from sops";
    wantedBy = [ "multi-user.target" ];
    after = [ "samba-smbd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      pw=$(cat ${config.sops.secrets."samba/feanor-tdoggett-password".path})
      printf '%s\n%s\n' "$pw" "$pw" \
        | ${lib.getExe' pkgs.samba "smbpasswd"} -s -a ${configVars.username}
    '';
  };

  ############################### NFS #######################################
  #
  # Fixed ports so the firewall rules stay static (rpc.statd and friends
  # otherwise pick ephemeral ports at boot).

  services.nfs.server = {
    enable = true;
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;

    # TODO: narrow to the actual LAN CIDR from nix-secrets once feanor's
    # subnet entry exists. Exporting to the whole RFC1918 space is lazier
    # than it should be for a box holding everything.
    exports = ''
      ${pool}/jellyfin  192.168.0.0/16(ro,sync,no_subtree_check)
      ${pool}/music     192.168.0.0/16(ro,sync,no_subtree_check)
    '';
  };

  ############################## WebDAV #####################################
  #
  # GrapheneOS mobile backup target. Bound to localhost - it is reached
  # through the reverse proxy, which is what terminates TLS and where auth
  # belongs. Never expose this directly.

  # hacdias/webdav v5 schema: `directory` + `permissions`, NOT the v4
  # `scope` + `modify` pair.
  #
  # No bcrypt hash needed. v5 understands a `{env}VAR` prefix, and the NixOS
  # module explicitly recommends it over putting credentials in settings -
  # anything in `settings` lands in the world-readable Nix store. So the
  # password comes in through an EnvironmentFile that sops renders at
  # activation from the plain `webdav` secret.
  services.webdav = {
    enable = true;
    user = "webdav";
    group = dataGroup;
    environmentFile = config.sops.templates."webdav.env".path;
    settings = {
      address = "127.0.0.1";
      port = configVars.networking.ports.tcp.webdav;
      directory = "${pool}/netbackup";
      permissions = "CRUD"; # GrapheneOS needs to create and overwrite backups
      users = [
        {
          username = "{env}WEBDAV_USERNAME";
          password = "{env}WEBDAV_PASSWORD";
        }
      ];
    };
  };

  sops.secrets."webdav" = { };
  sops.templates."webdav.env".content = ''
    WEBDAV_USERNAME=${configVars.username}
    WEBDAV_PASSWORD=${config.sops.placeholder."webdav"}
  '';

  users.users.webdav = {
    isSystemUser = true;
    group = dataGroup;
    home = "${pool}/netbackup";
  };

  networking.firewall.allowedTCPPorts = [
    2049 # nfsd
    4000
    4001
    4002
  ];
  networking.firewall.allowedUDPPorts = [
    2049
    4000
    4001
    4002
  ];
}
