{
  config,
  lib,
  configVars,
  ...
}:
{
  programs.ssh.addKeysToAgent = lib.mkForce null;
  programs.ssh.forwardAgent = true;
  programs.ssh.hashKnownHosts = false;
  programs.ssh.serverAliveInterval = 0;
  programs.ssh.serverAliveCountMax = 3;
  programs.ssh.identityFile = [
    "${config.home.homeDirectory}/.ssh/id_yubikey"
    "${config.home.homeDirectory}/.ssh/work_rsa"
  ];
  programs.ssh.matchBlocks = configVars.work.sshMatchBlocks { inherit config; };
}
