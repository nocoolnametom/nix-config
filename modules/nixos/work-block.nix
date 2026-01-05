# Work Block Module
#
# Automatically blocks distracting services during work hours by:
# - Stopping specified services (stash, invokeai, comfyui, etc.)
# - Serving placeholder HTTP pages on their ports using a lightweight Python server
# - Auto-restarting services when work-block is stopped or outside work hours
# - Respecting configured holidays (no blocking on vacation days)
#
# Uses Python's built-in HTTP server (no nginx) to avoid conflicts with existing web servers.
# Only services that are explicitly configured and enabled will be affected.
# If no relevant services are enabled, the work-block service won't be created.
#
# Usage:
#   Add to your host configuration or import hosts/common/optional/services/work-block.nix:
#
#   services.work-block = {
#     enable = true;
#     services = [ "stash" "comfyui" "invokeai" ];  # Which services to block
#   };
#
# Optional configuration:
#   services.work-block.startTime = "09:00:00";  # Default: 08:00:00
#   services.work-block.endTime = "18:00:00";    # Default: 17:00:00
#   services.work-block.timezone = "America/Los_Angeles";  # Default: America/New_York
#   services.work-block.workDays = [ "Mon" "Tue" "Wed" "Thu" "Fri" ];  # Default
#   services.work-block.holidays = [ "2026-01-19" "2026-12-25" ];  # Default: []
#
# Manual override:
#   To temporarily disable work-block (e.g., on a work holiday):
#     sudo systemctl stop work-block
#   Services will automatically restart when work-block stops.
#
#   To manually re-enable:
#     sudo systemctl start work-block
#
#   To manually re-enable on a holiday:
#     sudo WORK_BLOCK_IGNORE_HOLIDAYS=1 systemctl start work-block
#
# Services that can be blocked (if enabled):
#   - stash
#   - stash-vr-helper
#   - arion-invokeai (InvokeAI Docker)
#   - comfyui (native or Docker)
#   - comfyuimini
#   - kavitan (note: kavita is NOT blocked, only kavitan)
#   - open-webui
#
# The module automatically detects which services are enabled and their ports,
# so you don't need to configure anything beyond enabling the module.
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
          # Check if invokeai service config is enabled AND active
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
          # Check if comfyui is enabled AND using Docker
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
        // Server timezone configuration
        const SERVER_TZ = '${cfg.timezone}';
        const START_TIME = '${cfg.startTime}';
        const END_TIME = '${cfg.endTime}';
        const WORK_DAYS = [${concatMapStringsSep ", " (day: "'${day}'") cfg.workDays}];

        // Map abbreviated day names to full names
        const dayMap = {
          'Mon': 'Monday',
          'Tue': 'Tuesday',
          'Wed': 'Wednesday',
          'Thu': 'Thursday',
          'Fri': 'Friday',
          'Sat': 'Saturday',
          'Sun': 'Sunday'
        };

        // Map days to their numeric order in the week
        const dayOrder = {
          'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3,
          'Thu': 4, 'Fri': 5, 'Sat': 6
        };

        // Format consecutive days into ranges
        function formatDayRanges(days) {
          if (days.length === 0) return '';
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

          return ranges.join(', ');
        }

        // Function to format time in 12-hour format
        function formatTime12Hour(date) {
          return date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
          });
        }

        // Convert server time to user's local time
        function convertToLocalTime(timeString, serverTimezone) {
          // Get today's date in the server's timezone
          const now = new Date();
          const serverDateStr = now.toLocaleDateString('en-CA', { timeZone: serverTimezone }); // YYYY-MM-DD format

          // Parse the time string (HH:MM:SS)
          const [hours, minutes] = timeString.split(':').map(Number);

          // Create a date object in the server's timezone
          const serverDateTime = new Date(`''${serverDateStr}T''${timeString}Z`);

          // Get the offset for the server timezone
          const serverDateInTZ = new Date(serverDateTime.toLocaleString('en-US', { timeZone: serverTimezone }));
          const serverDateInUTC = new Date(serverDateTime.toLocaleString('en-US', { timeZone: 'UTC' }));
          const tzOffset = serverDateInUTC - serverDateInTZ;

          // Adjust for timezone offset
          const localDate = new Date(serverDateTime.getTime() - tzOffset);

          return localDate;
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

          document.getElementById('work-hours').textContent = 
            `Work hours: ''${dayRangeText}, ''${timeRangeText} (your local time: ''${localTzName})`;
        } catch (e) {
          console.error('Error converting timezone:', e);
          // Fallback to showing server timezone name with day ranges
          const dayRangeText = formatDayRanges(WORK_DAYS);
          document.getElementById('work-hours').textContent = 
            `Work hours: ''${dayRangeText}, ''${START_TIME.substring(0,5)} - ''${END_TIME.substring(0,5)} (''${SERVER_TZ})`;
        }
      </script>
    </body>
    </html>
  '';

  # Get list of unique ports
  ports = unique (map (s: s.port) flattenedServices);

  # Create a script to check if today is a holiday
  # Returns exit code 0 if NOT a holiday (should block)
  # Returns exit code 1 if IS a holiday (should NOT block)
  # Can be bypassed by setting WORK_BLOCK_IGNORE_HOLIDAYS=1 environment variable
  holidayCheckScript = pkgs.writeScript "work-block-holiday-check.sh" ''
    #!${pkgs.bash}/bin/bash

    # Allow manual override via environment variable
    if [ "$WORK_BLOCK_IGNORE_HOLIDAYS" = "1" ]; then
      echo "WORK_BLOCK_IGNORE_HOLIDAYS is set. Bypassing holiday check."
      exit 0
    fi

    TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)

    HOLIDAYS=(${concatStringsSep " " (map (h: ''"${h}"'') cfg.holidays)})

    for holiday in "''${HOLIDAYS[@]}"; do
      if [ "$TODAY" = "$holiday" ]; then
        echo "Today ($TODAY) is a configured holiday. Skipping work-block activation."
        echo "To manually override, run: sudo WORK_BLOCK_IGNORE_HOLIDAYS=1 systemctl start work-block"
        exit 1
      fi
    done

    # Not a holiday, proceed with work-block
    exit 0
  '';

  # Create a Python script that serves the placeholder HTML on multiple ports
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
        - Stop specified services during work hours (Mon-Fri 8am-5pm)
        - Serve placeholder HTTP pages on their ports using a lightweight Python server
        - Automatically restart services when work-block is stopped or outside work hours

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
      default = "08:00:00";
      description = "Time to start blocking services (24-hour format)";
    };

    endTime = mkOption {
      type = types.str;
      default = "17:00:00";
      description = "Time to stop blocking services (24-hour format)";
    };

    timezone = mkOption {
      type = types.str;
      default = "America/New_York";
      example = "America/Los_Angeles";
      description = mdDoc ''
        Timezone for work hours. This explicitly sets which timezone the start and end times use.
        Uses IANA timezone database names (e.g., "America/New_York", "America/Chicago", 
        "America/Denver", "America/Los_Angeles", "UTC").

        This is particularly useful if you travel or if the system timezone differs from
        your work timezone.
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

        This is useful for pre-configuring company holidays, vacation days, and other
        days off where you don't want services blocked even if they fall on a work day.

        The work-block service will check if today matches any date in this list and
        skip activation if it's a holiday.

        Examples:
        - "2026-01-19" - Martin Luther King Jr. Day
        - "2026-12-25" - Christmas
        - "2026-07-04" - Independence Day
      '';
    };
  };

  config = mkIf (cfg.enable && hasEnabledServices) {
    # Main work-block service that stops services and serves placeholders
    systemd.services.work-block = {
      description = "Work Block - Disable distracting services during work hours (Python HTTP server)";

      # Stop the blocked services when this starts
      # Note: systemd requires full unit names with .service suffix
      before = uniqueServiceNamesWithSuffix;
      conflicts = uniqueServiceNamesWithSuffix;

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";

        # Check if today is a holiday - if so, skip activation
        # ExecCondition exits 0 = proceed, non-zero = skip (but not fail)
        ExecCondition = mkIf ((length cfg.holidays) > 0) "${holidayCheckScript}";

        # Run Python HTTP server to serve placeholder pages
        ExecStart = "${serverScript}";

        # When work-block stops (manually or via timer), trigger service restart
        # Use '-+' prefix: '-' ignores failures, '+' runs with full privileges (bypassing sandbox)
        # Schedule restart to run after we're fully stopped using --on-active=1s
        ExecStopPost = "-+${pkgs.systemd}/bin/systemd-run --on-active=1s --timer-property=AccuracySec=100ms ${pkgs.systemd}/bin/systemctl start work-block-restart-services.service";

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

        # Allow binding to the service ports
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      };
    };

    # Timer to automatically enable work-block during work hours
    systemd.timers.work-block-start = {
      description = "Start work-block at beginning of work hours (${cfg.timezone})";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "${cfg.timezone} ${concatStringsSep "," cfg.workDays} *-*-* ${cfg.startTime}";
        Persistent = false;
        Unit = "work-block.service";
      };
    };

    # Timer to automatically disable work-block at end of work hours
    systemd.timers.work-block-stop = {
      description = "Stop work-block at end of work hours (${cfg.timezone})";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "${cfg.timezone} ${concatStringsSep "," cfg.workDays} *-*-* ${cfg.endTime}";
        Persistent = false;
        Unit = "work-block-stop.service";
      };
    };

    # Oneshot service that the stop timer activates
    systemd.services.work-block-stop = {
      description = "Stop work-block service and restart blocked services";

      # Make sure work-block stops first
      before = [ "work-block-restart-services.service" ];

      serviceConfig = {
        Type = "oneshot";

        # Stop work-block and wait for it to fully stop
        ExecStart = "${pkgs.systemd}/bin/systemctl stop work-block.service";

        # After this service completes, start the restart helper
        ExecStartPost = "${pkgs.systemd}/bin/systemctl start work-block-restart-services.service";
      };
    };

    # Helper service to restart blocked services
    # This should be triggered after work-block has fully stopped
    systemd.services.work-block-restart-services = {
      description = "Restart services that were blocked by work-block";

      # Only start this after work-block is fully stopped
      after = [ "work-block.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;

        # Add a small delay to ensure work-block is fully stopped
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";

        # Restart all blocked services
        ExecStart = map (
          service: "-${pkgs.systemd}/bin/systemctl start ${service}.service"
        ) uniqueServiceNames;
      };
    };
  };
}
