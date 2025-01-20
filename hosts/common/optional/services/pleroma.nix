{
  config,
  lib,
  configVars,
  ...
}:
{
  services.pleroma.enable = lib.mkDefault true;
  services.pleroma.configs = [
    ''
      #----------Imported Base Config---------------------#
      import Config
    ''

    ''
      #----------------------------------#
    ''

    ''
      config :pleroma, Pleroma.Web.Endpoint,
        url: [host: "${configVars.domain}", scheme: "https", port: 443],
        http: [ip: {127, 0, 0, 1}, port: 4000]

      config :pleroma, :instance,
        name: "NoCoolNameTom",
        email: "${configVars.email.user}",
        notify_email: "${configVars.email.alerts}",
        limit: 5000,
        # MAKE THIS FALSE AFTER REGISTERING YOURSELF!! -----
        # registrations_open: false # ----------------------
        registrations_open: true # -------------------------
        # --------------------------------------------------

      config :pleroma, :media_proxy,
        enabled: false,
        redirect_on_failure: true
        #base_url: "https://cache.pleroma.social"

      config :pleroma, Pleroma.Repo,
        adapter: Ecto.Adapters.Postgres,
        username: "${config.services.pleroma.user}",
        database: "${config.services.pleroma.user}",
        hostname: "localhost"

      config :web_push_encryption, :vapid_details,
        subject: "mailto:${configVars.email.user}"

      config :pleroma, :database, rum_enabled: false
      config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"
      config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"

      # config :pleroma, Pleroma.Upload, filters: [Pleroma.Upload.Filter.Exiftool]

      config :ex_aws, :s3,
        region: "us-west-2"

      # Enable Strict-Transport-Security once SSL is working:
      config :pleroma, :http_security,
        sts: true

      config :pleroma, configurable_from_database: true
    ''
  ];
  services.pleroma.secretConfigFile = "/var/lib/pleroma/secrets.exs";

  services.nginx.virtualHosts."${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:4000";
    locations."/".recommendedProxySettings = true;
    locations."/".proxyWebsockets = true;
  };
  services.nginx.virtualHosts."www.${configVars.domain}" = {
    forceSSL = true;
    enableACME = true;
    # TODO: You should be able to safely change this to a 301 at any point in the future
    locations."/".return = "302 https://${configVars.domain}\$request_uri";
  };

  sops.secrets."pleroma/secret_key_base" = { };
  sops.secrets."pleroma/signing_salt" = { };
  sops.secrets."pleroma/password" = { };
  sops.secrets."pleroma/public_key" = { };
  sops.secrets."pleroma/private_key" = { };
  sops.secrets."pleroma/default_signer" = { };
  sops.templates."pleroma-secrets" = {
    content = ''
      config :pleroma, Pleroma.Web.Endpoint,
        secret_key_base: "${config.sops.placeholder."pleroma/secret_key_base"}",
        signing_salt: "${config.sops.placeholder."pleroma/signing_salt"}"

      config :pleroma, Pleroma.Repo,
        password: "${config.sops.placeholder."pleroma/password"}"

      config :web_push_encryption, :vapid_details,
        public_key: "${config.sops.placeholder."pleroma/public_key"}",
        private_key: "${config.sops.placeholder."pleroma/private_key"}"

      config :joken, default_signer: "${config.sops.placeholder."pleroma/default_signer"}"
    '';
    path = config.services.pleroma.secretConfigFile;
  };
}
