###############################################################################
#
#  Homelab jump host - for the VPS that holds the WireGuard tunnel to estel
#
#  Gives the host an SSH client config so "ssh estel" (over WireGuard) and
#  "ssh <lan host>" (hopping through estel) work once logged in, and adds a
#  login message with those commands plus the one-line equivalents to use
#  from a machine that lacks the usual ProxyJump config.
#
#  Hopping onward from this host needs your SSH agent (the keys stay on the
#  YubiKey), so connect here with "ssh -A". Jumping through from the client
#  ("ssh -J") avoids forwarding the agent to this host at all.
#
###############################################################################

{
  config,
  configVars,
  lib,
  ...
}:
let
  cfg = config.services.homelabJumpHost;
  user = configVars.username;
  estelWgIp = configVars.networking.wireguard.estel.ip;
  sshPort = toString configVars.networking.ports.tcp.localSsh;
  thisHost = "${user}@${
    configVars.networking.external.${config.networking.hostName}.mainUrl
  }:${toString configVars.networking.ports.tcp.remoteSsh}";

  lanHosts = lib.filter (name: configVars.networking.subnets ? ${name}) cfg.lanHosts;
  lanIp = name: configVars.networking.subnets.${name}.ip;
in
{
  options.services.homelabJumpHost = {
    lanHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "barliman"
        "durin"
        "feanor"
        "smeagol"
      ];
      description = "Hosts on the home LAN (configVars.networking.subnets names) reached through estel.";
    };
  };

  config = {
    programs.ssh.extraConfig = ''
      Host estel
        HostName ${estelWgIp}
        Port ${sshPort}
        User ${user}
    ''
    + lib.concatMapStrings (name: ''
      Host ${name}
        HostName ${lanIp name}
        Port ${sshPort}
        User ${user}
        ProxyJump estel
    '') lanHosts;

    users.motd = lib.mkAfter ''

      Reaching the homelab from here (connect to this host with "ssh -A" so
      your YubiKey agent comes along):
        ssh estel                 estel over WireGuard (${estelWgIp})
        ssh <host>                through estel: ${lib.concatStringsSep ", " lanHosts}

      Without that config:
        ssh ${user}@${estelWgIp}
        ssh -J ${user}@${estelWgIp} ${user}@<lan ip>
      ${lib.concatMapStrings (name: "    ${name}: ${lanIp name}\n") lanHosts}
      Straight from another machine (no agent forwarding needed):
        ssh -J ${thisHost} ${user}@${estelWgIp}
        ssh -J ${thisHost},${user}@${estelWgIp} ${user}@<lan ip>

    '';
  };
}
