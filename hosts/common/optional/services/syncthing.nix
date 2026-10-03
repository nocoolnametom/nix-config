###############################################################################
#
#  Syncthing as a system service with a LAN-reachable web UI
#
#  For always-on servers. Desktops use the Home Manager module instead
#  (home/<user>/common/optional/services/syncthing.nix), whose GUI stays on
#  localhost and so needs no login.
#
#  Here the GUI listens on all interfaces, so it gets a declarative login:
#  user = the configured username, password from sops at
#  syncthing/<hostname>-gui-password.
#
#  Folders and devices are managed in the web UI, not in Nix. With the
#  override options at their default (true) every rebuild would delete
#  anything added there, so they are off. The UI-managed config lives in
#  configDir, which hosts with impermanence must persist.
#
#  Hosts set dataDir (where synced folders live) and, if needed, group.
#
###############################################################################

{
  config,
  configVars,
  lib,
  ...
}:
let
  port = configVars.networking.ports.tcp.syncthing;
  passwordSecret = "syncthing/${config.networking.hostName}-gui-password";
in
{
  services.syncthing = {
    enable = lib.mkDefault true;
    # Small, write-heavy index DB: keep it on the system disk even when
    # dataDir is on bulk storage.
    configDir = lib.mkDefault "/var/lib/syncthing";
    guiAddress = lib.mkDefault "0.0.0.0:${toString port}";
    guiPasswordFile = config.sops.secrets.${passwordSecret}.path;
    settings.gui.user = lib.mkDefault configVars.username;
    openDefaultPorts = lib.mkDefault true; # 22000/tcp+udp for sync traffic itself
    overrideFolders = lib.mkDefault false;
    overrideDevices = lib.mkDefault false;
  };

  networking.firewall.allowedTCPPorts = [ port ];

  # Read by syncthing-init, which runs as the syncthing user.
  sops.secrets.${passwordSecret}.owner = config.services.syncthing.user;
}
