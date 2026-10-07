###############################################################################
#
#  Wi-Fi watchdog for NetworkManager machines that live on Wi-Fi alone
#
#  NetworkManager gives up on autoconnect after a few failed attempts, and some
#  drivers (MediaTek mt7925e in particular) can wedge the card so that no
#  amount of retrying helps until the driver is reloaded. A headless box with
#  no Ethernet then stays offline until someone walks over with a keyboard.
#
#  Every minute this pings the default gateway. After a few misses in a row it
#  asks NetworkManager to reconnect; after more misses it reloads the driver.
#  It also turns off Wi-Fi power saving, which is a common cause of the drops.
#  Optionally it sets the Wi-Fi country code (see regulatoryDomain below).
#
###############################################################################

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.networking.wifiWatchdog;

  watchdogScript = pkgs.writeShellApplication {
    name = "wifi-watchdog";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      iproute2
      iputils
      kmod
      networkmanager
    ];
    text = ''
      state_dir=/run/wifi-watchdog
      failure_file="$state_dir/failures"
      mkdir -p "$state_dir"
      failures=$(cat "$failure_file" 2>/dev/null || echo 0)

      wifi_device=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" { print $1; exit }')
      gateway=$(ip -4 route show default | awk '{ print $3; exit }')

      if [ -n "$gateway" ] && ping -c 3 -W 2 "$gateway" > /dev/null 2>&1; then
        if [ "$failures" -gt 0 ]; then
          echo "Gateway $gateway reachable again after $failures failed checks"
        fi
        echo 0 > "$failure_file"
        exit 0
      fi

      failures=$((failures + 1))
      echo "$failures" > "$failure_file"
      echo "Check $failures failed (wifi device: ''${wifi_device:-none}, gateway: ''${gateway:-none})"

      # driver_module is empty when no driver reload is configured
      driver_module="${cfg.driverModule}"
      if [ "$failures" -ge ${toString cfg.driverReloadAfter} ] && [ -n "$driver_module" ]; then
        echo "Reloading driver $driver_module"
        modprobe -r "$driver_module" || true
        sleep 2
        modprobe "$driver_module"
        # Start the count over so the next reload waits another full cycle
        echo 0 > "$failure_file"
      elif [ "$failures" -ge ${toString cfg.reconnectAfter} ]; then
        if [ -z "$wifi_device" ]; then
          echo "No wifi device present; waiting for driver reload"
          exit 0
        fi
        echo "Asking NetworkManager to reconnect $wifi_device"
        nmcli radio wifi on || true
        nmcli device wifi rescan ifname "$wifi_device" || true
        sleep 5
        # An explicit "connect" also clears NetworkManager's autoconnect block,
        # which otherwise stays in place after its retries run out
        # A slow login can take most of a minute; a shorter wait reports
        # failure for attempts that go on to succeed
        nmcli --wait 60 device connect "$wifi_device" || true
      fi
    '';
  };
in
{
  options.networking.wifiWatchdog = {
    driverModule = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "mt7925e";
      description = ''
        Kernel module of the Wi-Fi card, reloaded when reconnecting does not
        help. Empty means never reload. Find it with
        `readlink /sys/class/net/<wifi interface>/device/driver/module`.
      '';
    };

    disableDriverAspm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Pass disable_aspm=1 to driverModule. Turns off PCIe link power saving
        for the card, which stops the mt7921e/mt7925e cards from dropping off
        the bus. Only set this for drivers that have that parameter
        (check with `modinfo -p <module>`).
      '';
    };

    regulatoryDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "US";
      description = ''
        Two-letter country code for Wi-Fi rules. Without it the kernel uses
        the "world" domain (00), which forbids 6 GHz. Then the card keeps
        roaming to the router's 6 GHz access points, fails, and resets its
        firmware, over and over.
      '';
    };

    reconnectAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Failed one-minute checks in a row before asking NetworkManager to reconnect.";
    };

    driverReloadAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "Failed one-minute checks in a row before reloading driverModule.";
    };
  };

  config = {
    assertions = [
      {
        assertion = config.networking.networkmanager.enable;
        message = "wifi-watchdog.nix expects NetworkManager to manage Wi-Fi";
      }
    ];

    # Power saving on the radio is a frequent cause of drops, and these are
    # plugged-in machines with nothing to gain from it
    networking.networkmanager.wifi.powersave = false;

    boot.extraModprobeConfig = lib.mkMerge [
      (lib.mkIf (cfg.disableDriverAspm && cfg.driverModule != "") ''
        options ${cfg.driverModule} disable_aspm=1
      '')
      (lib.mkIf (cfg.regulatoryDomain != null) ''
        options cfg80211 ieee80211_regdom=${cfg.regulatoryDomain}
      '')
    ];

    # The kernel needs the regulatory database to apply a country code
    hardware.wirelessRegulatoryDatabase = lib.mkIf (cfg.regulatoryDomain != null) true;

    systemd.services.wifi-watchdog = {
      description = "Reconnect Wi-Fi when the gateway stops answering";
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe watchdogScript;
        # A reconnect run can take ~75s (ping + rescan + 60s wait); the 90s
        # default would kill it partway through on a bad day
        TimeoutStartSec = "3min";
      };
    };

    systemd.timers.wifi-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Give NetworkManager time to bring the link up after boot
        OnBootSec = "3min";
        OnUnitActiveSec = "1min";
        AccuracySec = "10s";
      };
    };
  };
}
