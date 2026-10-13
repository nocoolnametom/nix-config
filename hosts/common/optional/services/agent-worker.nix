###############################################################################
#
#  agent-worker - a low-privilege Unix user for an AI coding agent's shell
#
#  The agent itself (a Hermes profile) runs as the normal user, because Hermes
#  Kanban spawns workers under the dispatcher's own uid. What gets confined is
#  where its tools run: the profile uses Hermes's SSH terminal backend pointed
#  at this user on loopback. Hermes runs terminal calls and its file tools
#  (read, write, patch, search are shell commands through the backend's
#  execute()) over that connection, so they happen as this user. So does
#  execute_code (Python on this side, file RPC back to Hermes). Tools that run
#  inside Hermes itself (web, browser, cron, memory) are outside this
#  confinement; the worker profile turns them off.
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
#   - reach the network, or any service on this machine: the firewall rejects
#     every connection it opens, loopback included, and lets through only its
#     replies on connections made to it (the SSH session the agent drives it
#     over). Loopback matters too: Caddy's admin API and Ollama listen there
#     without a login, so a worker allowed on lo could rewrite the web server
#     config or load and delete models. A rule in its instructions wasn't
#     enough: in an evaluation run it probed a real third-party mail server
#     to reproduce a bug. Nix still works: builds and substitution run in the nix daemon
#     (as nixbld users), and locked flake inputs are already in the store.
#     What breaks is anything that downloads as this user: `git fetch`,
#     `nix build nixpkgs#...` (registry lookup) and new, uncached inputs.
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
        # Hermes's execute_code runs Python on the remote side of its SSH
        # backend, and refuses ("Python 3 is not available in the ssh terminal
        # environment") when the worker has none.
        python3
      ];
      defaultText = lib.literalExpression "with pkgs; [ git opencode ripgrep jq nixfmt python3 ]";
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

    # Replies only (see the header). sshd's per-session process runs as the
    # worker, so the SSH session's own packets carry its uid; they belong to
    # a connection someone else opened, hence ESTABLISHED. Its own chain, so
    # a firewall reload replaces the rules instead of stacking copies. ip46tables is defined
    # by the NixOS firewall script and applies each rule to IPv4 and IPv6.
    assertions = [
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "services.agent-worker blocks the worker's network with iptables rules; it needs networking.firewall with the iptables backend.";
      }
    ];
    networking.firewall.extraCommands = ''
      ip46tables -N agent-worker-out 2>/dev/null || ip46tables -F agent-worker-out
      ip46tables -A agent-worker-out -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
      ip46tables -A agent-worker-out -j REJECT
      ip46tables -D OUTPUT -m owner --uid-owner ${cfg.user} -j agent-worker-out 2>/dev/null || true
      ip46tables -I OUTPUT -m owner --uid-owner ${cfg.user} -j agent-worker-out
    '';
    networking.firewall.extraStopCommands = ''
      ip46tables -D OUTPUT -m owner --uid-owner ${cfg.user} -j agent-worker-out 2>/dev/null || true
      ip46tables -F agent-worker-out 2>/dev/null || true
      ip46tables -X agent-worker-out 2>/dev/null || true
    '';
  };
}
