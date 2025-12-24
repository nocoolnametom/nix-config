{
  pkgs,
  lib,
  config,
  ...
}:
{
  sops.secrets."mormonsites/mormoncanon" = { };
  sops.secrets."mormonsites/mormonquotes" = { };
  sops.secrets."mormonsites/journalofdiscourses" = { };
  sops.templates."mormoncanon-secrets".content = ''
    MORMONCANON_DB_PASSWORD=${config.sops.placeholder."mormonsites/mormoncanon"}
  '';
  sops.templates."mormonquotes-secrets".content = ''
    MORMONQUOTES_DB_PASSWORD=${config.sops.placeholder."mormonsites/mormonquotes"}
  '';
  sops.templates."journalofdiscourses-secrets".content = ''
    JOURNALOFDISCOURSES_DB_PASSWORD=${config.sops.placeholder."mormonsites/journalofdiscourses"}
  '';

  services.mormonsites.enable = lib.mkDefault true;
  services.mormonsites.defaultListenAddress = lib.mkDefault "127.0.0.1";
  # nginx proxies locally; no need to expose
  services.mormonsites.defaultOpenFirewall = lib.mkDefault false;

  services.mormonsites.instances.canon.enable = lib.mkDefault true;
  services.mormonsites.instances.canon.package = lib.mkDefault pkgs.mormoncanon;
  services.mormonsites.instances.canon.shareName = lib.mkDefault "mormoncanon";
  services.mormonsites.instances.canon.envPrefix = lib.mkDefault "MORMONCANON";
  services.mormonsites.instances.canon.port = lib.mkDefault 9005;
  services.mormonsites.instances.canon.database.name = lib.mkDefault "mormoncanon";
  services.mormonsites.instances.canon.database.user = lib.mkDefault "mormoncanon";
  services.mormonsites.instances.canon.database.host = lib.mkDefault "127.0.0.1";
  services.mormonsites.instances.canon.database.passwordFile =
    lib.mkDefault
      config.sops.templates."mormoncanon-secrets".path;

  services.mormonsites.instances.quotes.enable = lib.mkDefault true;
  services.mormonsites.instances.quotes.package = lib.mkDefault pkgs.mormonquotes;
  services.mormonsites.instances.quotes.shareName = lib.mkDefault "mormonquotes";
  services.mormonsites.instances.quotes.envPrefix = lib.mkDefault "MORMONQUOTES";
  services.mormonsites.instances.quotes.port = lib.mkDefault 9006;
  services.mormonsites.instances.quotes.database.name = lib.mkDefault "mormonquotes";
  services.mormonsites.instances.quotes.database.user = lib.mkDefault "mormonquotes";
  services.mormonsites.instances.quotes.database.host = lib.mkDefault "127.0.0.1";
  services.mormonsites.instances.quotes.database.passwordFile =
    lib.mkDefault
      config.sops.templates."mormonquotes-secrets".path;

  services.mormonsites.instances.jod.enable = lib.mkDefault true;
  services.mormonsites.instances.jod.package = lib.mkDefault pkgs.journalofdiscourses;
  services.mormonsites.instances.jod.shareName = lib.mkDefault "journalofdiscourses";
  services.mormonsites.instances.jod.envPrefix = lib.mkDefault "JOURNALOFDISCOURSES";
  services.mormonsites.instances.jod.port = lib.mkDefault 9007;
  services.mormonsites.instances.jod.database.name = lib.mkDefault "journalofdiscourses";
  services.mormonsites.instances.jod.database.user = lib.mkDefault "journalofdiscourses";
  services.mormonsites.instances.jod.database.host = lib.mkDefault "127.0.0.1";
  services.mormonsites.instances.jod.database.passwordFile =
    lib.mkDefault
      config.sops.templates."journalofdiscourses-secrets".path;
}
