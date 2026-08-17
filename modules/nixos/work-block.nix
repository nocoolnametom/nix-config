# Work Block Module
#
# Automatically blocks distracting services during work hours by:
# - Stopping specified services (stash, invokeai, comfyui, etc.)
# - Serving placeholder HTTP pages on their ports using a lightweight Python server
# - Auto-restarting services when work-block is stopped or outside work hours
# - Respecting configured holidays (no blocking on vacation days)
#
# Design overview:
#   The persistent state file /var/lib/work-block/blocked-until holds an ISO
#   timestamp describing when the current work-block session ends. Its presence
#   with a future timestamp is the single source of truth for "work-block should
#   be active right now."
#
#     work-block-start.timer  -> work-block-start.service
#       On workDays at startTime, unless today is a holiday: write blocked-until
#       (= today at endTime) and start work-block.service.
#
#     work-block-stop.timer   -> work-block-stop.service
#       On workDays at endTime: delete blocked-until and stop work-block.service.
#       (Stopping the service triggers ExecStopPost, which restarts blocked services.)
#
#     work-block-check.service (run at boot and after the override timer elapses)
#       If blocked-until exists and is in the future and today is not a holiday,
#       start work-block.service. Otherwise clear stale state.
#
#     work-block-override.service  (triggered by HTTP request on the listener port)
#       Stop work-block.service (blocked services restart via ExecStopPost).
#       Restart the one-hour work-block-check.timer, resetting its countdown from
#       "now". After that hour, work-block-check re-evaluates and restarts
#       work-block if the day's session is still active.
#
# Manual controls:
#   Force a fresh block session for today:
#     sudo systemctl start work-block-start.service
#
#   End today's block session immediately (until the next work day):
#     sudo systemctl start work-block-stop.service
#
#   Trigger the one-hour override manually:
#     sudo systemctl start work-block-override.service
#     # or: curl http://localhost:<port>/
{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:

with lib;

let
  cfg = config.services.work-block;

  stateDir = "/var/lib/work-block";
  stateFile = "${stateDir}/blocked-until";

  # Complete registry of all available services with their friendly names
  # Each entry maps a friendly name to one or more systemd services
  serviceRegistry = {
    stash = {
      services = [
        {
          name = "stash";
          enabled = config.services.stash.enable or false;
          port = config.services.stash.settings.port or null;
        }
      ];
    };

    stashvr = {
      services =
        let
          vrHelperEnabled = config.services.stash.vr-helper.enable or false;
          vrHosts = config.services.stash.vr-helper.hosts or { };
          enabledHosts = lib.filterAttrs (n: v: v.enable or true) vrHosts;
          # Sanitize host name for systemd service naming (same as in stash-vr-helper.nix)
          sanitizeName = name: builtins.replaceStrings [ "." ":" "/" "@" " " ] [ "-" "-" "-" "-" "-" ] name;
        in
        if !vrHelperEnabled then
          [ ]
        else
          lib.mapAttrsToList (hostName: hostCfg: {
            name = "stash-vr-${sanitizeName hostName}";
            enabled = true;
            port = hostCfg.port or null;
          }) enabledHosts;
    };

    invokeai = {
      services = [
        {
          name = "arion-invokeai";
          enabled = (config.services.invokeai.enable or false) && (config.services.invokeai.active or true);
          port = config.services.invokeai.port or 9090;
        }
      ];
    };

    comfyui = {
      services = [
        {
          name = "comfyui";
          enabled =
            (config.services.comfyui.enable or false) && !(config.services.comfyui.useDocker or false);
          port = config.services.comfyui.port or 8188;
        }
        {
          name = "arion-comfyui-docker";
          enabled = (config.services.comfyui.enable or false) && (config.services.comfyui.useDocker or false);
          port = config.services.comfyui.docker.port or 8188;
        }
      ];
    };

    comfyuimini = {
      services = [
        {
          name = "comfyuimini";
          enabled = config.services.comfyui.comfyuimini.enable or false;
          port = 3000;
        }
      ];
    };

    kavitan = {
      services = [
        {
          name = "kavitan";
          enabled = config.services.kavitan.enable or false;
          port = config.services.kavitan.settings.Port or null;
        }
      ];
    };

    openwebui = {
      services = [
        {
          name = "open-webui";
          enabled = config.services.open-webui.enable or false;
          port = config.services.open-webui.port or null;
        }
      ];
    };
  };

  # Get services based on configured friendly names
  requestedServices = flatten (
    map (
      friendlyName:
      if serviceRegistry ? ${friendlyName} then serviceRegistry.${friendlyName}.services else [ ]
    ) cfg.services
  );

  # Filter to only enabled services with valid ports
  enabledServices = filter (
    s: s.enabled && ((s ? port && s.port != null) || (s ? ports && (length s.ports) > 0))
  ) requestedServices;

  # Flatten services with multiple ports into individual entries
  flattenedServices = flatten (
    map (
      s:
      if s ? ports then
        map (port: {
          name = s.name;
          port = port;
        }) (filter (p: p != null) s.ports)
      else
        [
          {
            name = s.name;
            port = s.port;
          }
        ]
    ) enabledServices
  );

  # Get unique service names
  uniqueServiceNames = unique (map (s: s.name) enabledServices);

  # Service names with .service suffix for systemd directives
  uniqueServiceNamesWithSuffix = map (name: "${name}.service") uniqueServiceNames;

  # Generate HTML placeholder page content
  placeholderHtml = ''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Service Unavailable - Work Hours</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container {
          text-align: center;
          padding: 2rem;
          max-width: 600px;
        }
        h1 {
          font-size: 3rem;
          margin: 0 0 1rem 0;
          font-weight: 700;
        }
        p {
          font-size: 1.25rem;
          margin: 1rem 0;
          opacity: 0.9;
        }
        .time {
          font-size: 1rem;
          opacity: 0.8;
          margin-top: 2rem;
        }
        .emoji {
          font-size: 4rem;
          margin-bottom: 1rem;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="emoji">🚫</div>
        <h1>Service Blocked</h1>
        <p>This service is unavailable during work hours.</p>
        <p id="work-hours">Work hours: Monday-Friday, 8:00 AM - 5:00 PM</p>
        <p class="time">Please try again outside of work hours, or contact your administrator to temporarily disable work-block mode.</p>
      </div>
      <script>
        // Server timezone configuration (uses system timezone)
        const SERVER_TZ = '${config.time.timeZone}';
        const START_TIME = '${cfg.startTime}';
        const END_TIME = '${cfg.endTime}';
        const WORK_DAYS = [${concatMapStringsSep ", " (day: "'${day}'") cfg.workDays}];

        // Map abbreviated day names to full names
        const dayMap = {
          "Mon": "Monday",
          "Tue": "Tuesday",
          "Wed": "Wednesday",
          "Thu": "Thursday",
          "Fri": "Friday",
          "Sat": "Saturday",
          "Sun": "Sunday"
        };

        // Map days to their numeric order in the week
        const dayOrder = {
          "Sun": 0, "Mon": 1, "Tue": 2, "Wed": 3,
          "Thu": 4, "Fri": 5, "Sat": 6
        };

        // Format consecutive days into ranges
        function formatDayRanges(days) {
          if (days.length === 0) return "";
          if (days.length === 1) return dayMap[days[0]] || days[0];

          // Sort days by their week order
          const sortedDays = [...days].sort((a, b) => dayOrder[a] - dayOrder[b]);

          // Group consecutive days
          const ranges = [];
          let rangeStart = 0;

          for (let i = 1; i <= sortedDays.length; i++) {
            const isLastDay = i === sortedDays.length;
            const isConsecutive = !isLastDay &&
              dayOrder[sortedDays[i]] === dayOrder[sortedDays[i-1]] + 1;

            if (!isConsecutive) {
              const rangeEnd = i - 1;
              const rangeLength = rangeEnd - rangeStart + 1;

              if (rangeLength === 1) {
                // Single day
                ranges.push(dayMap[sortedDays[rangeStart]]);
              } else if (rangeLength === 2) {
                // Two consecutive days - show both
                ranges.push(`''${dayMap[sortedDays[rangeStart]]}, ''${dayMap[sortedDays[rangeEnd]]}`);
              } else {
                // Three or more consecutive days - show as range
                ranges.push(`''${dayMap[sortedDays[rangeStart]]}-''${dayMap[sortedDays[rangeEnd]]}`);
              }

              rangeStart = i;
            }
          }

          return ranges.join(", ");
        }

        // Function to format time in 12-hour format
        function formatTime12Hour(date) {
          return date.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true
          });
        }

        // Convert server time to user's local time
        function convertToLocalTime(timeString, serverTimezone) {
          // Parse the time string (HH:MM:SS)
          const [hours, minutes, seconds = 0] = timeString.split(":").map(Number);

          // Simple approach: create a date with the time, then adjust for timezone difference
          const now = new Date();

          // Create date with given time in LOCAL timezone first
          const localDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hours, minutes, seconds);

          // Calculate timezone offset difference
          // Get what "noon today" would be in both timezones to find the offset
          const referenceDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12, 0, 0);

          // Format reference date in server timezone and parse it back
          const serverTZString = referenceDate.toLocaleString("en-US", {
            timeZone: serverTimezone,
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
            hour12: false
          });

          // Parse the formatted string (will be interpreted in local TZ)
          // Format is like: "01/05/2026, 12:00:00"
          const parts = serverTZString.match(/(\d+)\/(\d+)\/(\d+),\s+(\d+):(\d+):(\d+)/);
          if (!parts) return localDate; // Fallback

          const reparsed = new Date(
            parseInt(parts[3]), // year
            parseInt(parts[1]) - 1, // month (0-indexed)
            parseInt(parts[2]), // day
            parseInt(parts[4]), // hour
            parseInt(parts[5]), // minute
            parseInt(parts[6])  // second
          );

          // The offset between these tells us the TZ difference
          const offset = referenceDate.getTime() - reparsed.getTime();

          // Apply offset to our target time
          return new Date(localDate.getTime() + offset);
        }

        try {
          const startTimeLocal = convertToLocalTime(START_TIME, SERVER_TZ);
          const endTimeLocal = convertToLocalTime(END_TIME, SERVER_TZ);

          const startFormatted = formatTime12Hour(startTimeLocal);
          const endFormatted = formatTime12Hour(endTimeLocal);

          // Check if the time range crosses midnight in local timezone
          const crossesMidnight = endTimeLocal.getTime() < startTimeLocal.getTime();
          const timeRangeText = crossesMidnight
            ? `''${startFormatted} - ''${endFormatted} (next day)`
            : `''${startFormatted} - ''${endFormatted}`;

          // Format days as ranges
          const dayRangeText = formatDayRanges(WORK_DAYS);

          // Get local timezone name
          const localTzName = Intl.DateTimeFormat().resolvedOptions().timeZone;

          // Check if timezones are the same or have the same offset
          const now = new Date();
          const localOffset = now.getTimezoneOffset();
          const serverOffset = new Date(now.toLocaleString("en-US", { timeZone: SERVER_TZ })).getTime() -
                               new Date(now.toLocaleString("en-US", { timeZone: "UTC" })).getTime();
          const userOffset = now.getTime() - new Date(now.toLocaleString("en-US", { timeZone: "UTC" })).getTime();

          const sameTimezone = localTzName === SERVER_TZ || Math.abs(serverOffset - userOffset) < 60000; // Within 1 minute

          // Only show timezone info if different
          const timezoneInfo = sameTimezone ? "" : ` (your local time: ''${localTzName})`;

          document.getElementById("work-hours").textContent =
            `Work hours: ''${dayRangeText}, ''${timeRangeText}''${timezoneInfo}`;
        } catch (e) {
          console.error("Error converting timezone:", e);
          // Fallback to showing server timezone name with day ranges
          const dayRangeText = formatDayRanges(WORK_DAYS);
          document.getElementById("work-hours").textContent =
            `Work hours: ''${dayRangeText}, ''${START_TIME.substring(0,5)} - ''${END_TIME.substring(0,5)} (''${SERVER_TZ})`;
        }
      </script>
    </body>
    </html>
  '';

  # Get list of unique ports
  ports = unique (map (s: s.port) flattenedServices);

  # Python HTTP server that serves the placeholder HTML on the blocked ports
  serverScript = pkgs.writeScript "work-block-server.py" ''
    #!${pkgs.python3}/bin/python3
    # Work-block HTTP server
    #
    # This server blocks the following services:
    ${concatMapStringsSep "\n" (s: "#   - ${s.name}") enabledServices}
    #
    # Ports being served: ${concatMapStringsSep ", " toString ports}

    import sys
    import signal
    import threading
    from http.server import HTTPServer, BaseHTTPRequestHandler
    from socketserver import ThreadingMixIn

    HTML_CONTENT = """${placeholderHtml}"""

    class WorkBlockHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_CONTENT.encode('utf-8'))

        def do_HEAD(self):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()

        def log_message(self, format, *args):
            # Log to stdout
            sys.stdout.write("%s - - [%s] %s\n" %
                           (self.address_string(),
                            self.log_date_time_string(),
                            format%args))

    class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
        daemon_threads = True
        allow_reuse_address = True

    def start_server(port):
        try:
            server = ThreadedHTTPServer(('0.0.0.0', port), WorkBlockHandler)
            print(f"Work-block server started on port {port}", flush=True)
            server.serve_forever()
        except Exception as e:
            print(f"Error starting server on port {port}: {e}", file=sys.stderr, flush=True)
            sys.exit(1)

    def signal_handler(sig, frame):
        print("\nShutting down work-block servers...", flush=True)
        sys.exit(0)

    if __name__ == '__main__':
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        ports = [${concatMapStringsSep ", " toString ports}]

        if not ports:
            print("Error: No ports specified", file=sys.stderr, flush=True)
            sys.exit(1)

        print(f"Starting work-block servers on ports: {ports}", flush=True)

        # Start a thread for each port
        threads = []
        for port in ports:
            thread = threading.Thread(target=start_server, args=(port,), daemon=True)
            thread.start()
            threads.append(thread)

        # Wait for all threads
        try:
            for thread in threads:
                thread.join()
        except KeyboardInterrupt:
            print("\nShutting down work-block servers...", flush=True)
            sys.exit(0)
  '';

  # Bash fragment: exits with a message and status 0 if today is a configured
  # holiday. Callers should source or dot-include; on non-holidays it returns
  # without producing output.
  holidayGuardFragment = ''
    TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
    HOLIDAYS=(${concatStringsSep " " (map (h: ''"${h}"'') cfg.holidays)})
    for holiday in "''${HOLIDAYS[@]}"; do
      if [ "$TODAY" = "$holiday" ]; then
        echo "Today ($TODAY) is a configured holiday. Skipping."
        exit 0
      fi
    done
  '';

  # Called by the work-block-start.timer. Writes today's session end into the
  # state file and starts work-block.service unless an override is currently
  # active (in which case work-block-check.service will pick it up when the
  # override elapses).
  startScript = pkgs.writeScript "work-block-start.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${holidayGuardFragment}

    END_TS="$TODAY ${cfg.endTime}"
    echo "$END_TS" > ${stateFile}
    echo "Wrote ${stateFile} = $END_TS"

    if ${pkgs.systemd}/bin/systemctl is-active --quiet work-block-check.timer; then
      echo "Override timer is active; not starting work-block.service now."
      echo "It will be re-evaluated when the override timer elapses."
      exit 0
    fi

    ${pkgs.systemd}/bin/systemctl start work-block.service
  '';

  # Called by the work-block-stop.timer. Deletes the state file and stops
  # work-block; ExecStopPost on work-block.service restarts blocked services.
  # Also cancels any active override timer so a new session starts cleanly.
  stopScript = pkgs.writeScript "work-block-stop.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${pkgs.coreutils}/bin/rm -f ${stateFile}
    echo "Removed ${stateFile}"

    ${pkgs.systemd}/bin/systemctl stop work-block-check.timer 2>/dev/null || true
    ${pkgs.systemd}/bin/systemctl stop work-block.service || true
  '';

  # Called at boot (via wantedBy=multi-user.target) and after the override timer
  # elapses. Restarts work-block if the day's session is still valid.
  checkScript = pkgs.writeScript "work-block-check.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    if [ ! -f ${stateFile} ]; then
      echo "No ${stateFile}; nothing to do."
      exit 0
    fi

    BLOCKED_UNTIL=$(${pkgs.coreutils}/bin/cat ${stateFile})
    BLOCKED_TS=$(${pkgs.coreutils}/bin/date -d "$BLOCKED_UNTIL" +%s 2>/dev/null || echo 0)
    NOW_TS=$(${pkgs.coreutils}/bin/date +%s)

    if [ "$BLOCKED_TS" -le "$NOW_TS" ]; then
      echo "$BLOCKED_UNTIL is in the past; removing stale state."
      ${pkgs.coreutils}/bin/rm -f ${stateFile}
      exit 0
    fi

    ${holidayGuardFragment}

    echo "Session still active until $BLOCKED_UNTIL; starting work-block.service."
    ${pkgs.systemd}/bin/systemctl start work-block.service
  '';

  # Called by the HTTP listener (or manually). Stops work-block (ExecStopPost
  # restarts blocked services) and resets the one-hour override timer so it
  # fires an hour from now, replacing any prior countdown.
  overrideScript = pkgs.writeScript "work-block-override.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Override requested. Suspending work-block for ${toString cfg.overrideDuration}s."

    ${pkgs.systemd}/bin/systemctl stop work-block.service || true

    # restart resets OnActiveSec back to the full duration, regardless of
    # whether the timer was already counting down.
    ${pkgs.systemd}/bin/systemctl restart work-block-check.timer
  '';

  # HTTP listener handler: drains the request headers, sends a minimal OK, then
  # kicks off the override in the background so the socket closes promptly.
  listenerHandlerScript = pkgs.writeScript "work-block-listener-handler.sh" ''
    #!${pkgs.bash}/bin/bash

    while IFS= read -r -t 2 line; do
      [[ "''${line%$'\r'}" == "" ]] && break
    done 2>/dev/null || true

    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK'

    ${pkgs.systemd}/bin/systemctl --no-block start work-block-override.service
  '';

  # Check if any services are configured and enabled
  hasEnabledServices = (length cfg.services) > 0 && (length enabledServices) > 0;

in
{
  options.services.work-block = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable work-block mode to automatically disable distracting services during work hours.

        When enabled, this will:
        - Stop specified services during work hours (Mon-Fri 8am-5pm by default)
        - Serve placeholder HTTP pages on their ports using a lightweight Python server
        - Automatically restart services when work-block is stopped or outside work hours

        Work hours use the system's configured timezone (`time.timeZone` option).

        Uses Python's built-in HTTP server to avoid conflicts with existing web servers like nginx.
        Only services that are both listed in `services.work-block.services` and actually enabled
        on the system will be affected.
      '';
    };

    services = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "stash"
        "stashvr"
        "comfyui"
        "invokeai"
      ];
      description = mdDoc ''
        List of services to block during work hours. Use friendly names:

        - `stash` - Stash media server
        - `stashvr` - Stash VR helper (both local and external instances)
        - `invokeai` - InvokeAI (Docker)
        - `comfyui` - ComfyUI (both native and Docker versions)
        - `comfyuimini` - ComfyUI Mini frontend
        - `kavitan` - Kavitan media reader
        - `openwebui` - Open WebUI

        Only services that are actually enabled on your system will be blocked.
        If a service isn't enabled, it will be silently ignored.
      '';
    };

    startTime = mkOption {
      type = types.str;
      default = "09:00:00";
      description = mdDoc ''
        Time to start blocking services (24-hour format).

        Uses the system's configured timezone (`time.timeZone` option).
      '';
    };

    endTime = mkOption {
      type = types.str;
      default = "17:00:00";
      description = mdDoc ''
        Time to stop blocking services (24-hour format).

        Uses the system's configured timezone (`time.timeZone` option).
      '';
    };

    workDays = mkOption {
      type = types.listOf types.str;
      default = [
        "Mon"
        "Tue"
        "Wed"
        "Thu"
        "Fri"
      ];
      description = "Days of the week to enable work-block";
    };

    holidays = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "2026-01-19"
        "2026-12-25"
        "2027-01-01"
      ];
      description = mdDoc ''
        List of holidays (in YYYY-MM-DD format) when work-block should NOT activate.

        On these dates, `work-block-start.service` exits without writing the state
        file or starting the block, and `work-block-check.service` (if triggered by
        an override or boot recovery) refuses to reactivate. Adding a day off still
        requires a rebuild.
      '';
    };

    overrideDuration = mkOption {
      type = types.int;
      default = 3600;
      description = mdDoc ''
        How long (in seconds) the manual override suspends work-block before it is
        re-evaluated. Every override request resets this countdown from the moment
        the request arrives.
      '';
    };

    listener = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Enable a systemd socket-activated HTTP listener that triggers the work-block
          override on any incoming request. Intended for use with a physical button or
          other simple trigger that sends a single HTTP request per press.

          The request body is not parsed; the mere arrival of a connection is the signal.
        '';
      };

      port = mkOption {
        type = types.port;
        default = configVars.networking.ports.tcp.workBlockOverride;
        description = "TCP port the override listener binds to.";
      };
    };
  };

  config = mkIf (cfg.enable && hasEnabledServices) {
    # State directory for the blocked-until file. Persistent across reboots.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];

    # Main work-block service: HTTP server on the blocked ports.
    # Conflicts= stops the blocked services when this starts.
    # ExecStopPost restarts them when this stops (via the helper below).
    systemd.services.work-block = {
      description = "Work Block - Disable distracting services during work hours (Python HTTP server)";

      before = uniqueServiceNamesWithSuffix;
      conflicts = uniqueServiceNamesWithSuffix;

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";

        ExecStart = "${serverScript}";

        # '-+' prefix: ignore failures, run with full privileges (bypass sandbox)
        ExecStopPost = "-+${pkgs.systemd}/bin/systemctl --no-block start work-block-restart-services.service";

        TimeoutStopSec = "30s";

        # Security hardening
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;

        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      };
    };

    # Helper: restart blocked services after work-block.service stops.
    # Runs as root so it can start services outside the sandboxed main unit.
    systemd.services.work-block-restart-services = {
      description = "Restart services that were blocked by work-block";
      after = [ "work-block.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = map (
          service: "-${pkgs.systemd}/bin/systemctl start ${service}.service"
        ) uniqueServiceNames;
      };
    };

    # Start-of-day: write the state file and start work-block.
    systemd.services.work-block-start = {
      description = "Begin a work-block session for the current day";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${startScript}";
      };
    };

    systemd.timers.work-block-start = {
      description = "Start work-block at beginning of work hours (${config.time.timeZone})";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "${concatStringsSep "," cfg.workDays} *-*-* ${cfg.startTime}";
        Persistent = true;
        Unit = "work-block-start.service";
      };
    };

    # End-of-day: delete the state file and stop work-block.
    systemd.services.work-block-stop = {
      description = "End the current day's work-block session";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${stopScript}";
      };
    };

    systemd.timers.work-block-stop = {
      description = "Stop work-block at end of work hours (${config.time.timeZone})";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "${concatStringsSep "," cfg.workDays} *-*-* ${cfg.endTime}";
        Persistent = true;
        Unit = "work-block-stop.service";
      };
    };

    # Check service: run at boot and after the override timer elapses.
    # Reads the state file and restarts work-block if the session is still active.
    systemd.services.work-block-check = {
      description = "Re-evaluate work-block state (boot recovery / post-override)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${checkScript}";
      };
    };

    # One-shot override timer. Not wantedBy anything: activated only by the
    # override service. OnActiveSec fires once, then the timer goes inactive.
    systemd.timers.work-block-check = {
      description = "Fire work-block-check after the override elapses";
      timerConfig = {
        OnActiveSec = cfg.overrideDuration;
        Unit = "work-block-check.service";
        RemainAfterElapse = false;
      };
    };

    # Manual override: stop work-block now, reset the one-hour timer.
    systemd.services.work-block-override = {
      description = "Suspend work-block for ${toString cfg.overrideDuration}s (resets on each request)";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${overrideScript}";
      };
    };

    # HTTP listener socket. Accept=yes spawns a fresh handler per connection.
    systemd.sockets.work-block-trigger = mkIf cfg.listener.enable {
      description = "Work-block override trigger socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = cfg.listener.port;
        Accept = true;
      };
    };

    systemd.services."work-block-trigger@" = mkIf cfg.listener.enable {
      description = "Work-block override trigger handler";
      serviceConfig = {
        Type = "simple";
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        ExecStart = "${listenerHandlerScript}";
        User = "root";
        TimeoutStartSec = "10s";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.listener.enable [ cfg.listener.port ];
  };
}
