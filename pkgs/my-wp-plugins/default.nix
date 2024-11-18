{ pkgs, ... }:

let
  plugins = {
    # To get a hash run:
    # nix-prefetch-url --unpack https://downloads.wordpress.org/plugins/<name>.<version>.zip
    classic-editor = {
      version = "1.6.5";
      sha256 = "0rcsa7j31qs2xm098kg6kijyl0xff55w1bxddy0gxrwxbmsrjx0q";
    };
    column-shortcodes = {
      version = "1.0.1";
      sha256 = "04bsr02iazj2indwdg6nrjn9dszknvci39899kz0g3kbn4wgv2f3";
    };
    simple-csv-tables = {
      version = "1.0.3";
      url = "https://downloads.wordpress.org/plugins/simple-csv-tables.zip";
      sha256 = "0aghic2mxljbwir35rvgbz3s0zwys4844svjnmlpad2l8viwvabf";
    };
    youtube-embed-plus = {
      version = "14.2.1.2";
      sha256 = "0lgcj85nbdf1145igs0bsxng1f8mfb72ij8za2yvcp3xj3v7zg2s";
    };
    wpdatatables = {
      version = "3.4.2.30";
      sha256 = "0rfzgrsxn0zvwjg67qnbg9iqw2f35i1235csnh3495020l63cjs9";
    };
  };
  mkPlugin =
    pluginName:
    {
      version,
      sha256,
      url ? "https://downloads.wordpress.org/plugins/${pluginName}.${version}.zip",
    }:
    pkgs.stdenvNoCC.mkDerivation rec {
      inherit pluginName version;
      name = "wp-plugin-${pluginName}";
      src = pkgs.fetchzip {
        inherit sha256 url;
      };
      installPhase = "mkdir -p $out; cp -R * $out/";
    };
in
pkgs.lib.mapAttrs (name: buildInfo: mkPlugin name buildInfo) plugins
