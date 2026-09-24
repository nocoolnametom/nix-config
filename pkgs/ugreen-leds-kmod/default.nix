###############################################################################
#
#  led-ugreen kernel module
#
#  Out-of-tree Linux kernel module that registers the UGREEN NASync front-panel
#  LEDs as standard Linux LED class devices under /sys/class/leds/.  Once
#  loaded, the monitoring daemons (ugreen-diskiomon, ugreen-netdevmon) can bind
#  sysfs triggers to these devices.
#
#  This derivation must be called via linuxPackages.callPackage (or
#  boot.kernelPackages.callPackage), NOT via the flat packages output, because
#  it needs a specific kernel to build against.
#
#  Usage from a NixOS module:
#
#    boot.extraModulePackages = [
#      (config.boot.kernelPackages.callPackage ./ugreen-leds-kmod { })
#    ];
#    boot.kernelModules = [ "led-ugreen" "i2c-dev" ];
#
###############################################################################

{
  lib,
  stdenv,
  kernel,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "led-ugreen";
  version = "0.3";

  src = fetchFromGitHub {
    owner = "miskcoo";
    repo = "ugreen_leds_controller";
    tag = "v${finalAttrs.version}";
    hash = "sha256-eSTOUHs4y6n4cacpjQAp4JIfyu40aBJEMsvuCN6RFZc=";
  };

  # The kernel module source lives in kmod/
  sourceRoot = "${finalAttrs.src.name}/kmod";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    dest="$out/lib/modules/${kernel.modDirVersion}/misc"
    mkdir -p "$dest"
    cp led-ugreen.ko "$dest/"
    runHook postInstall
  '';

  meta = {
    description = "Linux kernel module for UGREEN NAS front-panel LEDs";
    longDescription = ''
      Out-of-tree I2C LED driver for UGREEN DX/DXP series NAS units.  After
      loading, the front-panel LEDs appear as Linux LED class devices under
      /sys/class/leds/ (power, netdev, disk1–disk8), which the monitoring
      daemons from ugreen-leds-utils then use to drive activity blinking and
      link-state colour coding.
    '';
    homepage = "https://github.com/miskcoo/ugreen_leds_controller";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
