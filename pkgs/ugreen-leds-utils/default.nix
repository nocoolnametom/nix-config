###############################################################################
#
#  ugreen-leds-utils
#
#  Userspace monitoring daemons for UGREEN DX/DXP NAS front-panel LEDs.
#  Requires the led-ugreen kernel module (pkgs/ugreen-leds-kmod) to be loaded
#  so that the LEDs appear under /sys/class/leds/.
#
#  Provides:
#    ugreen-diskiomon     – daemon: blinks disk-bay LEDs on I/O; colours by
#                           SMART health and standby state
#    ugreen-netdevmon     – daemon: tracks link state and gateway reachability
#                           for the front-panel network LED
#    ugreen-probe-leds    – oneshot: registers the I2C device at 0x3a with the
#                           led-ugreen driver (run this before the daemons)
#
#  Internal helpers (in $out/libexec/, not intended for direct use):
#    ugreen-blink-disk    – polls /sys/block/sdX/stat and fires LED shots
#    ugreen-check-standby – probes a disk's ATA power state via ioctl
#
#  Runtime configuration (read at startup if present):
#    /etc/ugreen-leds.conf   – colours, intervals, disk mapping; see the
#                              installed example at $out/share/ugreen-leds-utils/
#
###############################################################################

{
  lib,
  stdenv,
  fetchFromGitHub,
  bash,
  bc,
  coreutils,
  dmidecode,
  i2c-tools,
  iproute2,
  iputils,
  kmod,
  linuxHeaders,
  makeWrapper,
  smartmontools,
  util-linux,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ugreen-leds-utils";
  version = "0.3";

  src = fetchFromGitHub {
    owner = "miskcoo";
    repo = "ugreen_leds_controller";
    tag = "v${finalAttrs.version}";
    # Same tarball as the nixpkgs ugreen-leds-cli package (v0.3).
    hash = "sha256-eSTOUHs4y6n4cacpjQAp4JIfyu40aBJEMsvuCN6RFZc=";
  };

  # We work from the top of the tree so we can reach scripts/ for both the
  # bash scripts and the C++ sources.  No Makefile at the scripts level.
  sourceRoot = "${finalAttrs.src.name}";

  nativeBuildInputs = [
    makeWrapper
    # linux/hdreg.h is needed by check-standby.cpp for the HDIO_GET_IDENTITY
    # ioctl that probes ATA power mode.
    linuxHeaders
  ];

  buildInputs = [ bash ];

  buildPhase = ''
    runHook preBuild

    # blink-disk: reads /sys/block/<dev>/stat and fires LED oneshot pulses.
    # No external headers needed beyond the C++17 standard library.
    $CXX -std=c++17 -O2 -o ugreen-blink-disk scripts/blink-disk.cpp -pthread

    # check-standby: sends HDIO_GET_IDENTITY via ioctl to detect ATA standby.
    # linux/hdreg.h is provided by linuxHeaders.
    $CXX -std=c++17 -O2 -o ugreen-check-standby scripts/check-standby.cpp \
      -I${linuxHeaders}/include

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Internal helper binaries — called by the daemons via BLINK_MON_PATH /
    # STANDBY_MON_PATH, not meant to be run by hand.
    install -Dm755 ugreen-blink-disk    "$out/libexec/ugreen-blink-disk"
    install -Dm755 ugreen-check-standby "$out/libexec/ugreen-check-standby"

    # Stage the bash scripts before wrapping so makeWrapper has a real file to
    # read; it refuses to wrap a wrapper.
    install -Dm755 scripts/ugreen-diskiomon  "$out/share/ugreen-leds-utils/ugreen-diskiomon"
    install -Dm755 scripts/ugreen-netdevmon  "$out/share/ugreen-leds-utils/ugreen-netdevmon"
    install -Dm755 scripts/ugreen-probe-leds "$out/share/ugreen-leds-utils/ugreen-probe-leds"

    # Ship the example configuration so users have a reference for
    # /etc/ugreen-leds.conf without needing to visit the upstream repo.
    install -Dm644 scripts/ugreen-leds.conf \
      "$out/share/ugreen-leds-utils/ugreen-leds.conf.example"

    # ── ugreen-diskiomon ─────────────────────────────────────────────────────
    # Override default helper-binary paths with the Nix store paths so the
    # daemon always finds the right binaries regardless of PATH.
    makeWrapper "$out/share/ugreen-leds-utils/ugreen-diskiomon" \
      "$out/bin/ugreen-diskiomon" \
      --set   BLINK_MON_PATH   "$out/libexec/ugreen-blink-disk" \
      --set   STANDBY_MON_PATH "$out/libexec/ugreen-check-standby" \
      --prefix PATH : "${
        lib.makeBinPath [
          bash
          coreutils
          dmidecode
          kmod
          smartmontools
          util-linux
        ]
      }"

    # ── ugreen-netdevmon ─────────────────────────────────────────────────────
    # Takes the network interface name as $1 (e.g. ugreen-netdevmon enp2s0).
    makeWrapper "$out/share/ugreen-leds-utils/ugreen-netdevmon" \
      "$out/bin/ugreen-netdevmon" \
      --prefix PATH : "${
        lib.makeBinPath [
          bash
          bc
          coreutils
          iproute2
          iputils
          kmod
        ]
      }"

    # ── ugreen-probe-leds ────────────────────────────────────────────────────
    # Oneshot init: detects the SMBus I801 adapter and registers led-ugreen at
    # I2C address 0x3a so the LED class devices appear under /sys/class/leds/.
    makeWrapper "$out/share/ugreen-leds-utils/ugreen-probe-leds" \
      "$out/bin/ugreen-probe-leds" \
      --prefix PATH : "${
        lib.makeBinPath [
          bash
          coreutils
          i2c-tools
          kmod
        ]
      }"

    runHook postInstall
  '';

  meta = {
    description = "Monitoring daemons for UGREEN NAS front-panel LEDs";
    longDescription = ''
      Userspace side of the UGREEN NASync LED controller stack.  The three
      installed programs drive the front-panel LEDs when the led-ugreen kernel
      module is loaded:

        ugreen-probe-leds   Run once at boot (oneshot service) to register the
                            I2C device; all other services depend on this.

        ugreen-diskiomon    Long-running daemon that reflects disk I/O activity,
                            SMART health and standby state on the bay LEDs.

        ugreen-netdevmon    Long-running daemon that reflects network link state
                            and optional gateway reachability on the netdev LED.

      Copy $out/share/ugreen-leds-utils/ugreen-leds.conf.example to
      /etc/ugreen-leds.conf and edit it to customise colours and intervals.

      Note: Linux-only in practice (sysfs LED class, ATA ioctls, I2C), but
      meta.platforms is not restricted so it can be included in multi-platform
      package sets without evaluation errors.  Builds will be delegated to a
      Linux builder when invoked on macOS.
    '';
    homepage = "https://github.com/miskcoo/ugreen_leds_controller";
    license = lib.licenses.mit;
    mainProgram = "ugreen-diskiomon";
  };
})
