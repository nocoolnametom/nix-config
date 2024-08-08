{ pkgs, ... }:
{
  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.gutenprintBin
    pkgs.hplip
  ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.openFirewall = true; # for a WiFi printer
}
