###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/thinkpadx1/persistence.nix
#
# This does NOT use the home-manager modules as I dislike how it loads files
# after login.
#
###############################################################################

{ inputs, ... }:

{
  # imports = [ inputs.impermanence.nixosModules.impermanence ];

  # this folder is where the files will be stored (don't put it in tmpfs)
  # The directive for if persistence is enabled is in the system-level file, if used
  environment.persistence."/persist".users.tdoggett = {
    directories = [
      # "Documents"
      "Downloads"
      # "Music"
      # "Pictures"
      "Projects"
      # "Videos"
      # "VirtualBox VMs"
      ".config/BraveSoftware/Brave-Browser"
      ".config/discord"
      ".config/jellyfin.org"
      ".config/obsidian"
      ".config/Slack"
      ".config/vlc"
      ".config/zed"
      ".local/share/direnv"
      ".mozilla"
      # ".config/Yubico"
      ".cache/czkawka"
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
      # THIS FILE MUST EXIST TO USE ANY SECRETS LIKE WITH OPENSSH!
      #TODO I'm actually loading this from the nix-secrets in the system-level hosts/common/core/sops.nix
      # So this line probably isn't needed anymore
      #".config/sops/age/keys.txt"
    ];
  };

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
