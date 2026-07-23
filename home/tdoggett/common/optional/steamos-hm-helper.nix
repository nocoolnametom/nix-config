{ lib, config, pkgs, configVars, ... }:
let
  # Collect any steam-related packages that snuck into home.packages.
  # Matches against pname/name (case-insensitive) so it catches packages
  # from any nixpkgs input or overlay, not just the canonical `pkgs.steam`.
  steamPkgs = builtins.filter
    (p:
      let name = lib.toLower (if builtins.isAttrs p then p.pname or p.name or "" else "");
      in builtins.match ".*steam.*" name != null
    )
    config.home.packages;

  # SteamOS doesn't ship libfido2, so /usr/lib/ssh/ssh-sk-helper fails with:
  #   cannot open shared object file: libfido2.so.1
  # This wrapper pre-loads nix's libfido2 into the helper's environment.
  # LD_LIBRARY_PATH is scoped to ssh-sk-helper's process only (via exec env),
  # so it cannot leak to Steam or any other GUI process.
  skHelperWrapper = pkgs.writeShellScript "ssh-sk-helper-wrapper" ''
    exec env LD_LIBRARY_PATH="${pkgs.libfido2}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      /usr/lib/ssh/ssh-sk-helper "$@"
  '';

  # When SSH_AUTH_SOCK is set, ssh-keygen -Y sign (used by git for SSH signing)
  # attempts to sign via the SSH agent BEFORE falling through to the sk-helper.
  # The system SSH agent cannot handle SK/FIDO2 keys and returns
  # "agent refused operation", blocking the signing entirely.
  # Unsetting SSH_AUTH_SOCK forces the direct sk-helper code path, which is
  # what actually communicates with the YubiKey via libfido2.
  gitSshSignWrapper = pkgs.writeShellScript "steamos-git-ssh-sign" ''
    unset SSH_AUTH_SOCK
    export SSH_SK_HELPER="${skHelperWrapper}"
    exec /usr/bin/ssh-keygen "$@"
  '';

  # Build a bash associative-array literal from the shared serial → key-name map.
  # Produces: ([yklappy]="22373686" [ykmbp]="22373683" ...)
  # Same data as configVars.yubikey.identifiers used by modules/nixos/yubikey.nix.
  serialMapBash = lib.concatStringsSep " "
    (lib.mapAttrsToList
      (name: serial: "[${name}]=\"${toString serial}\"")
      configVars.yubikey.identifiers);

  # Userspace equivalent of the udev rules in modules/nixos/yubikey.nix.
  # On SteamOS, /etc/udev/rules.d/ is wiped by every A/B OS upgrade, so we
  # monitor udev events as a systemd user service instead — no root access and
  # no system files required.  The service:
  #   • runs udevadm monitor (system binary, no nix dep needed)
  #   • on USB add with Yubico vendor 1050 → calls ykman, matches serial,
  #     creates ~/.ssh/id_yubikey → ~/.ssh/id_<keyname> symlink
  #   • on HID remove with name matching "Yubi*" → removes the symlink
  #   • does an initial sync at startup so a pre-plugged key is handled
  yubikeyMonitor = pkgs.writeShellApplication {
    name = "steamos-yubikey-monitor";
    # yubikey-manager provides ykman; gawk for the serial extraction.
    # udevadm comes from the system (/usr/bin/udevadm) — not nix dep.
    runtimeInputs = with pkgs; [ yubikey-manager gawk ];
    text = ''
      SSH_DIR="${config.home.homeDirectory}/.ssh"

      declare -A SERIALS=(${serialMapBash})

      fallback_link() {
        ln -sf "$SSH_DIR/id_personal"          "$SSH_DIR/id_yubikey"
        ln -sf "$SSH_DIR/personal_ed25519.pub" "$SSH_DIR/id_yubikey.pub"
        echo "steamos-yubikey-monitor: no YubiKey — id_yubikey → id_personal (fallback)" >&2
      }

      update_link() {
        local serial key_name="" key
        serial=$(ykman list 2>/dev/null | awk '{print $NF}' | head -1)

        if [[ -z "$serial" ]]; then
          fallback_link
          return
        fi

        for key in "''${!SERIALS[@]}"; do
          if [[ "$serial" == "''${SERIALS[$key]}" ]]; then
            key_name="$key"
            break
          fi
        done

        if [[ -z "$key_name" ]]; then
          echo "steamos-yubikey-monitor: unknown serial $serial, not linking" >&2
          return
        fi

        ln -sf "$SSH_DIR/id_$key_name"     "$SSH_DIR/id_yubikey"
        ln -sf "$SSH_DIR/id_$key_name.pub" "$SSH_DIR/id_yubikey.pub"
        echo "steamos-yubikey-monitor: linked id_yubikey → id_$key_name ($serial)" >&2
      }

      # Sync once at startup in case a key is already plugged in.
      update_link

      # Parse udev event property blocks (blank-line-separated).
      # USB subsystem: detect add events for Yubico (vendor 1050).
      # HID subsystem: detect remove events by HID_NAME pattern.
      action="" subsystem="" vendor_id="" hid_name=""

      while IFS= read -r line; do
        if [[ -z "$line" ]]; then
          if [[ "$action" == "add" && "$subsystem" == "usb" && "$vendor_id" == "1050" ]]; then
            sleep 1   # give the device time to fully initialise
            update_link
          elif [[ "$action" == "remove" && "$subsystem" == "hid" && "$hid_name" == *Yubi* ]]; then
            fallback_link
          fi
          action="" subsystem="" vendor_id="" hid_name=""
        elif [[ "$line" == ACTION=* ]];       then action="''${line#ACTION=}"
        elif [[ "$line" == SUBSYSTEM=* ]];    then subsystem="''${line#SUBSYSTEM=}"
        elif [[ "$line" == ID_VENDOR_ID=* ]]; then vendor_id="''${line#ID_VENDOR_ID=}"
        elif [[ "$line" == HID_NAME=* ]];     then hid_name="''${line#HID_NAME=}"
        fi
      done < <(/usr/bin/udevadm monitor --udev --property \
                  --subsystem-match=usb --subsystem-match=hid)
    '';
  };
in
{
  # On SteamOS, Steam is a core OS component managed by Valve's system image.
  # A Nix-installed Steam would shadow or conflict with it, breaking Game Mode,
  # system updates, and hardware integration. Catch this at evaluation time so
  # the error is clear rather than a mysterious runtime failure.
  assertions = [
    {
      assertion = steamPkgs == [ ];
      message = ''
        steamos-hm-helper: Steam-related packages found in home.packages — not allowed on SteamOS.

          Offending package(s): ${lib.concatMapStringsSep ", " (p: p.pname or p.name or "(unknown)") steamPkgs}

          On SteamOS, Steam is managed by Valve's system image, not by Nix.
          Installing it via Nix would shadow the system Steam, breaking Game Mode,
          OS updates, and hardware-level integration (controller firmware, etc.).

          Remove all steam-* packages from home.packages and any imported module
          that adds them.
      '';
    }
  ];

  # Point ssh-keygen (and ssh-add) at the libfido2-aware wrapper so ED25519-SK
  # commit signing works. SSH_SK_HELPER is checked before the compiled-in default
  # path, so this works whether the system or nix ssh-keygen is invoked.
  home.sessionVariables.SSH_SK_HELPER = "${skHelperWrapper}";

  # When SSH_AUTH_SOCK is set, ssh-keygen -Y sign (used by git commit signing)
  # tries the SSH agent BEFORE the sk-helper. The system SSH agent cannot handle
  # SK/FIDO2 keys and returns "agent refused operation", blocking signing entirely.
  # This wrapper overrides the signer program to unset SSH_AUTH_SOCK first,
  # forcing the direct sk-helper path that actually communicates with the YubiKey.
  programs.git.settings."gpg.ssh".program = "${gitSshSignWrapper}";

  # YubiKey SSH symlink manager — userspace replacement for the udev rules in
  # modules/nixos/yubikey.nix that don't survive SteamOS A/B partition upgrades.
  systemd.user.services.steamos-yubikey-monitor = {
    Unit = {
      Description = "YubiKey SSH key symlink manager (userspace udev monitor)";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${yubikeyMonitor}/bin/steamos-yubikey-monitor";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # On SteamOS Desktop Mode (KDE), /etc/profile.d/nix-daemon.sh runs during session
  # startup and prepends ~/.nix-profile/bin before /usr/bin. Steam's runtime then sets
  # LD_LIBRARY_PATH to system library paths, which overrides nix binaries' RUNPATH.
  # Nix packages (e.g. coreutils 9.11) are built against glibc 2.42, but SteamOS ships
  # glibc 2.41, so any nix binary Steam's scripts invoke crashes with:
  #   dirname: /usr/lib/libc.so.6: version `GLIBC_2.42' not found
  # This kills steamwebhelper in a restart loop.
  #
  # KDE Plasma sources ~/.config/plasma-workspace/env/*.sh after the profile.d scripts.
  # We use this hook to move system paths to the front for GUI/Steam sessions.
  # Login-shell terminals (kitty, etc.) are unaffected: they re-source login files
  # on launch and get nix paths prepended again as expected.
  home.file.".config/plasma-workspace/env/steamos-path.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Reorder PATH so system tools come before nix profile bins.
      # System paths first prevents Steam from picking up nix binaries that require
      # a newer glibc than SteamOS provides.
      _sys="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin"
      _new="$_sys"
      _ifs_save="$IFS"
      IFS=":"
      for _d in $PATH; do
        case ":$_new:" in
          *":$_d:"*) ;;
          *) _new="$_new:$_d" ;;
        esac
      done
      IFS="$_ifs_save"
      export PATH="$_new"
      unset _sys _new _d _ifs_save
    '';
  };
}
