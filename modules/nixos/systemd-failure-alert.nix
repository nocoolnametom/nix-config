{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.systemd-failure-alert;
  essentialServiceSources = [
    {
      system = "nixos-upgrade";
      control = config.system.autoUpgrade.enable;
    }
    {
      system = "nix-optimise";
      control = config.nix.optimise.automatic;
    }
    {
      system = "nix-gc";
      control = config.nix.gc.automatic;
    }
  ];
  essentialServices = builtins.map (source: source.system) (
    builtins.filter (source: source.control) essentialServiceSources
  );
  systemdServices = essentialServices ++ cfg.additional-services;

  stateDirectory = "/var/lib/systemd-failure-alert";

  # Pushover debounce, per failing service. A service stuck in a restart loop can fail every few
  # seconds (feanor's immich-server sent 9 Pushover alerts in one minute), so after an alert goes
  # out, further failures of the same service are only counted until `cooldownSeconds` has
  # passed. The next alert that does go out reports how many were swallowed. The flock keeps
  # near-simultaneous instances from both deciding to send.
  # Call `markAlertSent` only after the notification actually went out, so a failed send is
  # retried on the next failure instead of starting a silent cooldown.
  debounceScript = notifier: ''
    alertStatePrefix="${stateDirectory}/${notifier}-$SERVICE_ID"
    exec 9>"$alertStatePrefix.lock"
    flock 9
    currentTime=$(date +%s)
    lastSentTime=$(cat "$alertStatePrefix.last-sent" 2>/dev/null || echo 0)
    if [ $((currentTime - lastSentTime)) -lt ${toString cfg.cooldownSeconds} ]; then
      suppressedCount=$(cat "$alertStatePrefix.suppressed" 2>/dev/null || echo 0)
      echo $((suppressedCount + 1)) > "$alertStatePrefix.suppressed"
      echo "Not sending ${notifier} alert for $SERVICE_ID: last one went out $((currentTime - lastSentTime))s ago"
      exit 0
    fi
    SUPPRESSED_COUNT=$(cat "$alertStatePrefix.suppressed" 2>/dev/null || echo 0)
    SUPPRESSED_NOTE=""
    if [ "$SUPPRESSED_COUNT" -gt 0 ]; then
      SUPPRESSED_NOTE="($SUPPRESSED_COUNT more failure(s) since the previous alert were not reported)"
    fi
    markAlertSent() {
      echo "$currentTime" > "$alertStatePrefix.last-sent"
      rm -f "$alertStatePrefix.suppressed"
    }
  '';

  # Email is a digest across all services, not per service: the first failure is mailed right
  # away, and every failure in the following `cooldownSeconds` (any service, any number of times)
  # is queued and mailed as one message when the window ends. If that digest had anything in it,
  # a new window starts, so a service that keeps crash-looping produces one email per window.
  #
  # State: email-queue holds one "<epoch> <service>" line per failure not yet mailed;
  # email-last-sent holds the epoch of the last successful email. notify-email-digest.timer is
  # (re)armed after each send and fires notify-email-digest.service at the end of the window.
  # If a send fails, the queue and timestamp are left alone, so the next failure (or the next
  # timer run) retries with everything that is still queued.
  emailQueueFile = "${stateDirectory}/email-queue";
  emailLastSentFile = "${stateDirectory}/email-last-sent";
  emailDigestScript = ''
    exec 9>"${stateDirectory}/email.lock"
    flock 9

    # Mail everything in the queue as one message, then start a new cooldown window
    sendQueuedFailures() {
      local hostName serviceList serviceCount subject
      hostName=$(${pkgs.hostname}/bin/hostname)
      serviceList=$(awk '!seen[$2]++ { print $2 }' ${emailQueueFile})
      serviceCount=$(echo "$serviceList" | wc -l)
      if [ "$serviceCount" -eq 1 ]; then
        subject="[$hostName] service $serviceList failed"
      else
        subject="[$hostName] $serviceCount services failed: $(echo "$serviceList" | paste -sd, - | sed 's/,/, /g')"
      fi
      {
        echo "Date: $(date -R)"
        echo "From: root (systemd notify-email)"
        echo "To: $EMAIL_ADDRESS"
        echo "Subject: $subject"
        echo "Auto-Submitted: auto-generated"
        echo
        echo "Failures on $hostName not yet reported by email:"
        echo
        # One line per service: failure count plus first and last failure time
        awk '{
          if (!($2 in failureCount)) { serviceOrder[++numServices] = $2; firstFailure[$2] = $1 }
          failureCount[$2]++; lastFailure[$2] = $1
        } END {
          for (i = 1; i <= numServices; i++) {
            serviceName = serviceOrder[i]
            printf "  %-40s %4dx  first %s  last %s\n", serviceName, failureCount[serviceName],
              strftime("%F %T", firstFailure[serviceName]), strftime("%F %T", lastFailure[serviceName])
          }
        }' ${emailQueueFile}
        echo "$serviceList" | while read -r serviceName; do
          echo
          echo "==== systemctl status $serviceName"
          systemctl status "$serviceName" 2>&1 | head -n 25 ||:
        done
      } | ${cfg.email.sendCommand} "$EMAIL_ADDRESS"
      rm -f ${emailQueueFile}
      date +%s > ${emailLastSentFile}
      systemctl restart --no-block notify-email-digest.timer
    }
  '';

  # Settings shared by the notifier units
  notifierServiceConfig = {
    StateDirectory = "systemd-failure-alert";
  };
in
{
  options.services.systemd-failure-alert = {
    enable = lib.mkEnableOption "Enable systemd failure alert service";

    email = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable email notifications (requires sendmail/mailserver)";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "root@localhost";
        description = "E-mail address to send alerts to";
      };
      sendCommand = lib.mkOption {
        type = lib.types.str;
        # A sendmail-compatible MTA (e.g. Postfix) installs sendmail as a setgid wrapper here.
        # systemd units do not have the wrapper dir on PATH, so a bare `sendmail` is
        # "command not found" even though the mail server is working.
        default = "${config.security.wrapperDir}/sendmail";
        defaultText = lib.literalExpression ''"''${config.security.wrapperDir}/sendmail"'';
        description = ''
          sendmail-compatible command used to send alerts. It receives the full message
          (headers included) on stdin and the recipient address as its only argument.
        '';
      };
    };

    cooldownSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 1800;
      description = ''
        Debounce window, in seconds.
        Pushover: minimum time between two alerts for the same service; failures inside the
        window are counted and mentioned in the next alert.
        Email: after an email goes out, failures of any service during this window are
        collected into a single digest email sent when the window ends.
        Set to 0 to alert on every failure.
      '';
    };

    additional-services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "nixos-upgrade"
        "nix-optimise"
      ];
      description = ''
        List of systemd services to monitor for failure
        Note that an empty service WILL be created if it is not already defined!
      '';
    };

    pushover = {
      enable = lib.mkEnableOption "Enable Pushover notifications";
      userKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Pushover user key";
      };
      apiTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Pushover API token";
      };
      priority = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Pushover priority (-2 to 2, where 1 = high priority, 2 = emergency)";
      };
    };
  };

  config = lib.mkIf (cfg.enable && (builtins.lessThan 0 (builtins.length systemdServices))) {
    # Warn if neither notification method is enabled
    warnings = lib.optional (
      !cfg.email.enable && !cfg.pushover.enable
    ) "systemd-failure-alert is enabled but neither email nor pushover notifications are enabled";

    # Define systemd template units for reporting service failures
    systemd.services = (
      # Email notification service (only if enabled)
      lib.optionalAttrs (cfg.email.enable) {
        "notify-email@" = {
          environment.EMAIL_ADDRESS = lib.strings.replaceStrings [ "%" ] [ "%%" ] cfg.email.address;
          environment.SERVICE_ID = "%i";
          path = with pkgs; [
            coreutils
            gawk # strftime
            gnused
            systemd
            util-linux # flock
          ];
          serviceConfig = notifierServiceConfig;
          script = ''
            ${emailDigestScript}
            currentTime=$(date +%s)
            echo "$currentTime $SERVICE_ID" >> ${emailQueueFile}
            lastSentTime=$(cat ${emailLastSentFile} 2>/dev/null || echo 0)
            if [ $((currentTime - lastSentTime)) -ge ${toString cfg.cooldownSeconds} ]; then
              sendQueuedFailures
            else
              echo "Queued $SERVICE_ID for the next digest email"
              # No-op while the timer is armed; re-arms it if it was lost (e.g. after a reboot)
              systemctl start --no-block notify-email-digest.timer
            fi
          '';
        };
        notify-email-digest = {
          description = "Send queued systemd failure alerts as one digest email";
          environment.EMAIL_ADDRESS = lib.strings.replaceStrings [ "%" ] [ "%%" ] cfg.email.address;
          path = with pkgs; [
            coreutils
            gawk # strftime
            gnused
            systemd
            util-linux # flock
          ];
          serviceConfig = notifierServiceConfig // {
            Type = "oneshot";
          };
          script = ''
            ${emailDigestScript}
            if [ -s ${emailQueueFile} ]; then
              sendQueuedFailures
            fi
          '';
        };
      }
      # Pushover notification service (only if enabled)
      // lib.optionalAttrs (cfg.pushover.enable) {
        "notify-pushover@" = {
          environment.SERVICE_ID = "%i";
          path = with pkgs; [
            curl
            systemd
            coreutils
            util-linux # flock
          ];
          serviceConfig = notifierServiceConfig;
          script = ''
            ${debounceScript "pushover"}

            # Read API credentials from files
            PUSHOVER_USER_KEY=$(cat ${cfg.pushover.userKeyFile})
            PUSHOVER_API_TOKEN=$(cat ${cfg.pushover.apiTokenFile})

            # Get hostname and service status
            HOSTNAME=$(${pkgs.hostname}/bin/hostname)
            SERVICE_STATUS=$(systemctl status "$SERVICE_ID" 2>&1 | head -n 20)

            # Send Pushover notification
            # --fail makes an HTTP error a non-zero exit, so the alert is not marked as sent
            ${pkgs.curl}/bin/curl -s --fail \
              --form-string "token=$PUSHOVER_API_TOKEN" \
              --form-string "user=$PUSHOVER_USER_KEY" \
              --form-string "title=[$HOSTNAME] Service Failure" \
              --form-string "message=Service $SERVICE_ID has failed on $HOSTNAME $SUPPRESSED_NOTE" \
              --form-string "priority=${toString cfg.pushover.priority}" \
              https://api.pushover.net/1/messages.json
            markAlertSent
          '';
        };
      }
      # Add onFailure handlers to monitored services
      // (lib.attrsets.genAttrs systemdServices (
        name:
        let
          # Build list of notifiers based on what's enabled
          notifiers =
            lib.optional cfg.email.enable "notify-email@%i.service"
            ++ lib.optional cfg.pushover.enable "notify-pushover@%i.service";
        in
        {
          onFailure = lib.mkBefore notifiers;
        }
      ))
    );

    # Started (not enabled) by the email units above; fires once at the end of a cooldown window.
    # RemainAfterElapse=false makes the timer go inactive after firing, so it can be armed again.
    systemd.timers = lib.optionalAttrs (cfg.email.enable) {
      notify-email-digest = {
        description = "End of the systemd failure email cooldown window";
        timerConfig = {
          # Keep at least one second so the timer always has a future trigger
          OnActiveSec = lib.max 1 cfg.cooldownSeconds;
          AccuracySec = "1s";
          RemainAfterElapse = false;
        };
      };
    };
  };
}
