###############################################################################
#
#  Komodo Periphery - the per-host agent that lets Komodo Core (on feanor, see
#  docker/komodo.nix) see and manage this host's containers. Import it on
#  every host whose containers should appear in Komodo.
#
#  Native service from nixpkgs-unstable (module + package): the stable ones
#  are still Komodo v1, which cannot talk to a v2 Core.
#
#  Periphery connects out to Core over the LAN (outbound mode) and the two
#  authenticate with key pairs (noise handshake). Core's public key is pinned
#  below. A new host registers itself the first time with the onboarding key
#  (homelab/komodo/homelab-onboarding, made in Core: Settings > Servers >
#  onboarding keys); after that Core knows the host's key and the onboarding
#  key is no longer used.
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.komodoAgent;
in
{
  disabledModules = [ "services/admin/komodo-periphery.nix" ];
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/admin/komodo-periphery.nix"
  ];

  options.services.komodoAgent = {
    coreAddress = lib.mkOption {
      type = lib.types.str;
      default = "ws://${configVars.networking.subnets.feanor.ip}:${toString configVars.networking.ports.tcp.komodo}";
      description = "Komodo Core's websocket address.";
    };

    dockerHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "unix:///run/podman/podman.sock";
      description = "Engine socket to manage instead of the local Docker daemon (e.g. Podman's).";
    };

    onboard = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass the onboarding key so this host can register itself. Off for
        Core's own host, whose server Core creates from KOMODO_PERIPHERY_PUBLIC_KEY.
      '';
    };
  };

  config = lib.mkMerge [
    {
      services.komodo-periphery = {
        enable = true;
        package = pkgs.unstable.komodo;
        dockerHost = cfg.dockerHost;
        outbound = {
          coreAddress = cfg.coreAddress;
          connectAs = config.networking.hostName;
        };
        # Core's public key (it is public). Regenerated only if Core's key
        # file in feanor:/var/lib/komodo/keys is deleted; then update it here.
        auth.corePublicKeys = [ "MCowBQYDK2VuAyEARG8HGRV0Ve1zRgS9rekqwmVE+Zlk650V2g2o8/VomAE=" ];
      };
    }

    # The module only joins the docker group for the local Docker daemon.
    (lib.mkIf (cfg.dockerHost != null && lib.hasPrefix "unix:///run/podman/" cfg.dockerHost) {
      users.users.${config.services.komodo-periphery.user}.extraGroups = [ "podman" ];
      systemd.services.komodo-periphery = {
        after = [ "podman.socket" ];
        wants = [ "podman.socket" ];
      };
    })

    (lib.mkIf cfg.onboard {
      sops.secrets."homelab/komodo/homelab-onboarding" = { };
      sops.templates."komodo-periphery.env" = {
        content = ''
          PERIPHERY_ONBOARDING_KEY=${config.sops.placeholder."homelab/komodo/homelab-onboarding"}
        '';
        restartUnits = [ "komodo-periphery.service" ];
      };
      systemd.services.komodo-periphery.serviceConfig.EnvironmentFile =
        config.sops.templates."komodo-periphery.env".path;
    })
  ];
}
