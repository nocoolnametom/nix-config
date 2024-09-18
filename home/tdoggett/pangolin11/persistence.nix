###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/pangolin11/persistence.nix
#
# This does NOT use the home-manager modules as I dislike how it loads files
# after login.
#
###############################################################################

{ inputs, configVars, ... }:

{
  # this folder is where the files will be stored (don't put it in tmpfs)
  # The directive for if persistence is enabled is in the system-level file, if used
  environment.persistence."${configVars.persistFolder}".users.tdoggett = {
    directories = [
      "Arduino"
      "DataGripProjects"
      "Desktop"
      "Documents"
      "Downloads"
      "Games"
      "Music"
      "Pictures"
      "Projects"
      "Videos"
      "VirtualBox VMs"
      "bin"
      ".config/google-chrome"
      ".config/BraveSoftware/Brave-Browser"
      ".config/Code"
      ".config/discord"
      ".config/jellyfin.org"
      ".config/KADOKAWA"
      ".config/Proton Mail"
      ".config/obsidian"
      ".config/Slack"
      ".config/vlc"
      ".config/waynergy/tls"
      ".config/Yubico"
      ".config/zed"
      ".Immersed"
      ".local/share/direnv"
      ".local/share/Steam"
      ".mozilla"
      ".cache/czkawka"
      ".steam"
      ".vscode"
      {
        directory = ".gnupg";
        mode = "0700";
      }
      {
        directory = ".local/share/keyrings";
        mode = "0700";
      }
      # { directory = ".nixops"; mode = "0700"; }
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
    ];
    files = [
      ".bash_history"
      ".davmail.properties"
      ".ImmersedConf"
      "intelephense/license.txt"
    ];
  };

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
