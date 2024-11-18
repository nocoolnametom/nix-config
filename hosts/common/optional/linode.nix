{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Enable LISH console
  boot.kernelParams = [ "console=ttyS0,19200n8" ];
  boot.loader.grub.extraConfig = ''
    serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1;
    terminal_input serial;
    terminal_output serial
  '';

  # Configure GRUB
  boot.loader.grub.enable = true;
  boot.loader.grub.forceInstall = true;
  boot.loader.grub.device = "nodev";
  boot.loader.timeout = 10;

  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false; # Disable DHCP globally as we will not need it.
  networking.interfaces.eth0.useDHCP = true; # Required for SSH

  # Diagnostic tools Linode troubleshooting expects
  environment.systemPackages = with pkgs; [
    inetutils
    mtr
    sysstat
  ];

  # Longview monitoring
  # Key is stored in sops: longview/<hostname>/key
  # Mysql, if enabled, password is stored in sops: longview/<hostname>/mysql/password (expected username is linode-longview)
  sops.secrets."longview-key" = {
    key = "longview/${config.networking.hostName}/key";
    owner = config.users.users.root.name;
    group = config.users.users.root.group;
    mode = "0600";
  };
  sops.secrets."longview-mysql-password" = {
    key = "longview/${config.networking.hostName}/mysql/password";
    owner = config.users.users.root.name;
    group = config.users.users.root.group;
    mode = "0600";
  };
  services.longview.enable = lib.mkDefault true;
  services.longview.apiKeyFile = config.sops.secrets."longview-key".path;
  services.longview.apacheStatusUrl =
    if config.services.httpd.enable then "http://localhost/server-status" else "";
  services.longview.nginxStatusUrl =
    if config.services.nginx.enable then "http://localhost/nginx_status" else "";
  services.longview.mysqlUser = lib.mkDefault (
    if config.services.mysql.enable then "linode-longview" else ""
  );
  services.longview.mysqlPasswordFile =
    if config.services.mysql.enable then config.sops.secrets."longview-mysql-password".path else "";
  services.nginx.statusPage = lib.mkDefault config.services.nginx.enable; # Ensure the status page is enabled if nginx is enabled
}
