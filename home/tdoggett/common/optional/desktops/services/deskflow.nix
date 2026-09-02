{ lib, ... }:
{
  services.deskflow.client = {
    enable = lib.mkDefault true;
  };
  
  # Persistence: .config/Deskflow (declare in system-level persistence files)
}
  
