###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/bert/persistence.nix
#
# This does NOT use the home-manager modules as I dislike how it loads files
# after login.
#
###############################################################################

{
  inputs,
  configVars,
  config,
  lib,
  ...
}:

{
  # this folder is where the files will be stored (don't put it in tmpfs)
  # The directive for if persistence is enabled is in the system-level file, if used
  environment.persistence."${configVars.persistFolder}".users."${configVars.username}" =
    lib.optionals (config.environment.persistence."${configVars.persistFolder}".enable)
      {
        directories = [
          "Projects"
          ".local/share/direnv"
          # ".config/Yubico"
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
        files = [ ".bash_history" ];
      };

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
