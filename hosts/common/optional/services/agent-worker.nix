###############################################################################
#
#  agent-worker - a low-privilege Unix user for an AI coding agent's shell
#
#  The agent itself (a Hermes profile) runs as the normal user, because Hermes
#  Kanban spawns workers under the dispatcher's own uid. What gets confined is
#  where its tools run: the profile uses Hermes's SSH terminal backend pointed
#  at this user on loopback. Hermes runs terminal calls and its file tools
#  (read, write, patch, search are shell commands through the backend's
#  execute()) over that connection, so they happen as this user.
#  execute_code has not been checked yet: verify it on the first live run.
#
#  What this user can NOT do, by construction rather than by instruction:
#   - read the normal user's home (~/.ssh, ~/.hermes, repos): those are 0700
#   - read group-shared data: it is in no extra groups (not wheel = no sudo,
#     not users, not docker = not root via the socket)
#   - decrypt secrets: it holds no sops/age key
#   - push to GitHub: it is given no credentials there (it clones the public
#     repo over https)
#   - log in from anywhere but this machine: sshd only accepts it from
#     loopback, and its authorized keys carry from="127.0.0.1,::1"
#
#  What it CAN do: build with Nix (allowed-users, not trusted-users), edit
#  and `git add` in its own clone, and later reach test targets with an SSH
#  key it alone holds. Whatever can run `nixos-rebuild test` on a target is
#  root on that target, so the list of test targets is the real blast radius.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agent-worker;

  # Login from this machine only, and nothing tunnelled through it.
  keyOptions = ''from="127.0.0.1,::1",no-agent-forwarding,no-port-forwarding,no-X11-forwarding'';
in
{
  options.services.agent-worker = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the low-privilege user that AI coding agents run their shells as.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "agent-worker";
      description = "Name of the user, and of its own group.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/agent-worker";
      description = ''
        Home directory: holds the repo clones and the worker's own SSH keys.
        Persist it on impermanence hosts.
      '';
    };

    dispatcherKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        SSH public keys allowed to log in as the worker (from loopback only):
        the key the agent's SSH terminal backend uses. With none, nobody can
        log in as the worker.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        git
        opencode
        ripgrep
        jq
        nixfmt
      ];
      defaultText = lib.literalExpression "with pkgs; [ git opencode ripgrep jq nixfmt ]";
      description = "Tools on the worker's PATH. nix and nixos-rebuild come from the system.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = { };
    users.users.${cfg.user} = {
      # Normal user: SSH login needs a real shell. Deliberately no
      # extraGroups - see the header.
      isNormalUser = true;
      group = cfg.user;
      home = cfg.home;
      createHome = true;
      homeMode = "700";
      packages = cfg.packages;
      openssh.authorizedKeys.keys = map (key: "${keyOptions} ${key}") cfg.dispatcherKeys;
    };

    # openssh.nix sets AllowGroups with lib.mkDefault [ "wheel" ]. A plain
    # definition here would REPLACE that list and lock every wheel user out;
    # defining it at the same mkDefault priority makes the two lists merge.
    # AllowUsers has no such default, so a plain list merges normally.
    services.openssh.settings.AllowGroups = lib.mkDefault [ cfg.user ];
    services.openssh.settings.AllowUsers = [
      "${cfg.user}@127.0.0.1"
      "${cfg.user}@::1"
    ];

    # Use the Nix daemon (builds, evaluation) without being trusted: a
    # trusted user can change substituters and settings, which is root.
    nix.settings.allowed-users = [ cfg.user ];
  };
}
