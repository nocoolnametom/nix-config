{ lib, pkgs, ... }: {
  systemPackages = with pkgs; [
    quickemu
    quickgui
  ];
  services.spice-vdagentd.enable = lib.mkDefault true;
  virtualisation.spiceUSBRedirection.enable = lib.mkDefault true;
}
