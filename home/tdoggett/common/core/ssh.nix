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
    enableDefaultConfig = lib.mkDefault false;

    matchBlocks = {
      "*" = {
        forwardAgent = lib.mkDefault true;
        userKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
        addKeysToAgent = lib.mkDefault "yes"; # req'd for enabling yubikey-agent
      };
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
      "archer" = {
        host = configVars.networking.subnets.archer.name;
        hostname = configVars.networking.subnets.archer.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "durin" = {
        host = configVars.networking.subnets.durin.name;
        hostname = configVars.networking.subnets.durin.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "estel" = {
        host = "${configVars.networking.subnets.estel.name} estel-ts";
        hostname = configVars.networking.subnets.estel.name;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "router" = {
        host = configVars.networking.subnets.router.name;
        hostname = configVars.networking.subnets.router.ip;
        port = configVars.networking.ports.tcp.remoteSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "barliman" = {
        host = configVars.networking.subnets.barliman.name;
        hostname = configVars.networking.subnets.barliman.ip;
        port = configVars.networking.ports.tcp.localSsh;
        identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
      };
      "smeagol" = {
        host = configVars.networking.subnets.smeagol.name;
        hostname = configVars.networking.subnets.smeagol.ip;
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
  }
  // yubikeyPublicKeyEntries;
}
