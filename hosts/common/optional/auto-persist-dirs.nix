###############################################################################
#
# Auto-Persist Directory Initialization
#
# Automatically creates persistence directories by:
# 1. Checking if directory exists in /persist -> Skip
# 2. If not, checking if directory exists on system -> Copy with cp -a
# 3. If neither exists -> Create empty with correct ownership
#
# Enabled by default when any persistence is enabled.
# To override: persistence.autoCreateDirs.enable = false;
#
###############################################################################

{
  config,
  lib,
  ...
}:
let
  cfg = config.persistence.autoCreateDirs;

  # Check if any /var/lib/private subdirectories are being persisted
  hasPrivateLibDirs = lib.any (
    persistConfig:
    if persistConfig.enable or false then
      lib.any (
        dir:
        let
          dirPath = if builtins.isString dir then dir else dir.directory;
        in
        lib.hasPrefix "/var/lib/private/" dirPath
      ) (persistConfig.directories or [ ])
    else
      false
  ) (lib.attrValues (config.environment.persistence or { }));

  # Generate initialization script for all persistence declarations
  mkInitScript =
    persistPath: username: userConfig:
    let
      persistHome = "${persistPath}/home/${username}";

      # Get user info for ownership
      userInfo =
        config.users.users.${username} or {
          uid = "1000";
          group = "users";
        };
      uid = toString (userInfo.uid or 1000);
      gid = toString (config.users.groups.${userInfo.group}.gid or 100);

      # Generate init commands for a directory
      mkDirInit =
        entry:
        let
          dirPath = if builtins.isString entry then entry else entry.directory;
          mode = if builtins.isString entry then "0755" else entry.mode;
          isAbsolute = lib.hasPrefix "/" dirPath;

          # Handle absolute paths (system directories)
          persistTarget = if isAbsolute then "${persistPath}${dirPath}" else "${persistHome}/${dirPath}";
          systemSource = if isAbsolute then dirPath else "/home/${username}/${dirPath}";

          # Special handling for /var/lib/private/* - always use 0700
          actualMode = if lib.hasPrefix "/var/lib/private/" dirPath then "0700" else mode;
          actualOwner = if isAbsolute then "root" else uid;
          actualGroup = if isAbsolute then "root" else gid;
        in
        ''
          # Initialize: ${dirPath}
          if [ ! -e "${persistTarget}" ]; then
            if [ -e "${systemSource}" ]; then
              echo "Copying existing directory: ${systemSource} -> ${persistTarget}"
              mkdir -p "$(dirname "${persistTarget}")"
              cp -a "${systemSource}" "${persistTarget}"
              chown -R ${actualOwner}:${actualGroup} "${persistTarget}"
              chmod ${actualMode} "${persistTarget}"
            else
              echo "Creating new directory: ${persistTarget}"
              mkdir -p "${persistTarget}"
              chown ${actualOwner}:${actualGroup} "${persistTarget}"
              chmod ${actualMode} "${persistTarget}"
            fi
          fi
        '';

      dirInits = map mkDirInit (userConfig.directories or [ ]);
    in
    lib.concatStringsSep "\n" dirInits;

  # Generate all initialization scripts
  allInitScripts = lib.concatStringsSep "\n" (
    lib.flatten (
      lib.mapAttrsToList (
        persistPath: persistConfig:
        if persistConfig.enable or false then
          lib.mapAttrsToList (username: userConfig: mkInitScript persistPath username userConfig) (
            persistConfig.users or { }
          )
        else
          [ ]
      ) (config.environment.persistence or { })
    )
  );
in
{
  options.persistence.autoCreateDirs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = lib.any (persistConfig: persistConfig.enable or false) (
        lib.attrValues (config.environment.persistence or { })
      );
      defaultText = lib.literalExpression "true if any persistence is enabled, false otherwise";
      description = "Automatically create persistence directories by copying from system or creating empty. Defaults to match persistence enable state.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Run before impermanence sets up bind-mounts
    system.activationScripts.autoInitPersistDirs = {
      deps = [
        "users"
        "groups"
        "specialfs"
      ];
      text = ''
        echo "Initializing persistence directories..."

        ${lib.optionalString hasPrivateLibDirs ''
          # Special handling for /var/lib/private - must be 0700 for systemd DynamicUser services
          for persist_root in ${
            lib.concatStringsSep " " (
              lib.mapAttrsToList (path: _: path) (config.environment.persistence or { })
            )
          }; do
            if [ -d "$persist_root" ]; then
              echo "Securing /var/lib/private in $persist_root"
              mkdir -p "$persist_root/var/lib/private"
              chmod 0700 "$persist_root/var/lib/private"
              chown root:root "$persist_root/var/lib/private"
            fi
          done
        ''}

        ${allInitScripts}
      '';
    };

    # Ensure /var/lib/private always has correct permissions in running system
    systemd.tmpfiles.rules = lib.mkIf hasPrivateLibDirs [
      "d /var/lib/private 0700 root root -"
    ];
  };
}
