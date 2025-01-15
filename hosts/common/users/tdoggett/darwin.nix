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
  aliasedName = configVars.networking,work.aliases."${config.networking.hostName}";
in
{
  # User-level persistence is loaded in the `home/<username>/persistence/<aliasedName>.nix` file!

  # Here is where the Home Manager magic happens!
  home-manager.users.${configVars.username} = import (
    configLib.relativeToRoot "home/${configVars.username}/${aliasedName}.nix"
  );

  users.users.${configVars.username} = {
    # Right now we're only using this for the authorizedKeys
    openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
  };
}
