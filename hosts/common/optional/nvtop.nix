{ lib, pkgs, ... }:
{
  # GPU monitoring tool - supports NVIDIA, AMD, and Intel GPUs
  # Run with: nvtop
  environment.systemPackages = lib.attrValues {
    inherit (pkgs.nvtopPackages)
      nvidia # NVIDIA GPUs
      amd # AMD GPUs
      intel # Intel GPUs
      ;
  };
}
