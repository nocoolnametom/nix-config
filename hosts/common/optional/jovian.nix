{
  inputs,
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
{
  imports = [
    inputs.jovian.nixosModules.default
  ];

  jovian.steam.enable = lib.mkDefault true;
  jovian.steam.autoStart = lib.mkDefault true;
  jovian.steam.user = lib.mkDefault configVars.username;

  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";

  jovian.steam.environment =
    { }
    // (lib.attrsets.optionalAttrs
      (
        (lib.attrsets.hasAttrByPath [ "services" "wivrn" "enable" ] config)
        && (config.services.wivrn.enable)
      )
      {
        PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
      }
    );

  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = false;
  jovian.steam.desktopSession = "plasma";
}
