{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPortRanges = [
    {
      # KDE Connect
      from = 1714;
      to = 1764;
    }
    {
      # Immersed VR
      from = 21000;
      to = 21000;
    }
  ];
  networking.firewall.allowedUDPPorts = [
    51820 # WiregAuard
    21000 # Immersed VR 1
    21010 # Immersed VR 2
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      # KDE Connect
      from = 1714;
      to = 1764;
    }
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
