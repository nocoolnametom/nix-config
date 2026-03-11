{
  config,
  lib,
  pkgs,
  ...
}:
let
  allKernelModules = config.boot.initrd.kernelModules ++ config.boot.kernelModules;
  # nvidia.nix sets services.xserver.videoDrivers = ["nvidia"]
  hasNvidia = builtins.elem "nvidia" config.services.xserver.videoDrivers;
  # hardware.amdgpu.initrd.enable adds "amdgpu" to initrd kernel modules,
  # so checking kernel modules covers both explicit and declarative AMD configs
  hasAmd = builtins.elem "amdgpu" allKernelModules;
  hasIntel = builtins.elem "i915" allKernelModules;
in
{
  environment.systemPackages =
    lib.optionals hasNvidia [ pkgs.nvtopPackages.nvidia ] # pulls in CUDA; guard with videoDrivers check
    ++ lib.optionals hasAmd [ pkgs.nvtopPackages.amd ]
    ++ lib.optionals hasIntel [ pkgs.nvtopPackages.intel ];
}
