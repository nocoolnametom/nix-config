{
  config,
  configVars,
  configLib,
  lib,
  ...
}:
let
  pathtokeys = configLib.relativeToRoot "hosts/common/users/${configVars.username}/keys";
  yubikeys =
    lib.lists.forEach (builtins.attrNames (builtins.readDir pathtokeys))
      # Remove the .pub suffix
      (key: lib.substring 0 (lib.stringLength key - lib.stringLength ".pub") key);
  yubikeyPublicKeyEntries = lib.attrsets.mergeAttrsList (
    lib.lists.map
      # list of dicts
      (key: { ".ssh/${key}.pub".source = "${pathtokeys}/${key}.pub"; })
      yubikeys
  );

  identityFiles = [
    "id_yubikey" # This is an auto symlink to whatever yubikey is plugged in. See modules/common/yubikey
    "id_ed25519" # fallback to id_ed25519 if yubikeys are not present
  ];
in
{
  programs.ssh = {
    enable = lib.mkDefault true;
    compression = lib.mkDefault true;
    addKeysToAgent = lib.mkDefault "yes"; # req'd for enabling yubikey-agent

    # FIXME: This should probably be for git systems only?
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/S.%r@%h:%p";
    controlPersist = "10m";

    matchBlocks = {
      "git" = {
        host = "gitlab.com github.com";
        user = "git";
        forwardAgent = true;
        identitiesOnly = true;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "elrond" = {
        host = configVars.networking.external.elrond.name;
        hostname = configVars.networking.external.elrond.ip;
        user = "root";
        port = configVars.networking.ports.tcp.remoteSsh;
      };
      "bombadil" = {
        host = configVars.networking.external.bombadil.mainUrl;
        port = configVars.networking.ports.tcp.remoteSsh;
      };
      "steamdeck" = {
        host = configVars.networking.subnets.steamdeck.name;
        hostname = configVars.networking.subnets.steamdeck.ip; # Local Network
        user = "deck";
        port = 9001;
      };
    };

  };
  home.file = {
    ".ssh/config.d/.keep".text = "# Managed by Home Manager";
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
  } // yubikeyPublicKeyEntries;
}
