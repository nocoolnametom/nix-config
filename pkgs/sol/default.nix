{
  lib,
  stdenvNoCC,
  fetchurl,
  writeShellApplication,
  cacert,
  curl,
  jq,
  openssl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sol";
  version = "2.1.269";

  src = fetchurl {
    name = "sol.zip";
    url = "https://github.com/ospfranco/sol/releases/download/${finalAttrs.version}/${finalAttrs.version}.zip";
    hash = "sha256-yQ2Iq5pw68WC2aSW3+AjnhBq9h2uJqGuaSq4qOazqGE=";
  };

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  nativeBuildInputs = [ unzip ];

  sourceRoot = "Sol.app";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications/Sol.app
    cp -R . $out/Applications/Sol.app

    runHook postInstall
  '';

  meta = {
    description = "Control your tools with a few keystrokes open-source style";
    homepage = "https://sol.ospfranco.com/";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
