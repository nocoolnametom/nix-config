{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beszel-agent-bin";
  version = "0.18.4";

  # Upstream's prebuilt release binary (nixpkgs' `beszel` builds from source).
  src = fetchurl {
    url = "https://github.com/henrygd/beszel/releases/download/v${finalAttrs.version}/beszel-agent_linux_amd64.tar.gz";
    hash = "sha256-spjttayPRlN0aRtUr2wjmdWA2OvLUB/uURNw+nv5EPk=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # The tarball holds the bare binary, with no top-level directory.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 beszel-agent $out/bin/beszel-agent
    runHook postInstall
  '';

  meta = {
    description = "Lightweight server monitoring agent for Beszel (upstream release binary)";
    homepage = "https://github.com/henrygd/beszel";
    changelog = "https://github.com/henrygd/beszel/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "beszel-agent";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
