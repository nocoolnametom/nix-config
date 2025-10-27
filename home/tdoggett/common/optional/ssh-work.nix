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
  programs.ssh.matchBlocks = {
    "*".addKeysToAgent = lib.mkForce "yes";
    "*".hashKnownHosts = false;
    "*".serverAliveInterval = 0;
    "*".serverAliveCountMax = 3;
    "*".forwardAgent = true;
  }
  // configVars.work.sshMatchBlocks { inherit config; };
}
