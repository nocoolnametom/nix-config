{ lib, pkgs, ... }:
{
  # SANE - Scanner Access Now Easy
  # Provides hardware support for USB and network document scanners
  # Supports HP OfficeJet and other modern all-in-one printers via AirScan/eSCL
  hardware.sane = {
    enable = true;
    extraBackends = [
      pkgs.samsung-unified-linux-driver
      pkgs.hplipWithPlugin # HP scanners/printers (OfficeJet, etc.)
      pkgs.sane-airscan # Network/wireless scanner support (AirScan/eSCL)
    ];
  };

  services.udev.packages = [ pkgs.sane-airscan ];
  services.ipp-usb.enable = true; # IPP-over-USB for modern printers

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      simple-scan # GUI scanning application (like Windows Scan)
      sane-frontends # Command-line scanning tools
      ;
  };

  # If your scanner is networked, you might need to open a port
  # networking.firewall.allowedTCPPorts = [ 9100 ];
}
