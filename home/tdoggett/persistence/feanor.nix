###############################################################################
#
# User-Level Persistence
# System-level is handled in hosts/feanor/persistence.nix
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
          {
            directory = ".gnupg";
            mode = "0700";
          }
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
          {
            directory = ".ssh";
            mode = "0700";
          }
        ];
        files = [ ".bash_history" ];
      };

  # Impermanence creates intermediate parent directories (e.g. /home/tdoggett,
  # /home/tdoggett/.local, /home/tdoggett/.local/share) as root:root because
  # its bind-mount services run *before* local-fs.target.  systemd-tmpfiles-
  # setup runs *after* local-fs.target, so these rules reliably correct
  # ownership each boot before any user services (home-manager, syncthing, …)
  # start.
  systemd.tmpfiles.rules =
    let
      u = configVars.username;
    in
    [
      "d /home/${u}          0700 ${u} users - -"
      "d /home/${u}/.local   0755 ${u} users - -"
      "d /home/${u}/.local/share 0755 ${u} users - -"
    ];

  # Don't allow mutation of users outside of the config.
  users.mutableUsers = false;
}
