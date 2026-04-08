{ ... }:
{
  # BAND-AID: This module works around intermittent DNS resolution failures on
  # long-running systems (particularly relevant for always-on downloaders that
  # frequently reconnect to Usenet servers). The underlying root cause has NOT
  # been identified or fixed. Forcing DNS-over-TLS to Cloudflare/Google here
  # prevents the failures but does not resolve whatever causes systemd-resolved
  # to lose its ability to resolve names after extended uptime.
  #
  # TODO: Investigate root cause (systemd-resolved state corruption? lease
  # expiry edge case? ISP DNS flakiness?) and replace this with a proper fix.
  networking.nameservers = [
    "1.1.1.1#one.one.one.one"
    "1.0.0.1#one.one.one.one"
    "8.8.8.8#eight.eight.eight.eight"
  ];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "true";
      Domains = [ "~." ];
      FallbackDNS = [
        "1.1.1.1#one.one.one.one"
        "1.0.0.1#one.one.one.one"
        "8.8.8.8#eight.eight.eight.eight"
      ];
      DNSOverTLS = "true";
    };
  };
}
