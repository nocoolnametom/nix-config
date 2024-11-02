{
  pkgs,
  config,
  lib,
  ...
}:
let
  iniFormat = pkgs.formats.ini { };
in
{
  home.file."${config.home.homeDirectory}/.wakatime.cfg".source =
    iniFormat.generate "wakatime-config-${config.home.username}"
      {
        settings = {
          api_key_vault_cmd = "cat ${config.sops.secrets.wakatime-key.path}";
        };
      };
}
