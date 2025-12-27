###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/smeagol/persistence.nix
#
# This does NOT use the home-manager modules as I dislike how it loads files
# after login.
#
###############################################################################

{
  inputs,
  configVars,
  configLib,
  config,
  lib,
  ...
}:

{
  imports = [
    (configLib.relativeToRoot "hosts/common/optional/auto-persist-dirs.nix")
  ];

  # this folder is where the files will be stored (don't put it in tmpfs)
  # The directive for if persistence is enabled is in the system-level file, if used
  environment.persistence."${configVars.persistFolder}".users."${configVars.username}" =
    lib.optionals (config.environment.persistence."${configVars.persistFolder}".enable)
      {
        directories = [
          # User directories
          "Desktop"
          "Documents"
          "Downloads"
          "Games"
          "Music"
          "Pictures"
          "Projects"
          "Sync" # syncthing
          "Videos"
          "bin"

          # Machine-specific app configs
          ".claude"

          # Machine-specific app data
          ".local/share/bottles"
          ".local/share/direnv" # devenv/direnv
          ".local/share/Steam"
          ".local/share/syncthing" # syncthing
          ".local/share/Trash" # desktop trash
          ".local/state/cliphist" # clipboard history
          ".local/state/syncthing" # syncthing
          ".mozilla"
          ".steam"
          ".zen"

          # Desktop app configs (from feature modules)
          ".config/BraveSoftware/Brave-Browser" # brave
          ".config/discord" # discord
          ".config/google-chrome" # google-chrome
          ".config/obsidian" # obsidian
          ".config/Slack" # slack
          ".config/vlc" # vlc
          ".config/zed" # zed
          ".vscode" # vscode
          ".config/Code" # vscode/cursor
          ".Immersed" # immersed

          # Foundational infrastructure (used system-wide)
          {
            directory = ".gnupg";
            mode = "0700";
          }
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
          {
            directory = ".pki";
            mode = "0700";
          }
          {
            directory = ".ssh";
            mode = "0700";
          }
          {
            directory = ".yubico";
            mode = "0700";
          }
          ".config/Yubico"
        ];
        files = [
          ".bash_history"
          ".claude.json"
          ".claude.json.backup"
          ".ImmersedConf" # immersed
        ];
      };

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
