{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  emailDomainsPath = builtins.toString inputs.disposable-email-domains;
  emailDomainBlocklist = "${emailDomainsPath}/disposable_email_blocklist.conf";
in
{

  # For Elasticsearch service we store the password in sops: mastodon/<hostname>/elasticsearch-password
  # Expected username is elasticsearch-mastodon
  sops.secrets."elasticsearch-mastodon-password" = {
    key = "mastodon/${config.networking.hostName}/elasticsearch-password";
    owner = config.services.mastodon.user;
    group = config.services.mastodon.group;
    mode = "0600";
  };

  # For Mastodon we store the secret key base, vapid private key, and vapid public key in sops
  sops.secrets."mastodon-vapid-public-key" = {
    key = "mastodon/${config.networking.hostName}/vapid/public";
    owner = config.services.mastodon.user;
    group = config.services.mastodon.group;
    mode = "0600";
  };
  sops.secrets."mastodon-vapid-private-key" = {
    key = "mastodon/${config.networking.hostName}/vapid/private";
    owner = config.services.mastodon.user;
    group = config.services.mastodon.group;
    mode = "0600";
  };
  sops.secrets."mastodon-secret-key-base" = {
    key = "mastodon/${config.networking.hostName}/key-base";
    owner = config.services.mastodon.user;
    group = config.services.mastodon.group;
    mode = "0600";
  };
  sops.secrets."mastodon-otp-secret" = {
    key = "mastodon/${config.networking.hostName}/otp";
    owner = config.services.mastodon.user;
    group = config.services.mastodon.group;
    mode = "0600";
  };

  services.mastodon.enable = lib.mkDefault true;
  services.mastodon.localDomain = lib.mkDefault "example.com"; # Change this to your domain! VERY IMPORTANT!
  services.mastodon.streamingProcesses = lib.mkDefault 1;
  services.mastodon.smtp.fromAddress = lib.mkDefault "noreply@${config.services.mastodon.localDomain}";
  services.mastodon.vapidPublicKeyFile = config.sops.secrets."mastodon-vapid-public-key".path;
  services.mastodon.vapidPrivateKeyFile = config.sops.secrets."mastodon-vapid-private-key".path;
  services.mastodon.secretKeyBaseFile = config.sops.secrets."mastodon-secret-key-base".path;
  services.mastodon.elasticsearch =
    if config.services.elasticsearch.enable then
      {
        host = lib.mkDefault config.services.elasticsearch.listenAddress;
        user = "elasticsearch-mastodon";
        passwordFile = config.sops.secrets."elasticsearch-mastodon-password".path;
      }
    else
      { };
  services.mastodon.extraConfig.EMAIL_DOMAIN_DENYLIST = lib.concatStringsSep "," (
    lib.splitString "\n" (builtins.readFile emailDomainBlocklist)
  );

  # If PostgreSql backup is enabled, make sure to backup the Mastodon database (expected name is `mastodon`)
  services.postgresqlBackup.databases = [ config.services.mastodon.database.name ];

  # services.nginx.virtualHosts.${config.services.mastodon.localDomain}.serverAliases = [ "www.${config.services.mastodon.localDomain}" ];
  # Below is the reconstructed Nginx config usually created by the mastodon service, but I can't figure out how to only enable
  # http3 and quic here like I'm enabling the serverAliases just above, so I'm copying the entire thing. Ends with comment "ENDS HERE"
  services.mastodon.configureNginx = false; # We're configuring it manually below
  services.nginx.virtualHosts.${config.services.mastodon.localDomain} = {
    serverAliases = [ "www.${config.services.mastodon.localDomain}" ];
    http2 = true;
    http3 = true;
    http3_hq = true;
    quic = true;
    reuseport = true;
    root = "${config.services.mastodon.package}/public/";
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      gzip_static on;
      limit_req zone=req_limit_per_ip burst=20 nodelay;
      limit_conn conn_limit_per_ip 10;
    '';
    locations."/system/".alias = "/var/lib/mastodon/public-system/";
    locations."/".tryFiles = "$uri @proxy";
    locations."@proxy".proxyPass = (
      if config.services.mastodon.enableUnixSocket then
        "http://unix:/run/mastodon-web/web.socket"
      else
        "http://127.0.0.1:${toString (config.services.mastodon.webPort)}"
    );
    locations."@proxy".proxyWebsockets = true;
    locations."/api/v1/streaming/".proxyPass = "http://mastodon-streaming";
    locations."/api/v1/streaming/".proxyWebsockets = true;
  };
  services.nginx.upstreams.mastodon-streaming.extraConfig = ''
    least_conn;
  '';
  services.nginx.upstreams.mastodon-streaming.servers = builtins.listToAttrs (
    map (i: {
      name = "unix:/run/mastodon-streaming/streaming-${toString i}.socket";
      value = { };
    }) (lib.range 1 config.services.mastodon.streamingProcesses)
  );
  users.groups.${config.services.mastodon.group}.members = [ config.services.nginx.user ];
  # ENDS HERE

  # Reddit Feed Webhook
  # IFTTT stores the API key itself so it's not present here!
  systemd.services.reddit-feed-webhook =
    let
      redeployScript = pkgs.writeShellScript "redeploy.sh" ''
        ACCESS_TOKEN=$HOOK_token
        POST_URL=${"$"}{HOOK_url/?utm_source=ifttt/}

        if [[ $HOOK_content != https://*.jpg && $HOOK_content != https://*.jpeg && $HOOK_content != https://*.png && $HOOK_content != https://*.bmp && $HOOK_content != https://*.mp4 ]]; then
          ${pkgs.curl}bin/curl -v -F spoiler_text="$HOOK_title" -F status="$HOOK_content $POST_URL" -F sensitive="0" https://${config.services.mastodon.localDomain}/api/v1/statuses?access_token=$ACCESS_TOKEN
          exit 0
        fi

        # Get image
        extension="${"$"}{HOOK_content##*.}"
        tmpfile=$(mktemp /tmp/mastodon-reddit-feedXXXXXXXXXXXX).$extension

        ${pkgs.curl}/bin/curl --silent --output "$tmpfile" $HOOK_content

          MEDIA_ID=$(${pkgs.curl}/bin/curl -v -F file=@$tmpfile https://${config.services.mastodon.localDomain}/api/v2/media?access_token=$ACCESS_TOKEN | ${pkgs.jq}/bin/jq '.id' | sed 's/"//g')
        rm "$tmpfile"
        sleep 5

        ${pkgs.curl}/bin/curl --silent -v -F spoiler_text="$HOOK_title" -F status="$POST_URL" -F sensitive="0" -F media_ids[]=$MEDIA_ID https://${config.services.mastodon.localDomain}/api/v1/statuses?access_token=$ACCESS_TOKEN
      '';
      confFile = pkgs.writeText "webhookConf.json" ''
        [
          {
            "id": "mastodon-reddit-hook",
            "execute-command": "${redeployScript}",
            "parse-parameters-as-json": [
              { "source": "payload", "name": "title" },
              { "source": "payload", "name": "content" },
              { "source": "payload", "name": "url" }
            ],
            "pass-environment-to-command": [
              { "source": "payload", "name": "title" },
              { "source": "payload", "name": "content" },
              { "source": "payload", "name": "url" },
              { "source": "payload", "name": "token" },
            ]
          }
        ]
      '';
    in
    {
      enable = true;
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        webhook
        curl
        jq
      ];
      serviceConfig.ExecStart = "${pkgs.webhook}/bin/webhook -hooks ${confFile} -verbose";
    };
  systemd.services.restart-reddit-feed-webhook = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    script = "systemctl restart reddit-feed-webhook";
    serviceConfig.Type = "oneshot";
  };
  systemd.timers.restart-reddit-feed-webhook = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [
      "timers.target"
      "multi-user.target"
    ];
    timerConfig.Unit = "restart-reddit-feed-webhook.service";
    timerConfig.OnCalendar = "Mon *-*-1..7 4:00:00"; # First Monday of the month at 4am
  };
  services.nginx.virtualHosts."reddit-feed.${config.services.mastodon.localDomain}" = {
    enableACME = true;
    forceSSL = true;
    http2 = true;
    locations."/".proxyPass = "http://127.0.0.1:9000";
  };
}
