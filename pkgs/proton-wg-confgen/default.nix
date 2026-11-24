{
  lib,
  python3,
  writeShellApplication,
  writeText,
}:

# Headless WireGuard config generator for Proton VPN, built on Proton's own
# client library (proton-vpn-api-core). Signs in with a stored password, keeps
# a persistent WireGuard key whose certificate it renews, and picks a live
# server from the API's server list. See the script's docstring for details.
let
  python =
    (python3.override {
      packageOverrides = _final: prev: {
        proton-core = prev.proton-core.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace proton/session/srp/util.py \
              --replace-fail 'bcrypt.hashpw(password,' 'bcrypt.hashpw(password[:72],'
          '';
        });
      };
    }).withPackages
      (
        ps: with ps; [
          proton-vpn-api-core
          pyotp
          packaging # imported by proton-vpn-api-core but not propagated by it
          distro
        ]
      );
in
writeShellApplication {
  name = "proton-wg-confgen";

  runtimeInputs = [ python ];

  text = ''
    exec ${python.interpreter} ${writeText "proton-wg-confgen.py" (builtins.readFile ./proton-wg-confgen.py)} "$@"
  '';

  meta = {
    description = "Generate WireGuard configurations for Proton VPN servers without the desktop client";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "proton-wg-confgen";
  };
}
