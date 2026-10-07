###############################################################################
#
#  Home Wi-Fi as a declarative NetworkManager profile
#
#  The network name and password come from nix-secrets and are filled in at
#  boot, so they never land in the Nix store. Because the profile comes from
#  config, it can't go stale: no hand-made duplicates ("Doggett-Home 1"), and
#  no profile pinned to an interface name that has since changed.
#
#  Profiles made by hand with nmcli are left alone. Delete any old copies of
#  this network, or NetworkManager may pick one of them instead.
#
###############################################################################

{
  config,
  configVars,
  lib,
  ...
}:
let
  cfg = config.networking.homeWifi;
  secretPrefix = "${configVars.username}/homeWifi/main";
in
{
  options.networking.homeWifi.band = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "a"
        "bg"
      ]
    );
    default = null;
    example = "a";
    description = ''
      Keep the connection on one band: "a" is 5 GHz, "bg" is 2.4 GHz. null
      lets the card pick any band, 6 GHz included. Useful when a card is
      unreliable on 6 GHz.
    '';
  };

  config = {
    sops.secrets."${secretPrefix}/name" = { };
    sops.secrets."${secretPrefix}/pass" = { };

    # systemd environment-file format; ensureProfiles substitutes $VARIABLES
    # into the profile from this file when it creates the connection
    sops.templates."home-wifi.env" = {
      content = ''
        HOME_WIFI_SSID="${config.sops.placeholder."${secretPrefix}/name"}"
        HOME_WIFI_PSK="${config.sops.placeholder."${secretPrefix}/pass"}"
      '';
      restartUnits = [ "NetworkManager-ensure-profiles.service" ];
    };

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.templates."home-wifi.env".path ];
      profiles.home-wifi = {
        connection = {
          id = "home-wifi";
          type = "wifi";
          autoconnect = true;
          # 0 = retry forever. The default gives up after 4 failed attempts,
          # which leaves a Wi-Fi-only machine offline until someone intervenes.
          autoconnect-retries = 0;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "$HOME_WIFI_SSID";
        }
        // lib.optionalAttrs (cfg.band != null) { inherit (cfg) band; };
        wifi-security = {
          # wpa-psk also allows WPA3 (SAE) when the card and access point both support it
          key-mgmt = "wpa-psk";
          psk = "$HOME_WIFI_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
