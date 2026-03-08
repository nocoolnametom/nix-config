{ lib, pkgs, ... }:
{
  # AMD GPU monitoring tool - like nvidia-smi for AMD GPUs
  # Run with: amdgpu_top
  # Useful for monitoring AMD GPU usage, temperatures, and frequencies

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      amdgpu_top
      ;
  };
}
