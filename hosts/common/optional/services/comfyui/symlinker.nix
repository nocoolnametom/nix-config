{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    types
    concatStringsSep
    mapAttrsToList
    flatten
    hasAttrByPath
    elem
    ;
in
{
  options.services.comfyui.symlinkPaths = mkOption {
    type = types.attrsOf types.str;
    default = { };
    description = "Defines named symlink target directories for comfyui models.";
  };

  config = mkIf config.services.comfyui.enable {
    systemd.tmpfiles.rules = mapAttrsToList (
      name: path: "d ${path} 0777 root root -"
    ) config.services.comfyui.symlinkPaths;
    system.activationScripts.linkComfyuiModels = {
      text =
        let
          models = config.services.comfyui.models;
          generateLinks = concatStringsSep "\n" (
            flatten (
              mapAttrsToList (
                linkName: targetDir:
                let
                  modelsForPath = lib.filter (
                    drv:
                    hasAttrByPath [ "passthru" "comfyui" "installPaths" ] drv
                    && elem linkName drv.passthru.comfyui.installPaths
                  ) models;
                in
                [
                  "mkdir -p ${targetDir}"
                  "find ${targetDir}/ -maxdepth 1 -type l -exec rm -f {} \\;"
                  (concatStringsSep "\n" (
                    map (model: "ln -sfn ${model} ${targetDir}/\$(basename ${model.name})") modelsForPath
                  ))
                ]
              ) config.services.comfyui.symlinkPaths
            )
          );
        in
        ''
          ${generateLinks}
        '';
    };
  };
}
