{
  pkgs,
  config,
  lib,
  configLib,
  configVars,
  inputs,
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

  # Allow user to login via SSH
  services.openssh.settings.AllowUsers = [
    config.users.users.${configVars.username}.name
  ];

  users.mutableUsers = lib.mkDefault false;

  users.users.${configVars.username} = {
    isNormalUser = true;
    # I never could get the sops secret version of this to work with a hashedPasswordFile
    hashedPassword = lib.mkDefault "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";
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
        "kvm" # virtualization
        "adbusers" # android debugging
        "video" # monitor
        "dialout" # serial ports for arduino
      ];
  };
}
