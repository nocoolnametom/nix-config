{ lib, ... }:
{
  services.deskflow.client = {
    # Disabled until a valid Deskflow server config exists in ~/.config/Deskflow/Deskflow.conf.
    enable = lib.mkDefault false;
  };

  # Persistence: .config/Deskflow (declare in system-level persistence files)
}
