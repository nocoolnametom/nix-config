{
  lib,
  stdenv,
  fetchurl,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "smolcoder";
  version = "0.7.1";

  # npm tarballs are gzipped and unpack under a `package/` prefix
  src = fetchurl {
    url = "https://registry.npmjs.org/smolcoder/-/smolcoder-${finalAttrs.version}.tgz";
    hash = "sha256-Bjewjz49kdh+qrvKROL0kOhp3xmeeXJbH7NnJTOeSmI=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Override unpack so the tarball's `package/` root becomes the build root
  sourceRoot = "package";

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/smolcoder" "$out/bin"
    cp -r dist "$out/lib/smolcoder/"
    cp package.json "$out/lib/smolcoder/"
    # Wrap the pre-built JS entry point with node; expose both `smolcoder` and `smol`
    makeWrapper "${nodejs}/bin/node" "$out/bin/smolcoder" \
      --add-flags "$out/lib/smolcoder/dist/index.js"
    ln -s "$out/bin/smolcoder" "$out/bin/smol"
    runHook postInstall
  '';

  meta = {
    description = "Zero-config coding agent for local LLMs via Ollama or LM Studio";
    homepage = "https://github.com/leonvanzyl/smolcoder";
    license = lib.licenses.mit;
    mainProgram = "smolcoder";
    # Pure JS — runs anywhere Node does
    platforms = lib.platforms.all;
  };
})
