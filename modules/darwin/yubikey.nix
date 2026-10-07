{
  config,
  pkgs,
  lib,
  configVars,
  ...
}:
let
  homeDirectory = "/Users/${configVars.username}";
  agentSocket = "${homeDirectory}/.ssh/sockets/ssh-agent.sock";
  # Use stable to avoid rebuilding this package every time and try to keep it from failing on rebuilds
  xpc_set_event_stream_handler = pkgs.stable.callPackage ./pkgs/xpc_set_event_stream_handler {
    inherit lib;
    inherit (pkgs.stable) stdenv makeWrapper;
    pkgs = pkgs.stable;
  };
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
      agent-package = lib.mkOption {
        default = pkgs.yubikey-agent;
        defaultText = "pkgs.yubikey-agent";
        description = "Which yubikey-agent derivation to use";
        type = lib.types.package;
      };
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
        description = "Lock screen when YubiKey is removed (not supported on macOS, option exists for compatibility)";
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
      config.yubikey.agent-package
      yubikey-up
      yubikey-down
    ];

    launchd.user.agents.yubikey-up = {
      serviceConfig = {
        Label = "local.${configVars.username}.yubikey-up";
        StandardOutPath = "/tmp/yubikey-up.log";
        StandardErrorPath = "/tmp/yubikey-up.log";
        ProgramArguments = [
          "${xpc_set_event_stream_handler}/bin/xpc_set_event_stream_handler"
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

    # Disable the built-in ssh-agent service
    services.openssh.enable = false;
    system.activationScripts.disableSystemSshAgent.text = ''
      sudo -u ${configVars.username} sh -c 'launchctl disable user/$UID/com.openssh.ssh-agent'
    '';

    # Install openssh via brew
    homebrew.taps = [ { name = "theseal/ssh-askpass"; } ];
    homebrew.brews = [
      "openssh"
      "pinentry-mac"
      "theseal/ssh-askpass/ssh-askpass"
    ];

    # Use brew's openssh for ssh-agent, bound to a stable known path
    launchd.user.agents.ssh-agent = {
      serviceConfig = {
        Label = "com.homebrew.ssh-agent";
        EnvironmentVariables.SSH_ASKPASS = "${config.homebrew.prefix}/bin/ssh-askpass";
        EnvironmentVariables.DISPLAY = ":0";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "mkdir -p $(dirname ${agentSocket}); rm -f ${agentSocket}; exec ${config.homebrew.prefix}/bin/ssh-agent -D -a ${agentSocket}"
        ];
        RunAtLoad = true;
      };
    };

    # homebrew.onActivation.upgrade can replace brew's openssh during a
    # rebuild, but the agent's launchd plist doesn't change, so launchd keeps
    # the old agent running. That agent then can't use the YubiKey ("agent
    # refused operation"): FIDO keys go through ssh-sk-helper, which it looks
    # for in the old version's Cellar directory, now deleted. Restart the agent
    # when its program is no longer the installed one. Keys come back on next
    # use (AddKeysToAgent). postActivation runs after the homebrew step.
    system.activationScripts.postActivation.text = ''
      ssh_agent_uid=$(/usr/bin/id -u ${configVars.username})
      ssh_agent_label="gui/$ssh_agent_uid/com.homebrew.ssh-agent"
      ssh_agent_pid=$(/bin/launchctl print "$ssh_agent_label" 2>/dev/null | /usr/bin/awk '$1 == "pid" { print $3; exit }' || true)
      if [ -n "$ssh_agent_pid" ]; then
        ssh_agent_running=$(/usr/sbin/lsof -a -p "$ssh_agent_pid" -d txt -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/grep '/bin/ssh-agent$' | /usr/bin/head -n 1 || true)
        ssh_agent_installed=$(/bin/realpath ${config.homebrew.prefix}/bin/ssh-agent 2>/dev/null || true)
        if [ -n "$ssh_agent_installed" ] && [ "$ssh_agent_running" != "$ssh_agent_installed" ]; then
          echo "restarting ssh-agent (running: ''${ssh_agent_running:-unknown}, installed: $ssh_agent_installed)..." >&2
          /bin/launchctl kickstart -k "$ssh_agent_label" || true
        fi
      fi
    '';

    environment.variables.SSH_ASKPASS = "${config.homebrew.prefix}/bin/ssh-askpass";
    environment.variables.DISPLAY = ":0";
  };
}
