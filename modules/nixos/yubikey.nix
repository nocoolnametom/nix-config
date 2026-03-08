{
  config,
  pkgs,
  lib,
  configVars,
  ...
}:
let
  homeDirectory =
    if pkgs.stdenv.isLinux then "/home/${configVars.username}" else "/Users/${configVars.username}";
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
        # If it got unplugged before we ran, just don't bother
        if [ -z "$serial" ]; then
          # FIXME: Warn probably
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
      autoScreenLock = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Lock screen when YubiKey is removed (Linux only)";
      };
    };
  };
  config = lib.mkIf config.yubikey.enable {
    environment.systemPackages = lib.flatten [
      (builtins.attrValues {
        inherit (pkgs)
          yubioath-flutter # gui-based authenticator tool. yubioath-desktop on older nixpkg channels
          yubikey-manager # cli-based authenticator tool. accessed via `ykman`

          pam_u2f # for yubikey with sudo
          ;
      })
      yubikey-up
      yubikey-down
    ];

    # FIXME(yubikey): Put this behind an option for yubikey ssh
    # Create ssh files

    # FIXME(yubikey): Not sure if we need the wheel one. Also my idProduct gruop is 0407
    # Yubikey 4/5 U2F+CCID
    # SUBSYSTEM == "usb", ATTR{idVendor}=="1050", ENV{ID_SECURITY_TOKEN}="1", GROUP="wheel"
    # We already have a yubikey rule that sets the ENV variable

    # FIXME(yubikey): This is linux only
    services.udev.extraRules = ''
      # Link/unlink ssh key on yubikey add/remove
      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="1050", RUN+="${lib.getBin yubikey-up}/bin/yubikey-up"
      # NOTE: Yubikey 4 has a ID_VENDOR_ID on remove, but not Yubikey 5 BIO, whereas both have a HID_NAME.
      # Yubikey 5 HID_NAME uses "YubiKey" whereas Yubikey 4 uses "Yubikey", so matching on "Yubi" works for both
      SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${lib.getBin yubikey-down}/bin/yubikey-down"
    ''
    + lib.optionalString config.yubikey.autoScreenLock ''
      # Lock screen when YubiKey is removed
      # Works with any desktop environment that respects systemd session management (GNOME, KDE, COSMIC, etc.)
      SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
    '';

    # Yubikey required services and config. See Dr. Duh NixOS config for
    # reference
    services.pcscd.enable = true; # smartcard service
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # FIXME(yubikey): Check if this exists on darwin
    # Disabled: Using gpg-agent for SSH instead, which also supports Yubikey
    # services.yubikey-agent.enable = true;

    # yubikey login / sudo
    security.pam = lib.optionalAttrs pkgs.stdenv.isLinux {
      sshAgentAuth.enable = true;
      u2f = {
        enable = true;
        settings = {
          cue = true; # Tells user they need to press the button
          authFile = "${homeDirectory}/.config/Yubico/u2f_keys";
        };
      };
      services = {
        login.u2fAuth = true;
        sudo = {
          u2fAuth = true;
          sshAgentAuth = true; # Use SSH_AUTH_SOCK for sudo
        };
        # Attempt to auto-unlock gnome-keyring using u2f
        # NOTE: vscode uses gnome-keyring even if we aren't using gnome, which is why it's still here
        # This doesn't work
        #gnome-keyring = {
        #  text = ''
        #    session    include                     login
        #    session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
        #  '';
        #};
      };
    };
  };
}
