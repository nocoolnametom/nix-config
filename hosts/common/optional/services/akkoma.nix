{
  config,
  configVars,
  lib,
  pkgs,
  ...
}:
let
  proxyLocs = {
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
      return = "301 https://${configVars.domain}\$request_uri";
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
        name = "NoCoolNameTom";
        description = "More detailed description";
        email = configVars.email.user;
        notify_email = configVars.email.alerts;
        limit = 5000;
        registration_open = false;
      };

      ":pleroma".":media_proxy" = {
        enabled = true;
        proxy_opts.redirect_on_failure = true;
        base_url = "https://cache.${configVars.domain}/";
      };

      ":pleroma".":mrf".policies = map (pkgs.formats.elixirConf { }).lib.mkRaw [
        "Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy"
      ];

      ":pleroma".":media_preview_proxy" = {
        enabled = true;
        thumbnail_max_width = 1920;
        thumbnail_max_height = 1080;
      };

      ":pleroma"."Pleroma.Upload" = {
        base_url = "https://media.${configVars.domain}/media/";
      };

      ":pleroma"."Pleroma.Uploaders.Local" = {
        uploads = "/var/lib/akkoma/uploads";
      };
      ":pleroma"."Pleroma.Web.Endpoint" = {
        url.host = configVars.domain;
        secret_key_base = {
          _secret = secrets."pleroma/secret_key_base".path;
        };
        signing_salt = {
          _secret = secrets."pleroma/signing_salt".path;
        };
      };
      ":joken".":default_signer" = {
        _secret = secrets."pleroma/default_signer".path;
      };
      ":web_push_encryption".":vapid_details" = {
        subject = "mailto:${configVars.email.user}";
        private_key = {
          _secret = secrets."pleroma/private_key".path;
        };
        public_key = {
          _secret = secrets."pleroma/public_key".path;
        };
      };
    };

  # Adds the configurable via database option to the config.exs
  systemd.services.akkoma-config.serviceConfig.ExecStart = lib.mkMerge [ [ configScriptPost ] ];
  systemd.services.akkoma-config.serviceConfig.ExecReload = lib.mkMerge [ [ configScriptPost ] ];

  services.akkoma.nginx = {
    enableACME = true;
    forceSSL = true;
    locations."~ ^/(media|proxy)" = {
      proxyPass = "http://unix:/run/akkoma/socket";
    };
  };

  services.nginx = {
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
  };

  services.nginx.virtualHosts."www.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return = "301 https://${configVars.domain}\$request_uri";
  };

  services.nginx.virtualHosts."tom.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return = "301 https://${configVars.domain}/users/tom\$request_uri";
  };

  services.nginx.virtualHosts."private.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return =
      "301 https://${configVars.domain}/users/NoCoolName_Tom_Private/\$request_uri";
  };

  services.nginx.virtualHosts."cache.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations = proxyLocs;
  };

  services.nginx.virtualHosts."media.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations = proxyLocs;
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
