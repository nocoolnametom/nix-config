{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "n8n-oidc";
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "kavdau";
    repo = "n8n-oidc";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BWDlwcCt+L1t7Q+f2s+m6wSVLNuzzaNOlD9e8D5Dwfk=";
  };

  # A single CommonJS file that n8n loads at runtime; it only uses Node's
  # built-in modules and the n8n installation it runs inside, so there is
  # nothing to build.
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 hooks.js $out/lib/n8n-oidc/hooks.js
    install -Dm644 -t $out/share/doc/n8n-oidc README.md CHANGELOG.md LICENSE.md
    runHook postInstall
  '';

  meta = {
    description = "External hook adding OpenID Connect sign-in to self-hosted n8n";
    longDescription = ''
      Loaded through n8n's EXTERNAL_HOOK_FILES. Registers /auth/oidc/login and
      /auth/oidc/callback, serves a frontend script that adds a sign-in button
      (EXTERNAL_FRONTEND_HOOKS_URLS=/assets/oidc-frontend-hook.js), and matches
      identity-provider users to n8n users by verified email. Uses n8n
      internals, so each release targets a range of n8n 2.x versions.
    '';
    homepage = "https://github.com/kavdau/n8n-oidc";
    changelog = "https://github.com/kavdau/n8n-oidc/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
