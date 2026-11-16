{
  lib,
  buildGoModule,
  fetchFromGitHub,
  libX11,
}:
buildGoModule rec {
  pname = "slk";
  version = "unstable-2026-11-16";

  src = fetchFromGitHub {
    owner = "gammons";
    repo = "slk";
    rev = "cf7c0265b96f603af7cdbacc1b2b8b7b0a5cd049";
    # NAR hash of the unpacked source directory (nixpkgs' fetchFromGitHub
    # verifies the unpacked tree, not the tarball file itself).
    hash = "sha256-zRSRJpaJp1MLyX+mPcexqoJbubvjkGPX9Ikl4Pxo+6c=";
  };

  # The only main package in the module — the equivalent of
  # `go install github.com/gammons/slk/cmd/slk@latest`.
  subPackages = [ "cmd/slk" ];

  # golang.design/x/clipboard (Ctrl+V paste-to-upload) talks to X11 via cgo.
  buildInputs = [ libX11 ];

  # Same build stamps upstream's GoReleaser injects, so `slk --version`
  # reports the real commit instead of "slk dev (commit none)".
  ldflags = [
    "-s"
    "-w"
    "-X"
    "main.version=${version}"
    "-X"
    "main.commit=${lib.substring 0 12 src.rev}"
    "-X"
    "main.date=2026-11-16"
  ];

  # Taken from upstream's own flake.nix at the same commit: the vendor
  # directory is generated with `go mod vendor` and verified against this hash.
  vendorHash = "sha256-VPmvgB8BkjI3DOdl4XMqT0nxXKdz/v0Hs06veKtfvoY=";

  # The test suite spins up httptest servers on loopback. The macOS Nix
  # sandbox denies all networking by default, so allow loopback there; the
  # attribute is a no-op on Linux.
  __darwinAllowLocalNetworking = true;

  meta = {
    description = "Blazingly fast Slack TUI (desktop-client replacement)";
    longDescription = ''
      Keyboard-driven Slack client written in Go with bubbletea: real-time over
      WebSocket, SQLite-backed scrollback, multi-workspace support, and
      automatic auth from the Slack desktop app or a browser session.
    '';
    homepage = "https://github.com/gammons/slk";
    license = lib.licenses.mit;
    mainProgram = "slk";
    # Pure Go plus the X11 clipboard extension; upstream ships darwin/linux/windows builds.
    platforms = lib.platforms.all;
  };
}
