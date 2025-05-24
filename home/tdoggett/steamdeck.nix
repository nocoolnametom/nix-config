{
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/only-hm.nix # Extra configs for systems ONLY using HM
    common/optional/sops.nix
    common/optional/git.nix
    common/optional/devenv.nix
    common/optional/desktops/brave.nix
    common/optional/desktops/kitty.nix
    common/optional/desktops/vscode.nix
    common/optional/wakatime.nix
  ];

  programs.git.userEmail = configVars.gitHubEmail;

  programs.bash.initExtra = ''
    PS1='(\u@\h \W)\$ '

    # Hack for the Qemu serial
    if [[ $(tty) == /dev/ttyS0 ]]
    then
      TERM=linux
      eval "$(resize)"
    fi

    ischroot() {
      local proc_root
      local root

      if ! proc_root="$(stat --printf "%d %i" /proc/1/root/ 2>/dev/null)" ||
        ! root="$(stat --printf "%d %i" / 2>/dev/null)"
      then
        return 1
      fi

      test "$proc_root" != "$root"
    }

    isremovable() {
      local devname
      local devpath
      local name

      if ! devname="$(realpath "$1")"
      then
        return 1
      fi

      if ! devpath="$(realpath "/sys/class/block/${"$"}{devname##*/}")"
      then
        return 1
      fi

      if ! test -e "$devpath/removable"
      then
        devpath="${"$"}{devpath%/*}"
      fi

      if ! test -e "$devpath/removable"
      then
        return 1
      fi

      if grep -q 0 "$devpath/removable"
      then
        return 1
      fi

      mapfile -t name < <(cat "$devpath/device/vendor" "$devpath/device/model" 2>/dev/null)
      name=("${"$"}{name[@]//  /}")
      name=("${"$"}{name[@]%% }")
      name=("${"$"}{name[@]## }")
      echo "${"$"}{name[@]}"
    }

    __steamos_ps1() {
      local read_only
      local partset
      local root
      local name
      local args
      local arg

      PS1="$1"

      # Check if user is root
      if [[ "$EUID" -ne 0 ]]
      then
        return
      fi

      # Set partition set to prompt
      read root partlabel < <(findmnt --noheading --output SOURCE,PARTLABEL /)
      if [[ "$root" ]]
      then
        # Set removable media name to prompt
        if name=$(isremovable "$root")
        then
          PS1="(\[\033[36;1m\]$name\[\033[0m\])$PS1"
        fi

        # Extract the color from the file os-release
        eval "$(. /etc/os-release; echo local ANSI_COLOR=\"$ANSI_COLOR\")"
        partset="${"$"}{partlabel#rootfs-}"
        if steamos-readonly status | grep -q "enabled"
        then
          read_only=1
        fi
        if [[ "$partset" ]] && [[ ! "$read_only" ]]
        then
          partset+="+"
        fi
        if [[ "$partset" ]]
        then
          PS1="(\[\033[${"$"}{ANSI_COLOR}m\]$partset\[\033[0m\])$PS1"
        fi
      fi
    }

    __steamos_prompt_command() {
      # Preserve return code
      local rc="$?"
      local ps1="$1"
      local partset

      # Set chroot to prompt
      if ischroot
      then
        partset="$(findmnt -no partlabel /)"
        partset="${"$"}{partset#rootfs-}"
        ps1="(\[\033[33;1m\]chroot[$partset]\[\033[0m\])$ps1"
      fi

      # Set return code to prompt
      if [[ "$rc" -ne 0 ]]
      then
        ps1="(\[\033[31;1m\]$rc\[\033[0m\])$ps1"
      fi

      # Set PS1
      PS1="$ps1"

      return "$rc"
    }

    __steamos_ps1 '(\[\033[1;32m\]\u@\h\[\033[1;34m\] \W\[\033[0m\])\$ '
    PROMPT_COMMAND="__steamos_prompt_command '$PS1'${"$"}{PROMPT_COMMAND:+; $PROMPT_COMMAND; }"
  '';

  services.yubikey-touch-detector.enable = true;

  home = {
    stateVersion = "25.05";
    username = lib.mkForce "deck";
    homeDirectory = lib.mkForce "/home/deck";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
