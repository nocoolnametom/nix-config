{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Construction du paquet cosmic-ext-alternative-startup
  cosmic-ext-alternative-startup = pkgs.rustPlatform.buildRustPackage {
    pname = "cosmic-ext-alternative-startup";
    version = "0.1.0";
    src = inputs.cosmic-ext-alternative-startup;

    cargoLock = {
      lockFile = "${inputs.cosmic-ext-alternative-startup}/Cargo.lock";
    };

    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ libxkbcommon ];

    meta = with lib; {
      description = "Alternative startup extension for COSMIC Desktop";
      homepage = "https://github.com/Drakulix/cosmic-ext-alternative-startup";
      license = licenses.gpl3;
      platforms = platforms.linux;
    };
  };
  originalScript = builtins.readFile "${inputs.cosmic-ext-extra-sessions}/niri/start-cosmic-ext-niri";

  modifiedScript =
    builtins.replaceStrings
      [
        "/usr/bin/cosmic-session"
        "/usr/bin/dbus-run-session"
      ]
      [
        "cosmic-session"
        "dbus-run-session"
      ]
      originalScript;

  originalDesktop = builtins.readFile "${inputs.cosmic-ext-extra-sessions}/niri/cosmic-ext-niri.desktop";

  modifiedDesktop =
    builtins.replaceStrings [ "/usr/local/bin/start-cosmic-ext-niri" ] [ "start-cosmic-ext-niri" ]
      originalDesktop;

  scriptPackage = pkgs.writeScriptBin "start-cosmic-ext-niri" modifiedScript;

  cosmicNiriDesktop = pkgs.writeTextFile {
    name = "cosmic-niri.desktop";
    destination = "/share/wayland-sessions/cosmic-niri.desktop";
    text = modifiedDesktop;
  };

  cosmicExtNiriSession = pkgs.symlinkJoin {
    name = "cosmic-ext-niri-session";
    paths = [
      scriptPackage
      cosmicNiriDesktop
    ];
    # Spécifier les noms des sessions fournies
    passthru.providedSessions = [ "cosmic-niri" ];
  };
in
{
  environment.systemPackages = [
    cosmic-ext-alternative-startup
    cosmicExtNiriSession
  ];

  systemd.user.targets.cosmic-session.enable = false;
  services.displayManager.sessionPackages = [ cosmicExtNiriSession ];
}
