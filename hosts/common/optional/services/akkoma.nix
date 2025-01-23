{
  config,
  configVars,
  lib,
  pkgs,
  ...
}:
let
  proxyLocs = akkomaDomain: {
    "~ ^/(media|proxy)" = {
      extraConfig = ''
        proxy_cache akkoma_media_cache;

        # Cache objects in slices of 1 MiB
        slice 1m;
        proxy_cache_key $host$uri$is_args$args$slice_range;
        proxy_set_header Range $slice_range;
        chunked_transfer_encoding on;

        # Decouple proxy and upstream responses
        proxy_buffering on;
        proxy_cache_lock on;
        proxy_ignore_client_abort on;

        # Default cache times for various responses
        # Can switch the lifetimes once working
        proxy_cache_valid  200 206 301 304 1h;
        # proxy_cache_valid 200 1y;
        # proxy_cache_valid 206 301 304 1h;

        # Allow serving of stale items
        proxy_cache_use_stale error timeout invalid_header updating;
      '';
      proxyPass = "http://unix:/run/akkoma/socket";
    };
    "/" = {
      return = "301 https://${akkomaDomain}\$request_uri";
    };
  };
  configScriptPost =
    pkgs.writeShellApplication {
      text = ''
        echo Running configScriptPost
        cd "$RUNTIME_DIRECTORY"
        echo "# configScriptPost patches:" >> config.exs
        echo "config :pleroma, configurable_from_database: true" >> config.exs
        echo Done patching the config!
      '';
      name = "configScriptPost";
    }
    + "/bin/configScriptPost";
in
{
  services.akkoma.enable = lib.mkDefault true;

  services.akkoma.config =
    let
      secrets = config.sops.secrets;
    in
    {
      ":pleroma".":instance" = {
        name = lib.mkDefault configVars.handles.oldHandle;
        description = lib.mkDefault "More detailed description";
        email = lib.mkDefault configVars.email.user;
        notify_email = lib.mkDefault configVars.email.alerts;
        limit = lib.mkDefault 5000;
        registration_open = lib.mkDefault false;
      };

      ":pleroma".":media_proxy" = {
        enabled = lib.mkDefault true;
        proxy_opts.redirect_on_failure = lib.mkDefault true;
        base_url = lib.mkDefault "https://cache.${
          config.services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host
        }/";
      };

      ":pleroma".":mrf".policies = map (pkgs.formats.elixirConf { }).lib.mkRaw [
        "Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy"
      ];

      ":pleroma".":media_preview_proxy" = {
        enabled = lib.mkDefault true;
        thumbnail_max_width = lib.mkDefault 1920;
        thumbnail_max_height = lib.mkDefault 1080;
      };

      ":pleroma"."Pleroma.Upload" = {
        base_url = lib.mkDefault "https://media.${
          config.services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host
        }/media/";
      };

      ":pleroma"."Pleroma.Uploaders.Local" = {
        uploads = lib.mkDefault "/var/lib/akkoma/uploads";
      };
      ":pleroma"."Pleroma.Web.Endpoint" = {
        url.host = lib.mkDefault configVars.domain;
        secret_key_base = lib.mkDefault {
          _secret = secrets."pleroma/secret_key_base".path;
        };
        signing_salt = lib.mkDefault {
          _secret = secrets."pleroma/signing_salt".path;
        };
      };
      ":joken".":default_signer" = lib.mkDefault {
        _secret = secrets."pleroma/default_signer".path;
      };
      ":web_push_encryption".":vapid_details" = {
        subject = lib.mkDefault "mailto:${configVars.email.user}";
        private_key = lib.mkDefault {
          _secret = secrets."pleroma/private_key".path;
        };
        public_key = lib.mkDefault {
          _secret = secrets."pleroma/public_key".path;
        };
      };
    };

  # Adds the configurable via database option to the config.exs
  # systemd.services.akkoma-config.serviceConfig.ExecStart = lib.mkMerge [ [ configScriptPost ] ];
  # systemd.services.akkoma-config.serviceConfig.ExecReload = lib.mkMerge [ [ configScriptPost ] ];

  services.akkoma.nginx = {
    enableACME = true;
    forceSSL = true;
    locations."~ ^/(media|proxy)" = {
      proxyPass = "http://unix:/run/akkoma/socket";
    };
  };

  services.nginx =
    let
      vhosts = akkomaDomain: {
        "www.${akkomaDomain}" = {
          forceSSL = true;
          enableACME = true;
          globalRedirect = akkomaDomain;
        };
        "${configVars.handles.mastodon}.${akkomaDomain}" = {
          forceSSL = true;
          enableACME = true;
          globalRedirect = "${akkomaDomain}/users/${configVars.handles.mastodon}";
        };
        "private.${akkomaDomain}" = {
          forceSSL = true;
          enableACME = true;
          globalRedirect = "${akkomaDomain}/users/${configVars.handles.oldHandle}_Private";
        };
        "cache.${akkomaDomain}" = {
          forceSSL = true;
          enableACME = true;
          locations = proxyLocs akkomaDomain;
        };
        "media.${akkomaDomain}" = {
          forceSSL = true;
          enableACME = true;
          locations = proxyLocs akkomaDomain;
        };
      };
    in
    {
      enable = true;

      clientMaxBodySize = "16m";
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      # Adjust the persistent cache size as needed:
      #  Assuming an average object size of 128 KiB, around 1 MiB
      #  of memory is required for the key zone per GiB of cache.
      # Ensure that the cache directory exists and is writable by nginx.
      commonHttpConfig = ''
        proxy_cache_path /var/cache/nginx/cache/akkoma-media-cache
          levels= keys_zone=akkoma_media_cache:16m max_size=16g
          inactive=1y use_temp_path=off;
      '';
      virtualHosts = vhosts config.services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host;
    };

  sops.secrets."pleroma/secret_key_base" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
  sops.secrets."pleroma/signing_salt" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
  sops.secrets."pleroma/password" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
  sops.secrets."pleroma/public_key" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
  sops.secrets."pleroma/private_key" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
  sops.secrets."pleroma/default_signer" = {
    owner = config.services.akkoma.user;
    group = config.services.akkoma.group;
  };
}
