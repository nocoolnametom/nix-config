{
  lib,
  configVars,
  ...
}:
{
  # Enable work-block to help with focus during work hours
  services.work-block = {
    enable = lib.mkDefault true;

    # Services to block during work hours
    # Only services that are actually enabled on each system will be blocked
    services = [
      "stash" # Stash media server
      "stashvr" # Stash VR helper (local + external)
      "invokeai" # InvokeAI AI image generation
      "comfyui" # ComfyUI (native or Docker)
      "comfyuimini" # ComfyUI Mini frontend
      "kavitan" # Kavitan media reader (not kavita)
      "openwebui" # Open WebUI
    ];

    # Holidays - days when work-block should NOT activate (even on work days)
    # Format: YYYY-MM-DD
    holidays = [
      # 2026 Paid Holidays
      "2026-01-19" # Martin Luther King Jr. Day
      "2026-05-25" # Memorial Day
      "2026-06-19" # Juneteenth
      "2026-07-03" # Independence Day (observed)
      "2026-09-07" # Labor Day
      "2026-11-26" # Thanksgiving
      "2026-11-27" # Day after Thanksgiving
      "2026-12-24" # Christmas Eve
      "2026-12-25" # Christmas Day

      # Time Off / Vacation Days
      # Add your vacation days here as you schedule them
    ];

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
