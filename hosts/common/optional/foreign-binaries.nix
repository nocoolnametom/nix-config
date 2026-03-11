{ lib, ... }:
{
  # Allow pre-built FHS-expecting binaries to run on NixOS.
  # NixOS's store layout doesn't match the standard Linux FHS, so pre-built
  # binaries (VSCode remote server, Cursor IDE, closed-source tools) can't
  # find their dynamic linker. nix-ld provides a shim that makes them work.
  programs.nix-ld.enable = lib.mkDefault true;

  # Register AppImage as a directly-runnable executable format.
  programs.appimage.binfmt = lib.mkDefault true;
}
