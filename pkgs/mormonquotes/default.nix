{ pkgs }:

((pkgs.callPackage ../php-mysql-site { }) {
  pname = "mormonquotes";
  rev = "a9e5475235b48034454ed9b27192712bc2fa9150";
  hash = "sha256-cI4oM+gnkPVC2QHIX/ek8kE2pLKhYk3pGVUyCvzpSek=";
  sqlRev = "35bb21dcb79286633b80c8ab8cdf938b43be66ff";
  sqlHash = "sha256-+yisyO/cnpzvDdjvUn0MUMM34ADTq735hX6MqUmnQOk=";
  envPrefix = "MORMONQUOTES";
  phpNamespace = "MormonQuotes";
  homepage = "https://gitlab.com/nocoolnametom/mormonquotes";
}
).overrideAttrs (old: {
  # Patch PHP 8.4 deprecations inline until upstream updates
  postPatch = (old.postPatch or "") + ''
    sed -i \
      -e 's/$${author_id}/{$author_id}/g' \
      -e 's/WHERE stitch_tag_id = $${tag_id}/WHERE stitch_tag_id = {$tag_id}/g' \
      -e 's/public function build_regular_page($query, string $title, int $author_id = null): string/public function build_regular_page($query, string $title, ?int $author_id = null): string/' \
      -e 's/<title>{($${author_id} ? \"Quotes from \" : \"\") \. $${title})} | Mormon Quotes<\/title>/<title>{$author_id ? \"Quotes from \" : \"\"}{$title} | Mormon Quotes<\/title>/' \
      src/Display.php
  '';
})
