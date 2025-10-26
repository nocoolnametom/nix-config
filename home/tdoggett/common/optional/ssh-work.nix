{
  config,
  lib,
  configVars,
  ...
}:
{
  programs.ssh.forwardAgent = true;
  programs.ssh.hashKnownHosts = false;
  programs.ssh.serverAliveInterval = 0;
  programs.ssh.serverAliveCountMax = 3;
  programs.ssh.extraConfig = ''
    IdentityFile ${config.home.homeDirectory}/.ssh/id_yubikey
    IdentityFile ${config.home.homeDirectory}/.ssh/work_rsa
  '';
  programs.ssh.matchBlocks = {
    "*".addKeysToAgent = lib.mkForce "yes";
  }
  // configVars.work.sshMatchBlocks { inherit config; };
}
