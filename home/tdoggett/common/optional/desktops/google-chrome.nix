{ lib, ... }:
{
  programs.google-chrome.enable = lib.mkDefault true;
}
