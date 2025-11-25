{ lib, config, ... }:

{
  options.system.deprecation = {
    isDeprecated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this system configuration is deprecated/archived.
        Deprecated systems are no longer in active use but are maintained
        for reference purposes and to ensure configuration examples remain valid.
      '';
    };

    reason = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Explanation of why this system was deprecated.
        Example: "Hardware decommissioned, replaced by estel"
      '';
    };

    deprecatedSince = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        When this system was deprecated.
        Format: YYYY-MM (e.g., "2024-03")
      '';
    };

    lastKnownGoodBuild = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Last known working commit hash or flake revision.
        Useful for reference if someone needs to restore the system.
      '';
    };

    replacedBy = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Name of the system that replaced this one, if applicable.
        Example: "estel"
      '';
    };
  };

  config = lib.mkIf config.system.deprecation.isDeprecated {
    # Add a warning that appears during build/evaluation
    warnings = [
      ''
        ⚠️  DEPRECATED SYSTEM CONFIGURATION

        This system is no longer in active use and is maintained for reference only.

        Reason: ${config.system.deprecation.reason}
        Deprecated since: ${config.system.deprecation.deprecatedSince}
        ${lib.optionalString (
          config.system.deprecation.replacedBy != ""
        ) "Replaced by: ${config.system.deprecation.replacedBy}"}
        ${lib.optionalString (
          config.system.deprecation.lastKnownGoodBuild != ""
        ) "Last known good build: ${config.system.deprecation.lastKnownGoodBuild}"}
      ''
    ];

    # Add a motd message if someone somehow boots this system
    environment.etc."motd".text = lib.mkBefore ''
      ═══════════════════════════════════════════════════════════════════════════
      ⚠️  WARNING: This is a DEPRECATED system configuration
      ═══════════════════════════════════════════════════════════════════════════

      This system is no longer in active use and is maintained for reference only.

      Reason: ${config.system.deprecation.reason}
      Deprecated since: ${config.system.deprecation.deprecatedSince}
      ${lib.optionalString (
        config.system.deprecation.replacedBy != ""
      ) "Replaced by: ${config.system.deprecation.replacedBy}"}

      ═══════════════════════════════════════════════════════════════════════════

    '';
  };
}
