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
  arionSuffix = "-arion";
in
{
  options.services.comfyui.symlinkPaths = mkOption {
    type = types.attrsOf types.str;
    default = { };
    description = "Defines named symlink target directories for comfyui models.";
  };

  config = mkIf config.services.comfyui.enable {
    systemd.tmpfiles.rules = lib.flatten (
      mapAttrsToList (name: path: [
        # Original directory
        "d ${path} 0777 root root -"
        # Corresponding -arion directory
        "d ${path}${arionSuffix} 0777 root root -"
      ]) config.services.comfyui.symlinkPaths
    );
    system.activationScripts.linkComfyuiModels = {
      text =
        let
          models = config.services.comfyui.models;
          generateLinksForPath =
            linkName: targetDir:
            let
              modelsForPath = lib.filter (
                drv:
                hasAttrByPath [ "passthru" "comfyui" "installPaths" ] drv
                && elem linkName drv.passthru.comfyui.installPaths
              ) models;
              dirs = [
                {
                  path = targetDir;
                  prefix = "";
                }
                {
                  path = "${targetDir}${arionSuffix}";
                  prefix = "/mnt";
                }
              ];
            in
            concatStringsSep "\n" (
              map (
                dir:
                let
                  targetPath = dir.path;
                  prefix = dir.prefix;
                in
                ''
                  mkdir -p ${targetPath}
                  find ${targetPath}/ -maxdepth 1 -type l -exec rm -f {} \;
                  ${concatStringsSep "\n" (
                    map (
                      model:
                      let
                        modelPath = "${prefix}${model}";
                      in
                      "ln -sfn ${modelPath} ${targetPath}/\$(basename ${model.name})"
                    ) modelsForPath
                  )}
                ''
              ) dirs
            );
          generateAllLinks = concatStringsSep "\n" (
            mapAttrsToList generateLinksForPath config.services.comfyui.symlinkPaths
          );
        in
        ''
          ${generateAllLinks}
        '';
    };
  };
}
