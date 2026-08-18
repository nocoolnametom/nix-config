{ lib, pkgs, ... }: {
  environment.systemPackages = [
    pkgs.quickemu
    pkgs.quickgui
  ];
  services.spice-vdagentd.enable = lib.mkDefault true;
  virtualisation.spiceUSBRedirection.enable = lib.mkDefault true;
}
