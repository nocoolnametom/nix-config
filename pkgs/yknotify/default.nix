{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "yknotify";
  version = "unstable-2026-03-24";

  src = fetchFromGitHub {
    owner = "noperator";
    repo = "yknotify";
    rev = "0c773bdadedb137d02d95c79430fa5e0442c9950";
    hash = "sha256-AhTr3lzYS6z1XoqVC2IIdJoDVdWajrbGhOe20dVQrGQ=";
  };

  # Upstream has no external Go dependencies.
  vendorHash = null;

  meta = {
    description = "Notify when YubiKey needs touch on macOS";
    homepage = "https://github.com/noperator/yknotify";
    platforms = lib.platforms.darwin;
    mainProgram = "yknotify";
  };
}
