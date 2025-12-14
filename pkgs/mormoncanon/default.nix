{ pkgs }:

(pkgs.callPackage ../php-mysql-site { }) {
  pname = "mormoncanon";
  rev = "fb2a5b335a962a5d2253f7859695b19e59f80b7c";
  hash = "sha256-goRqkiM0UflCeVCJ3ErMQ4AY/QXB8UZwQICYu6/ILxY=";
  sqlRev = "0febf21b3709577989957c856fda679b06d320d2";
  sqlHash = "sha256-TGxWVoGxJWfa4cJMZ6e3fmtQxqJQo3haLZAwx5Fxq5I=";
  envPrefix = "MORMONCANON";
  phpNamespace = "MormonCanon";
  homepage = "https://gitlab.com/nocoolnametom/mormoncanon";
}
