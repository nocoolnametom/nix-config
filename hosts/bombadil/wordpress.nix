{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # Testing WP Install
  services.wordpress.webserver = "nginx";
  services.nginx.virtualHosts."${configVars.friendBlogDomain}" = {
    # forceSSL = true;
    enableACME = true;
  };
  services.wordpress.sites."${configVars.friendBlogDomain}" = {
    database = {
      name = configVars.networking.blog.friends.name;
    };
    themes = {
      twentyten = pkgs.wp-theme-twentyten-ken;
    };
    plugins = {
      inherit (pkgs.wordpressPackages.plugins)
        akismet
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
      WP_DEBUG = true;
      WP_DEBUG_LOG = true;
    };
    extraConfig = ''
      ini_set( 'error_log', '/var/lib/wordpress/${configVars.friendBlogDomain}/debug.log' );
    '';
    package = pkgs.wordpress.overrideAttrs (oldAttrs: rec {
      installPhase =
        oldAttrs.installPhase
        + ''
          ln -s /var/lib/wordpress/${configVars.friendBlogDomain}/wpdatatables $out/share/wordpress/wp-content/wpdatatables
        '';
    });
  };
  systemd.tmpfiles.rules = [
    "d '/var/lib/wordpress/${configVars.friendBlogDomain}/wpdatatables' 0750 wordpress nginx - -"
  ];
}
