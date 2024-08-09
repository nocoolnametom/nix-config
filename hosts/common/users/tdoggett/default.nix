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

  users.mutableUsers = false;

  users.users.tdoggett = {
    isNormalUser = true;
    # I never could get the sops secret version of this to work with a hashedPasswordFile
    hashedPassword = "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";
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
        "lxd"
        "adbusers"
        "video" # monitor
        "dialout" # serial ports for arduino
      ];

    shell = pkgs.bash; # default shell;
  };
}
