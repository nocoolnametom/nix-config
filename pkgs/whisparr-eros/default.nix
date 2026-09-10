#
# Whisparr-Eros (Whisparr V3) - the Radarr-derived sibling of the Sonarr-derived
# `whisparr` in nixpkgs. Upstream ships prebuilt release tarballs but, unlike
# nixpkgs' `whisparr`, only self-contained builds (the .NET runtime is bundled),
# so this wraps the vendored apphost via autoPatchelfHook instead of `dotnet`.
#
# Run ./update_hashes.sh to bump the version and hashes.
#
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,

  curl,
  icu,
  krb5,
  libmediainfo,
  openssl,
  sqlite,
  zlib,

  # Replace the vendored ffprobe binary with a symlink to the servarr-ffmpeg
  # package, the same trade nixpkgs' radarr makes.
  withFFmpeg ? true,
  servarr-ffmpeg,
  ...
}:

let
  pkgVersion = "3.5.0";
  pkgBuild = "1585";
  version = "${pkgVersion}.${pkgBuild}";

  # Upstream tags and release assets carry the build channel as an infix, e.g.
  # tag `v3.5.0-release.1585` holds `Whisparr.eros.3.5.0-release.1585.linux-x64.tar.gz`.
  urlVersion = "${pkgVersion}-release.${pkgBuild}";

  platforms = {
    aarch64-darwin = {
      name = "osx-arm64";
      hash = "sha256-J/r5MNuPUSah7LvnhYuC7wJCK3udF94+GI68VmBXpXE=";
    };
    aarch64-linux = {
      name = "linux-arm64";
      hash = "sha256-ijhKAZwQcRkyVeaF9fVX1fOp5fxKlsWxDKp0Tt23A8w=";
    };
    x86_64-darwin = {
      name = "osx-x64";
      hash = "sha256-3ujmQIVBYWyRgtfueDmF28wRwK5p5m7kASmUSQ8RzuM=";
    };
    x86_64-linux = {
      name = "linux-x64";
      hash = "sha256-TCk8wXMqeHO8rklcoWuxEsXGCT53x0lUXh2i0YCdpr0=";
    };
  };

  plat =
    if (lib.hasAttrByPath [ stdenv.hostPlatform.system ] platforms) then
      platforms.${stdenv.hostPlatform.system}
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.system}";

  # Servarr apps dlopen these rather than linking them, so they're invisible to
  # autoPatchelf and have to be handed to the process at runtime: ICU for
  # globalization, OpenSSL for TLS, krb5 for Negotiate/NTLM auth, libmediainfo
  # for media probing.
  runtimeLibs = lib.makeLibraryPath [
    curl
    icu
    krb5
    libmediainfo
    openssl
    sqlite
    zlib
  ];

  libraryPathVar = if stdenv.hostPlatform.isDarwin then "DYLD_LIBRARY_PATH" else "LD_LIBRARY_PATH";

  shareDir = "share/whisparr-eros-${version}";
in
stdenv.mkDerivation {
  pname = "whisparr-eros";
  inherit version;

  src = fetchurl {
    name = "whisparr-eros-${urlVersion}-${plat.name}.tar.gz";
    url = "https://github.com/Whisparr/Whisparr-Eros/releases/download/v${urlVersion}/Whisparr.eros.${urlVersion}.${plat.name}.tar.gz";
    inherit (plat) hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    # The in-place updater must not be reachable: NixOS owns this package.
    rm -rf Whisparr.Update

    # The only bundled library that pulls in a dependency outside the .NET
    # runtime (lttng-ust). It provides LTTng tracing hooks and coreclr silently
    # skips it when absent.
    rm -f libcoreclrtraceptprovider.so

    mkdir -p $out/bin $out/${shareDir}
    cp -r * $out/${shareDir}/
  ''
  + lib.optionalString withFFmpeg ''
    rm -f $out/${shareDir}/ffprobe
    ln -s ${lib.getExe' servarr-ffmpeg "ffprobe"} $out/${shareDir}/ffprobe
  ''
  + ''
    # Named Whisparr-Eros so it can coexist with pkgs.whisparr's `Whisparr`.
    makeWrapper $out/${shareDir}/Whisparr $out/bin/Whisparr-Eros \
      --prefix ${libraryPathVar} : ${runtimeLibs}

    runHook postInstall
  '';

  meta = {
    description = "Adult scene collection manager for Usenet and BitTorrent users (Whisparr V3)";
    longDescription = ''
      Whisparr-Eros is the V3 line of Whisparr, built on the Radarr codebase,
      as opposed to the V2 line (nixpkgs' `whisparr`) built on Sonarr's.
    '';
    homepage = "https://github.com/Whisparr/Whisparr-Eros";
    changelog = "https://github.com/Whisparr/Whisparr-Eros/releases/tag/v${urlVersion}";
    license = lib.licenses.gpl3Only;
    platforms = builtins.attrNames platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "Whisparr-Eros";
  };
}
