# nixpkgs downgrade guard
#
# Refuses to activate a system built from an OLDER nixpkgs than the newest one this
# host has ever activated. Why: when a host follows the repo (comin) or auto-upgrades,
# a deploy of an older lock would downgrade services whose databases already migrated
# forward (the Immich problem). The check runs through `system.preSwitchChecks`, so it
# applies however the switch is started: comin, nixos-rebuild, or auto-upgrade.
#
# State, per tracked input, in /var/lib/nixpkgs-downgrade-guard/<input>.lastModified
# (persist this directory on impermanence hosts). It is raised by an activation script
# after the check passes. To deliberately go backwards once:
#   touch /var/lib/nixpkgs-downgrade-guard/allow-downgrade-once
# The next activation accepts the older input, records it as the new high-water mark,
# and removes the override file.
#
# Every tool is referenced by its store path: the pre-switch check inherits the PATH of
# whatever started the switch, and under comin's systemd unit that PATH has no coreutils
# (a bare `cat` broke feanor's deploy on 2026-11-06).
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.system.nixpkgsDowngradeGuard;
  stateDirectory = "/var/lib/nixpkgs-downgrade-guard";
  overrideFile = "${stateDirectory}/allow-downgrade-once";
  stampOf = inputName: toString inputs.${inputName}.lastModified;
  coreutils = "${pkgs.coreutils}/bin";
in
{
  options.system.nixpkgsDowngradeGuard = {
    enable = lib.mkEnableOption "refusing to activate a system built from an older nixpkgs than ever activated here";

    trackedInputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nixpkgs"
        "nixpkgs-unstable"
      ];
      description = ''
        Flake inputs whose `lastModified` must never go backwards. Each must be an input
        of the root flake (looked up as `inputs.<name>.lastModified`).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.preSwitchChecks.nixpkgsDowngradeGuard = ''
      # $1 is the new system's path, $2 the switch-to-configuration action.
      ${lib.concatMapStringsSep "\n" (inputName: ''
        newStamp=${stampOf inputName}
        stateFile="${stateDirectory}/${inputName}.lastModified"
        if [ -r "$stateFile" ]; then
          oldStamp=$(${coreutils}/cat "$stateFile")
          if [ "$newStamp" -lt "$oldStamp" ]; then
            if [ -e "${overrideFile}" ]; then
              echo "nixpkgs-downgrade-guard: '${inputName}' goes back from $oldStamp to $newStamp; allowed once by ${overrideFile}"
            else
              echo "nixpkgs-downgrade-guard: refusing to '$2' a system built from an OLDER '${inputName}'."
              echo "  newest '${inputName}' ever activated here (unix time): $oldStamp"
              echo "  '${inputName}' in this system:                        $newStamp"
              echo "  A downgrade can break services whose databases already migrated forward."
              echo "  If this is intended, run:  touch ${overrideFile}   and retry once."
              exit 1
            fi
          fi
        fi
      '') cfg.trackedInputs}
    '';

    # Raise the high-water marks once the check has passed. With the override present,
    # the older stamp becomes the new baseline so later switches to it need no override.
    system.activationScripts.nixpkgsDowngradeGuard = ''
      ${coreutils}/mkdir -p ${stateDirectory}
      ${coreutils}/chmod 700 ${stateDirectory}
      ${lib.concatMapStringsSep "\n" (inputName: ''
        newStamp=${stampOf inputName}
        stateFile="${stateDirectory}/${inputName}.lastModified"
        if [ ! -r "$stateFile" ] || [ -e "${overrideFile}" ] || [ "$newStamp" -gt "$(${coreutils}/cat "$stateFile")" ]; then
          echo "$newStamp" > "$stateFile"
        fi
      '') cfg.trackedInputs}
      ${coreutils}/rm -f ${overrideFile}
    '';
  };
}
