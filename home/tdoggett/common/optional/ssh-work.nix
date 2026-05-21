{
  config,
  lib,
  configVars,
  ...
}:
{
  programs.ssh.extraConfig = ''
    IdentityFile ${config.home.homeDirectory}/.ssh/id_yubikey
    IdentityFile ${config.home.homeDirectory}/.ssh/work_rsa
  '';
  programs.ssh.settings = {
    "*".AddKeysToAgent = lib.mkForce "yes";
    "*".HashKnownHosts = false;
    "*".ServerAliveInterval = 0;
    "*".ServerAliveCountMax = 3;
    "*".ForwardAgent = true;
  }
  // configVars.work.sshSettings { inherit config; };
}
