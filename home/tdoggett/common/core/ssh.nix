{ ocConfig, configVars, ... }:
{
  programs.ssh = {
    enable = true;
    compression = true;
    addKeysToAgent = "yes";

    matchBlocks."github.com".user = "git";
    matchBlocks."gitlab.com".user = "git";
    matchBlocks."elrond".hostname = configVars.elrondIpAddress;
    matchBlocks."elrond".user = "root";
    matchBlocks."elrond".port = 2222;
    matchBlocks."exmormon.social".port = 2222;
    matchBlocks."steamdeck".hostname = "192.168.1.132"; # Local Network
    matchBlocks."steamdeck".user = "deck";
    matchBlocks."steamdeck".port = 9001;
  };
}
