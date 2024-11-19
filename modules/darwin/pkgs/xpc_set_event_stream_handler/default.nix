{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
  runCommand ? pkgs.runCommand,
  ...
}:

let
  buildSymlinks = runCommand "macvim-build-symlinks" { } ''
    mkdir -p $out/bin
    ln -s /usr/bin/gcc $out/bin
  '';

in
stdenv.mkDerivation {
  name = "XPCEventStreamHandler";
  src = ./.;

  nativeBuildInputs = [ buildSymlinks ];

  sandboxProfile = ''
    (allow file-read* file-write* process-exec mach-lookup)
    ; block homebrew dependencies
    (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
  '';

  buildPhase = "gcc -framework Foundation -o xpc_set_event_stream_handler xpc_set_event_stream_handler.m";

  installPhase = ''
    mkdir -p $out/bin
    cp xpc_set_event_stream_handler $out/bin/
  '';

  meta = with lib; {
    description = "Consume a com.apple.iokit.matching event, then run the executable specified in the first parameter.";
    homepage = "https://github.com/snosrap/xpc_set_event_stream_handler";
    platforms = platforms.darwin;
    license = [ licenses.mit ];
    maintainers = [ maintainers.eqyiel ];
  };
}
