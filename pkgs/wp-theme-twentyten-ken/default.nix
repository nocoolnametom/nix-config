{
  lib,
  stdenvNoCC,
  wp-main,
  ...
}:
stdenvNoCC.mkDerivation rec {
  name = "${pname}-${version}";
  pname = "wp-theme-twentyten-ken";
  themeName = "twentyten";
  version = wp-main.rev;
  src = "${wp-main}/wp-content/themes/twentyten";

  dontConfigure = true;
  dontBuild = true;

  passthru = {
    wpName = pname;
  };

  loopSingleSearch = "editedByAddendum";
  loopSingleText = builtins.replaceStrings [ "$" ] [ "\\$" ] ''
    <?php
      $post_ID = get_the_ID();
      if ( $last_id = get_post_meta($post_ID, '_edit_last', true) ) {
        $last_user = get_userdata($last_id);
        printf(__('Last edited by %1$s on %2$s at %3$s'), wp_specialchars( $last_user->display_name ), mysql2date(get_option('date_format'), $post->post_modified), mysql2date(get_option('time_format'), $post->post_modified));
      };
    ?>
  '';
  hideVersionSearch = "hideVersionAddendum";
  hideVersionText = builtins.replaceStrings [ "$" ] [ "\\$" ] ''
    /**
    * Hides the WP version from being easily scraped from the page meta tags
    */
    function wpbeginner_remove_version() {
      return "";
    }
    add_filter('the_generator', 'wpbeginner_remove_version');
  '';
  singleSearch = "editedByAddendum";
  singleText = builtins.replaceStrings [ "$" ] [ "\\$" ] ''
    <?php
      $post_ID = get_the_ID();

      if ( $last_id = get_post_meta($post_ID, '_edit_last', true) ) {
        $last_user = get_userdata($last_id);
        printf(
          __('Last edited by %1$s on %2$s at %3$s'),
          wp_specialchars( $last_user->display_name ),
          mysql2date(get_option('date_format'),
          $post->post_modified),
          mysql2date(get_option('time_format'),
          $post->post_modified)
        );
      };
    ?>
  '';

  installPhase = ''
    runHook preInstall
    cp -R ./. $out

    sed -i 's%\(<!-- .entry-utility -->\)%\1@${loopSingleSearch}@%' $out/loop-single.php
    substituteInPlace $out/loop-single.php --subst-var-by ${loopSingleSearch} "${loopSingleText}"

    echo "" >> $out/functions.php
    echo "@${hideVersionSearch}@" >> $out/functions.php
    substituteInPlace $out/functions.php --subst-var-by ${hideVersionSearch} "${hideVersionText}"

    sed -i 's%\(<?php get_footer(); ?>\)%\1@${singleSearch}@%' $out/single.php
    substituteInPlace $out/single.php --subst-var-by ${singleSearch} "${singleText}"

    rm $out/readme.txt

    runHook postInstall
  '';

  meta = with lib; {
    description = "Twenty Ten WordPress theme with last edited by user and date";
    longDescription = ''
      This is the standard WordPress TwentyTen theme with some additional modifications.
      It is meant to be used by my friend's blog, and I wanted it to be easy to
      automatically update, so it's actually driven by one of the flake inputs so that
      getting an up-to-date version is as easy as updating the flake lock file.
      The files it edits have not been substantially changed for many years, so it's
      assumed they will remain able to be modified in this way for the foreseeable future.
    '';
    homepage = "https://github.com/WordPress/WordPress/tree/master/wp-content/themes/twentyten";
    license = licenses.gpl2;
    platforms = platforms.all;
  };
}
