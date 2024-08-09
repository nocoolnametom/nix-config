{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPortRanges = [
    {
      # KDE Connect
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPorts = [
    51820 # Wireguard
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
