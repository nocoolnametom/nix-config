{ configVars, ... }:
let
  hostConfig = configVars.networking.subnets."${config.networking.hostName}".protonWg;
  protonWg = {
    ifaceName = "protonWg-${config.networking.hostName}";
    privateKey = hostConfig.privateKey; # This config has been removed from Proton, but I still shouldn't share old keys
    address = hostConfig.address;
    fullAddress = "${protonWg.address}/32";
    dns = hostConfig.dns;
    peer1.public = hostConfig.peer1.public;
    peer1.address = hostConfig.peer1.address;
    peer1.port = hostConfig.peer1.port;
    peer1.allowedIPs = [ "0.0.0.0/0" ];
  };
in
{
  # Proton Wireguard Setup
  # I want to only use this with Transmission, so until I can keep everything else from
  # using it (like ddclient) I'm turning it off and clearing my torrents.  I don't really
  # torrent much anymore anyways.
  # networking.wg-quick.interfaces."${protonWg.ifaceName}" = {
  #   address = [ protonWg.fullAddress ];
  #   dns = [ protonWg.dns ];
  #   privateKey = protonWg.privateKey;
  #   peers = [{
  #     publicKey = protonWg.peer1.public;
  #     allowedIPs = protonWg.peer1.allowedIPs;
  #     endpoint = "${protonWg.peer1.address}:${toString protonWg.peer1.port}";
  #     persistentKeepalive = 25;
  #   }];
  # };
}
