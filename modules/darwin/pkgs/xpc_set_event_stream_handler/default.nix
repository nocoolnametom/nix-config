{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
  makeWrapper ? pkgs.makeWrapper,
}:

# This is a simple wrapper around the xpc_set_event_stream_handler executable.
# I had it building from the source code in the github repo referenced, but as
# of 24.11 it was refusing to build on darwin (it could not find the Foundation).
# I'm not sure why, but I'm not going to spend time on it right now. I'll just
# build it on my mac and copy the binary over to my repo.

stdenv.mkDerivation rec {
  name = "xpc_set_event_stream_handler";
  version = "1";

  # Rebuild this in darwin by the following command within this directory:
  # gcc -framework Foundation -o xpc_set_event_stream_handler src/main.m
  executable = ./xpc_set_event_stream_handler;

  dontUnpack = true;

  buildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper "${executable}" $out/bin/xpc_set_event_stream_handler --prefix PATH ":" "${
      lib.makeBinPath [
        stdenv.cc.cc
      ]
    }"
  '';

  meta = with lib; {
    description = "Consume a com.apple.iokit.matching event, then run the executable specified in the first parameter.";
    homepage = "https://github.com/snosrap/xpc_set_event_stream_handler";
    platforms = platforms.darwin;
    license = [ licenses.mit ];
    maintainers = [ maintainers.eqyiel ];
  };
}
