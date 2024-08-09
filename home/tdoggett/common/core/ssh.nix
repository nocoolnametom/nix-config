{ ocConfig, ... }:
{
  programs.ssh = {
    enable = true;
    compression = true;
    addKeysToAgent = "yes";
  };
}
