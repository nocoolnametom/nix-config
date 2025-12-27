{
  config,
  lib,
  ...
}:
let
  # Automatically generate tmpfiles rules for ALL persistence declarations
  # This ensures directories exist in /persist before impermanence tries to bind-mount them

  mkTmpfilesRules =
    persistPath: username: userConfig:
    let
      # Helper to generate tmpfiles rule for a directory
      mkDirRule =
        entry:
        if builtins.isString entry then
          "d ${persistPath}/home/${username}/${entry} 0755 ${username} users -"
        else if entry ? directory then
          "d ${persistPath}/home/${username}/${entry.directory} ${entry.mode} ${username} users -"
        else
          null;

      # Helper to generate tmpfiles rule for a file
      mkFileRule =
        entry:
        if builtins.isString entry then
          "f ${persistPath}/home/${username}/${entry} 0644 ${username} users -"
        else if entry ? file then
          "f ${persistPath}/home/${username}/${entry.file} ${entry.mode or "0644"} ${username} users -"
        else
          null;

      dirRules = lib.filter (x: x != null) (map mkDirRule (userConfig.directories or [ ]));
      fileRules = lib.filter (x: x != null) (map mkFileRule (userConfig.files or [ ]));
    in
    dirRules ++ fileRules;

  # Generate rules for all users across all persistence paths
  allRules = lib.flatten (
    lib.mapAttrsToList (
      persistPath: persistConfig:
      if persistConfig.enable or false then
        lib.flatten (
          lib.mapAttrsToList (username: userConfig: mkTmpfilesRules persistPath username userConfig) (
            persistConfig.users or { }
          )
        )
      else
        [ ]
    ) (config.environment.persistence or { })
  );
in
{
  # Automatically create directories for all persistence declarations
  systemd.tmpfiles.rules = allRules;
}
