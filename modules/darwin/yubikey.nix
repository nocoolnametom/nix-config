{
  config,
  pkgs,
  lib,
  configVars,
  ...
}:
let
  homeDirectory = "/Users/${configVars.username}";
  yubikey-up =
    let
      yubikeyIds = lib.concatStringsSep " " (
        lib.mapAttrsToList (name: id: "[${name}]=\"${builtins.toString id}\"") config.yubikey.identifiers
      );
    in
    pkgs.writeShellApplication {
      name = "yubikey-up";
      runtimeInputs = builtins.attrValues { inherit (pkgs) gawk yubikey-manager; };
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        serial=$(ykman list | awk '{print $NF}')
        # If it got unplugged before we ran, run the down script to remove anything
        if [ -z "$serial" ]; then
          ${yubikey-down}/bin/yubikey-down
          exit 0
        fi

        declare -A serials=(${yubikeyIds})

        key_name=""
        for key in "''${!serials[@]}"; do
          if [[ $serial == "''${serials[$key]}" ]]; then
            key_name="$key"
          fi
        done

        if [ -z "$key_name" ]; then
          echo WARNING: Unidentified yubikey with serial "$serial" . Won\'t link an SSH key.
          exit 0
        fi

        echo "Creating links to ${homeDirectory}/id_$key_name"
        ln -sf "${homeDirectory}/.ssh/id_$key_name" ${homeDirectory}/.ssh/id_yubikey
        ln -sf "${homeDirectory}/.ssh/id_$key_name.pub" ${homeDirectory}/.ssh/id_yubikey.pub
      '';
    };
  yubikey-down = pkgs.writeShellApplication {
    name = "yubikey-down";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      rm ${homeDirectory}/.ssh/id_yubikey
      rm ${homeDirectory}/.ssh/id_yubikey.pub
    '';
  };
in
{
  options = {
    yubikey = {
      enable = lib.mkEnableOption "Enable yubikey support";
      identifiers = lib.mkOption {
        default = { };
        type = lib.types.attrsOf lib.types.int;
        description = "Attrset of Yubikey IDs";
        example = lib.literalExample ''
          {
            foo = 12345678;
            bar = 87654321;
          }
        '';
      };
    };
  };
  config = lib.mkIf config.yubikey.enable {
    environment.systemPackages = lib.flatten [
      (builtins.attrValues {
        inherit (pkgs)
          yubikey-manager # cli-based authenticator tool. accessed via `ykman`
          ;
      })
      yubikey-up
      yubikey-down
    ];

    launchd.user.agents.yubikey-up = {
      serviceConfig = {
        Label = "local.${configVars.username}.yubikey-up";
        StandardOutPath = "/tmp/yubikey-up.log";
        StandardErrorPath = "/tmp/yubikey-up.log";
        ProgramArguments = [
          "${pkgs.xpc_set_event_stream_handler}/bin/xpc_set_event_stream_handler"
          "${yubikey-up}/bin/yubikey-up"
        ];
        LaunchEvents."com.apple.iokit.matching" = {
          "com.apple.device-attach" = {
            IOProviderClass = "IOUSBDevice";
            idVendor = 4176;
            idProduct = "*";
            IOMatchLaunchStream = true;
            IOMatchStream = true;
          };
        };
      };
    };

    # MacOS will not tell us when a USB is removed, which SUCKS
    launchd.user.agents.yubikey-down = {
      serviceConfig = {
        Label = "local.${configVars.username}.yubikey-down";
        RunAtLoad = true;
        StandardOutPath = "/tmp/yubikey-down.log";
        StandardErrorPath = "/tmp/yubikey-down.log";
        ProgramArguments = [
          "${yubikey-up}/bin/yubikey-up"
        ];
        StartInterval = 300; # Every five minutes try to link the yubikey, which will remove if it fails
      };
    };

    # FIXME(yubikey): Check if this exists on darwin
    # services.yubikey-agent.enable = true;
  };
}
