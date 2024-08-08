{
  pkgs,
  config,
  lib,
  configLib,
  configVars,
  ...
}:
let
  # Allows us to reference groups that may not exist on the system
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  # Loads all public key files into a list without having to reference them directly
  pubKeys = lib.filesystem.listFilesRecursive (./keys);
in
{
  # User-level persistence is loaded in the `hosts/common/<hosts>/default.nix!

  # Here is where the Home Manager magic happens!
  home-manager.users.${configVars.username} = import (
    configLib.relativeToRoot "home/${configVars.username}/${config.networking.hostName}"
  );

  sops.secrets."tdoggett/passwordHash" = {
    # Needs to be placed in an explicit path, otherwise the `hashedPasswordFile` option doesn't work
    path = "/run/tdoggett-passwordHash";
    neededForUsers = true;
  };
  users.mutableUsers = false;

  users.users.tdoggett = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."tdoggett/passwordHash".path;
    openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
    extraGroups =
      [ "wheel" ]
      ++ ifTheyExist [
        "users"
        "input" # input devices
        "audio" # audio levels
        "disk" # mount stuff
        "networkmanager" # connect to network
        "docker" # docker
        "video" # monitor
        "dialout" # serial ports for arduino
      ];

    shell = pkgs.bash; # default shell;
  };
}
