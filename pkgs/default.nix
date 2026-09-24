# You can build these directly using 'nix build .#example'

{
  pkgs ? import <nixpkgs> { },
  inputs,
  ...
}:

rec {

  #################### Packages with external source ############################
  # These need to all be direct derivations for `nix flake check` to work!

  display-info = pkgs.callPackage ./display-info { };
  split-my-cbz = pkgs.callPackage ./split-my-cbz { };
  stash-vr = pkgs.callPackage ./stash-vr { };
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  update-cbz-tags = pkgs.callPackage ./update-cbz-tags { };
  mormoncanon = pkgs.callPackage ./mormoncanon { };
  mormonquotes = pkgs.callPackage ./mormonquotes { };
  journalofdiscourses = pkgs.callPackage ./journalofdiscourses { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
  whisparr-eros = pkgs.callPackage ./whisparr-eros { };
  yknotify = pkgs.callPackage ./yknotify { };

  # UGREEN NASync LED userspace daemons (diskiomon, netdevmon, probe-leds).
  # Linux-only (sysfs LED class and ATA ioctls); no meta.platforms restriction
  # is set so it evaluates on all systems — it will be sent to the Linux remote
  # builder when invoked from macOS.
  # The companion kernel module (led-ugreen) lives in pkgs/ugreen-leds-kmod/
  # and must be called via boot.kernelPackages.callPackage from a NixOS module
  # because it requires a specific kernel version — it cannot be a flat package.
  ugreen-leds-utils = pkgs.callPackage ./ugreen-leds-utils { };

}
