###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/pangolin11/persistence.nix
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
          "Arduino"
          "DataGripProjects"
          "Desktop"
          "Documents"
          "Downloads"
          "Games"
          "Music"
          "Pictures"
          "Projects"
          "Sync" # syncthing
          "Videos"
          "VirtualBox VMs"
          "bin"

          # Machine-specific app configs
          ".claude"
          ".config/calibre"
          ".config/cosmic"
          ".config/jellyfin.org"
          ".config/KADOKAWA"
          ".config/net.imput.helium"
          ".config/Proton Mail"
          ".config/ticktick"
          ".config/waynergy/tls"

          # Machine-specific app data
          ".local/share/bottles"
          ".local/share/calibre-ebook.com"
          ".local/share/direnv" # devenv/direnv
          ".local/share/flatpak"
          ".local/share/Steam"
          ".local/share/syncthing" # syncthing
          ".local/share/Trash" # desktop trash
          ".local/state/cliphist" # clipboard history
          ".local/state/cosmic" # Cosmic desktop state
          ".local/state/cosmic-comp" # Cosmic compositor state
          ".local/state/syncthing" # syncthing
          ".mozilla"
          ".cache/czkawka"
          ".steam"
          ".zen"

          # Desktop app configs (from feature modules)
          ".config/BraveSoftware/Brave-Browser" # brave
          ".config/discord" # discord
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
          ".config/cosmic-initial-setup-done" # Cosmic welcome screen completion
          ".davmail.properties"
          ".ImmersedConf" # immersed
          "intelephense/license.txt"
        ];
      };

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
