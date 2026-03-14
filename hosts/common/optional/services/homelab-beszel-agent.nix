{
  lib,
  config,
  configVars,
  ...
}:

{
  # Homelab Beszel monitoring agent - connects to hub on estel
  # Lightweight alternative to Netdata for clean, focused system monitoring
  # Namespaced as "homelab-" to avoid conflicts with future official nixpkgs module

  services.homelab-beszel-agent = {
    enable = true;
    hubUrl = "http://${configVars.networking.subnets.estel.ip}:8090";
  };
}
