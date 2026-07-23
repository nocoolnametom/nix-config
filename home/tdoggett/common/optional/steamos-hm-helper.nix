{ lib, config, pkgs, ... }:
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
  #
  # Note: the NixOS yubikey.nix module's udev rules (which auto-symlink
  # ~/.ssh/id_yubikey to the specific plugged-in key) are not available on
  # HM-only systems — udev rule installation requires system-level access.
  # On this machine id_yubikey is a static private key file, so hotplug
  # detection isn't needed. If you ever need the auto-symlink behaviour,
  # add udev rules outside of Home Manager (e.g. via a SteamOS pacman install
  # of yubikey-manager, then manually create /etc/udev/rules.d/99-yubikey.rules).
  skHelperWrapper = pkgs.writeShellScript "ssh-sk-helper-wrapper" ''
    exec env LD_LIBRARY_PATH="${pkgs.libfido2}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      /usr/lib/ssh/ssh-sk-helper "$@"
  '';
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
