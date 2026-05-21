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
  identityFilePaths = lib.lists.forEach identityFiles (
    file: "${config.home.homeDirectory}/.ssh/${file}"
  );
in
{
  programs.ssh = {
    enable = lib.mkDefault true;
    enableDefaultConfig = lib.mkDefault false;

    settings = {
      "*" = {
        ForwardAgent = lib.mkDefault true;
        UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
        AddKeysToAgent = lib.mkDefault "yes"; # req'd for enabling yubikey-agent
      };
      "git" = {
        header = "Host gitlab.com github.com";
        User = "git";
        ForwardAgent = true;
        IdentitiesOnly = true;
        IdentityFile = identityFilePaths;
      };
      "bombadil" = {
        header = "Host ${configVars.networking.external.bombadil.name} ${configVars.networking.external.bombadil.mainUrl}";
        HostName = configVars.networking.external.bombadil.mainUrl;
        Port = configVars.networking.ports.tcp.remoteSsh;
        IdentityFile = identityFilePaths;
      };
      "${configVars.networking.subdomains.estelSshProxy}.${configVars.domain}" = {
        Port = configVars.networking.ports.tcp.estelSshProxy;
        IdentityFile = identityFilePaths;
      };
      "archer" = {
        header = "Host ${configVars.networking.subnets.archer.name} ${configVars.networking.subnets.archer.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.archer.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "barliman" = {
        header = "Host ${configVars.networking.subnets.barliman.name} ${configVars.networking.subnets.barliman.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.barliman.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "cirdan" = {
        header = "Host ${configVars.networking.subnets.cirdan.name} ${configVars.networking.subnets.cirdan.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.cirdan.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "durin" = {
        header = "Host ${configVars.networking.subnets.durin.name} ${configVars.networking.subnets.durin.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.durin.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "estel" = {
        header = "Host ${configVars.networking.subnets.estel.name} ${configVars.networking.subnets.estel.name}.${configVars.homeDomain} estel-ts";
        HostName = configVars.networking.subnets.estel.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "framework" = {
        header = "Host ${configVars.networking.subnets.framework.name} ${configVars.networking.subnets.framework.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.framework.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "macbookpro" = {
        header = "Host ${configVars.networking.work.macbookpro.name} macbookpro";
        HostName = configVars.networking.work.macbookpro.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "pangolin11" = {
        header = "Host ${configVars.networking.subnets.pangolin11.name} ${configVars.networking.subnets.pangolin11.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.pangolin11.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "router" = {
        header = "Host ${configVars.networking.subnets.router.name} ${configVars.networking.subnets.router.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.router.ip;
        Port = configVars.networking.ports.tcp.remoteSsh;
        IdentityFile = identityFilePaths;
      };
      "smeagol" = {
        header = "Host ${configVars.networking.subnets.smeagol.name} ${configVars.networking.subnets.smeagol.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.smeagol.ip;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
      "steamdeck" = {
        header = "Host ${configVars.networking.subnets.steamdeck.name} ${configVars.networking.subnets.steamdeck.name}.${configVars.homeDomain}";
        HostName = configVars.networking.subnets.steamdeck.ip;
        User = configVars.networking.subnets.steamdeck.username;
        Port = configVars.networking.ports.tcp.localSsh;
        IdentityFile = identityFilePaths;
      };
    };

  };
  home.file = {
    ".ssh/config.d/.keep".text = "# Managed by Home Manager";
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
  }
  // yubikeyPublicKeyEntries;
}
