# smolcoder persistent web UI service
#
# Listens on 127.0.0.1 only; access from other machines via SSH tunnel:
#   ssh -N -L <port>:127.0.0.1:<port> barliman
# The auth URL (with ?k= token) changes every restart; retrieve it with:
#   smolcoder-url
{
  pkgs,
  configVars,
  ...
}:
{
  systemd.user.services.smolcoder-web = {
    Unit = {
      Description = "smolcoder web UI (local LLM coding agent)";
      After = [ "default.target" ];
    };
    Service = {
      # qwen3-coder:30b-a3b: MoE 30B/3.3B-active, tools+thinking, ~19.7GB Q4_K_M.
      # 32K context leaves headroom alongside model weights in 32GB unified memory.
      ExecStart = "${pkgs.smolcoder}/bin/smolcoder --web ${toString configVars.networking.ports.tcp.smolcoder} --model qwen3-coder:30b-a3b --ctx 32768 --mode edit";
      WorkingDirectory = "%h";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Quick alias to find the current URL+auth-token from the service journal
  home.shellAliases.smolcoder-url =
    "journalctl --user -u smolcoder-web --no-pager | grep 'smolcoder web UI' | tail -1 | grep -oP 'http://\\S+'";
}
