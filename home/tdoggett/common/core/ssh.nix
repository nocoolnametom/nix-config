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
    "id_personal" # fallback to personal ed25519 if yubikeys are not present
  ];
in
{
  programs.ssh = {
    enable = lib.mkDefault true;
    compression = lib.mkDefault true;
    addKeysToAgent = lib.mkDefault "yes"; # req'd for enabling yubikey-agent

    # FIXME: This should probably be for git systems only?
    controlMaster = lib.mkDefault "auto";
    controlPath = lib.mkDefault "~/.ssh/sockets/master-%r@%h:%p";
    controlPersist = lib.mkDefault "10m";

    matchBlocks = {
      "git" = {
        host = "gitlab.com github.com";
        user = "git";
        forwardAgent = true;
        identitiesOnly = true;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "bombadil" = {
        host = "${configVars.networking.external.bombadil.name} ${configVars.networking.external.bombadil.mainUrl}";
        hostname = configVars.networking.external.bombadil.mainUrl;
        port = configVars.networking.ports.tcp.remoteSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "fedibox" = {
        # Havne't yet moved fedibox back over to handle the domain it usually handles
        # host = "${configVars.networking.external.fedibox.name} ${configVars.networking.external.bombadil.mainUrl}";
        # hostname = configVars.networking.external.fedibox.mainUrl;
        # port = configVars.networking.ports.tcp.remoteSsh;
        # identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
        host = "${configVars.networking.external.fedibox.name}";
        hostname = configVars.networking.external.fedibox.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = [ "${config.home.homeDirectory}/.ssh/id_fedibox" ];
        user = "root";
      };
      "bert" = {
        host = configVars.networking.subnets.bert.name;
        hostname = configVars.networking.subnets.bert.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "sauron" = {
        host = configVars.networking.subnets.sauron.name;
        hostname = configVars.networking.subnets.sauron.ip;
        user = configVars.networking.subnets.sauron.username;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "sauron-actual" = {
        host = "${configVars.networking.subnets.sauron.name}-actual";
        hostname = configVars.networking.subnets.sauron.actual;
        user = configVars.networking.subnets.sauron.username;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "smeagol" = {
        host = configVars.networking.subnets.smeagol.name;
        hostname = configVars.networking.subnets.smeagol.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "smeagol-actual" = {
        host = "${configVars.networking.subnets.smeagol.name}-actual";
        hostname = configVars.networking.subnets.smeagol.actual;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "framework" = {
        host = configVars.networking.subnets.framework.name;
        hostname = configVars.networking.subnets.framework.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "home.${configVars.domain}" = {
        host = "home.${configVars.domain}";
        port = configVars.networking.ports.tcp.remoteSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "${configVars.domain}" = {
        host = "${configVars.domain}";
        identityFile = [ "${config.home.homeDirectory}/.ssh/id_fedibox" ];
      };
      "steamdeck" = {
        host = configVars.networking.subnets.steamdeck.name;
        hostname = configVars.networking.subnets.steamdeck.ip; # Local Network
        user = configVars.networking.subnets.steamdeck.username;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
    };

  };
  home.file = {
    ".ssh/config.d/.keep".text = "# Managed by Home Manager";
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
  } // yubikeyPublicKeyEntries;
}
