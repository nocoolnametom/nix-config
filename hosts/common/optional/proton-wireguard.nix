{ ... }:
let
  protonWg = {
    ifaceName = "protonWg-bert";
    privateKey = "MGJaa8OS4WRhQuFxX/H0PCEimE//CQIrBjaFILnQAls=";
    address = "10.2.0.2";
    fullAddress = "${protonWg.address}/32";
    dns = "10.2.0.1";
    peer1.public = "Lnp+1fMB1vwK7kNKH2DD7LYIHwdlgYfrKEj0op1SsGk=";
    peer1.address = "193.148.18.98";
    peer1.port = 51820;
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
