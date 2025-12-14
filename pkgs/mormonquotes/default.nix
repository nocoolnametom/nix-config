{ pkgs }:

(pkgs.callPackage ../php-mysql-site { }) {
  pname = "mormonquotes";
  rev = "a9e5475235b48034454ed9b27192712bc2fa9150";
  hash = "sha256-cI4oM+gnkPVC2QHIX/ek8kE2pLKhYk3pGVUyCvzpSek=";
  sqlRev = "35bb21dcb79286633b80c8ab8cdf938b43be66ff";
  sqlHash = "sha256-+yisyO/cnpzvDdjvUn0MUMM34ADTq735hX6MqUmnQOk=";
  envPrefix = "MORMONQUOTES";
  phpNamespace = "MormonQuotes";
  homepage = "https://gitlab.com/nocoolnametom/mormonquotes";
}
