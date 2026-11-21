# Base for running services inside a Proton VPN WireGuard network namespace
# (see modules/nixos/proton-vpn-netns.nix). Importing this sets up the Proton
# account, the namespace and the self-healing tunnel, but confines nothing by
# itself: each service's own module imports this file and adds itself, e.g.
#
#   imports = [ ../proton-vpn-netns.nix ];
#   services.proton-vpn-netns.confinedServices = [ "myservice" ];
#   services.proton-vpn-netns.forwardPorts = [ 1234 ];  # reach it from the host
#
# Confined services can only reach the internet through the tunnel (no
# fallback to the LAN) and resolve names through the VPN's DNS. Everything
# else on the host is unaffected. `confinedServices` and `forwardPorts` are
# lists, so several service modules can share the one namespace.
#
# Secrets (the Proton account itself, not the OpenVPN/IKEv2 credentials):
#   proton-vpn/account/username     account username or email
#   proton-vpn/account/password     account password
#   proton-vpn/account/totp-secret  base32 TOTP secret (account uses 2FA)
#
# Useful on the host:
#   systemctl status proton-vpn-tunnel proton-vpn-watchdog proton-vpn-portforward
#   sudo ip netns pids protonvpn                       # what is confined
#   sudo ip netns exec protonvpn wg show
#   sudo cat /var/lib/proton-vpn-netns/server.json /run/proton-vpn-netns/forwarded-port
{ config, lib, ... }:
let
  secret = name: config.sops.secrets."proton-vpn/account/${name}".path;
in
{
  sops.secrets."proton-vpn/account/username" = { };
  sops.secrets."proton-vpn/account/password" = { };
  sops.secrets."proton-vpn/account/totp-secret" = { };

  services.proton-vpn-netns = {
    enable = true;
    usernameFile = secret "username";
    passwordFile = secret "password";
    totpSecretFile = secret "totp-secret";
    country = lib.mkDefault "US";
  };

  # Alert (via systemd-failure-alert) when the tunnel has been down for a while.
  services.systemd-failure-alert.additional-services = [ "proton-vpn-watchdog" ];
}
