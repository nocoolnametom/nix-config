{
  inputs,
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # Testing WP Install
  services.wordpress.webserver = "nginx";
  services.nginx.virtualHosts."${inputs.nix-secrets.networking.blog.friends.domain}" = {
    forceSSL = true;
    enableACME = true;
  };
  services.phpfpm.pools."wordpress-${inputs.nix-secrets.networking.blog.friends.domain}".phpOptions = ''
    extension=${pkgs.phpExtensions.imagick}/lib/php/extensions/imagick.so
  '';
  services.wordpress.sites."${inputs.nix-secrets.networking.blog.friends.domain}" = {
    database = {
      name = configVars.networking.blog.friends.name;
    };
    themes = {
      twentyten = pkgs.myWpPlugins.wp-theme-twentyten-ken;
    };
    plugins = {
      inherit (pkgs.wordpressPackages.plugins)
        akismet
        disable-xml-rpc
        jetpack
        merge-minify-refresh
        simple-login-captcha
        wordpress-seo
        ;
      inherit (pkgs.myWpPlugins)
        classic-editor
        column-shortcodes
        # simple-csv-tables # Breaks for some reason - can't find a file that should be part of the plugin
        youtube-embed-plus
        wpdatatables
        ;
    };
    settings = {
      FORCE_SSL_ADMIN = true;
    };
    # Uncomment this to enable PHP logging debug messages to a debug.log file
    # extraConfig = ''
    #   ini_set( 'error_log', '/var/lib/wordpress/${inputs.nix-secrets.networking.blog.friends.domain}/debug.log' );
    # '';
    # The following writes errors DIRECTLY to the browser, only use as a last resort
    # extraConfig = ''
    #   ini_set( 'display_errors', 1 );
    #   ini_set( 'display_startup_errors', 1 );
    # '';
    extraConfig = ''
      $_SERVER['HTTPS'] = 'on';
    '';
    package = pkgs.wordpress.overrideAttrs (oldAttrs: rec {
      installPhase =
        oldAttrs.installPhase
        # These folders link writable on-disk storage to the WP Nix Store package so that WP can write to them
        # Make sure the folders have write access for the wordpress user as made by the systemd rules below
        + ''
          ln -s /var/lib/wordpress/${inputs.nix-secrets.networking.blog.friends.domain}/mmr          $out/share/wordpress/wp-content/mmr
          ln -s /var/lib/wordpress/${inputs.nix-secrets.networking.blog.friends.domain}/wpdatatables $out/share/wordpress/wp-content/wpdatatables
        '';
    });
  };
  systemd.tmpfiles.rules = [
    "d '/var/lib/wordpress/${inputs.nix-secrets.networking.blog.friends.domain}/mmr' 0750 wordpress nginx - -"
    "d '/var/lib/wordpress/${inputs.nix-secrets.networking.blog.friends.domain}/wpdatatables' 0750 wordpress nginx - -"
  ];
}
