{
  lib,
  configVars,
  ...
}:
{
  # Enable work-block to help with focus during work hours
  services.work-block = {
    enable = lib.mkDefault true;
    listener.enable = lib.mkDefault true;

    # Services to block during work hours
    # Only services that are actually enabled on each system will be blocked
    services = configVars.work.workblock-services ++ [ ];

    # Holidays - days when work-block should NOT activate (even on work days)
    # Format: YYYY-MM-DD
    holidays = configVars.work.holidays ++ configVars.work.vacations ++ [ ];

    # Work hours (default: Mon-Fri 8am-5pm in system timezone)
    # Uncomment and adjust if you want different hours:
    # startTime = "09:00:00";
    # endTime = "18:00:00";
    # workDays = [ "Mon" "Tue" "Wed" "Thu" "Fri" ];
    #
    # Note: Times use the system's configured timezone (time.timeZone).
    # Make sure your system timezone is set correctly for your location.
  };
}
