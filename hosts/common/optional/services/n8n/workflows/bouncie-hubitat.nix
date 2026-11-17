###############################################################################
#
#  Bouncie -> Hubitat
#
#  Bouncie (an OBD-II vehicle tracker) POSTs vehicle events to
#  https://<n8n>/webhook/bouncie (spec: the OpenAPI document on bouncie.dev).
#  Each event names its vehicle by `vin` (and its device by `imei`) and its
#  kind by `eventType`:
#  tripStart, tripData, tripMetrics, tripEnd, mil, battery, connect,
#  disconnect, vinChange, userGeozone, applicationGeozone. Geo-zone events
#  also carry `geozone.name` and `geozone.event` (ENTER or EXIT); userGeozone
#  covers the zones drawn in the Bouncie app, the same ones its IFTTT
#  "Geo-Circle entered/exited" triggers use.
#
#  This workflow maps the VIN to a Hubitat device and the event to a command
#  on that device (`geozoneCommands` for geo-zone events, `eventCommands` for
#  the rest), then sends it through Hubitat's Maker API:
#    GET http://<hub>/apps/api/<app id>/devices/<deviceId>/<command>
#  By default a vehicle's device is an "at home" Virtual Switch: on when it
#  enters the home user geo-zone (configVars.locations.home.bouncie, the
#  zone's name in the Bouncie app), off when it leaves.
#
#  Events from unknown VINs, or with no command, stop at the mapping step.
#  Their execution still shows up in n8n, which is the easiest place to read
#  a new vehicle's VIN.
#
#  Bouncie only sends events for accounts that have authorized the app
#  (developer portal: Users & Devices -> Authorize My Devices), and only the
#  event types ticked on the app's webhook.
#
#  The webhook only accepts requests carrying the key Bouncie sends with
#  every webhook (header named by `webhookKeyHeader`); others get 403.
#
#  sops keys:
#    bouncie/my-unique-key              the app's webhook key (Bouncie developer portal)
#    hubitat/maker_api/app_id           the Maker API instance's app id (the number in its URLs)
#    hubitat/maker_api/access_token     the Maker API instance's access token
#
#  configVars (nix-secrets):
#    vehicles.<name>.bouncieId          Bouncie's internal vehicle id; marks the
#                                       vehicle as a Bouncie one (webhooks don't
#                                       carry it, so it isn't matched on)
#    vehicles.<name>.vin                the vehicle's VIN, which every event carries
#    vehicles.<name>.hubitatId          its Hubitat device (allowed in Maker API)
#    locations.home.bouncie             name of the home user geo-zone
#
###############################################################################

{
  lib,
  config,
  configVars,
  ...
}:
let
  cfg = config.services.n8n.bouncieHubitat;
  placeholder = config.sops.placeholder;

  # Vehicles in configVars with a Bouncie device. One without a hubitatId is
  # a mistake (a typo, say), so it fails evaluation instead of being skipped.
  vehiclesFromVars = lib.mapAttrs (name: v: {
    vin = v.vin or (throw "configVars.vehicles.${name} has a bouncieId but no vin");
    hubitatDeviceId =
      v.hubitatId or (throw "configVars.vehicles.${name} has a bouncieId but no hubitatId");
  }) (lib.filterAttrs (_: v: v ? bouncieId) configVars.vehicles);

  homeZone = configVars.locations.home.bouncie or "Home";

  devicesByVin = lib.mapAttrs' (_: v: lib.nameValuePair v.vin v.hubitatDeviceId) cfg.vehicles;

  credentialIds = {
    webhookKey = "bouncieWebhookKey";
    makerApi = "hubitatMakerApi";
  };
  credentialRef = id: {
    inherit id;
    name = config.services.n8n.declarative.credentials.${id}.name;
  };
in
{
  options.services.n8n.bouncieHubitat = {
    webhookKeyHeader = lib.mkOption {
      type = lib.types.str;
      default = "Authorization";
      description = "Request header in which Bouncie sends the webhook key.";
    };

    hubitatAddress = lib.mkOption {
      type = lib.types.str;
      default = configVars.networking.subnets.hubitat.ip;
      defaultText = lib.literalExpression "configVars.networking.subnets.hubitat.ip";
      description = "LAN address of the Hubitat hub.";
    };

    vehicles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            vin = lib.mkOption {
              type = lib.types.str;
              description = "The vehicle's VIN (the `vin` of its events).";
            };
            hubitatDeviceId = lib.mkOption {
              type = lib.types.ints.positive;
              description = "Hubitat device id that receives this vehicle's commands; it must be allowed in the Maker API instance.";
            };
          };
        }
      );
      default = vehiclesFromVars;
      defaultText = lib.literalMD "every `configVars.vehicles` entry with a `bouncieId`, by its `vin` and `hubitatId`";
      example = {
        minivan = {
          vin = "1HGBH41JXMN109186";
          hubitatDeviceId = 412;
        };
      };
      description = "Vehicles to forward, by any name.";
    };

    geozoneCommands = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {
        ${homeZone} = {
          ENTER = "on";
          EXIT = "off";
        };
      };
      defaultText = lib.literalExpression ''{ ''${configVars.locations.home.bouncie} = { ENTER = "on"; EXIT = "off"; }; }'';
      description = ''
        Maker API command per user geo-zone name (as named in the Bouncie app)
        and transition (ENTER or EXIT). The default drives an "at home"
        Virtual Switch.
      '';
    };

    eventCommands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        tripStart = "on";
        tripEnd = "off";
      };
      description = ''
        Maker API command per other Bouncie event type. A command may carry
        arguments as extra path segments, e.g. `setVariable/driving`. Empty by
        default: the vehicle devices are "at home" switches, which trip events
        say nothing about.
      '';
    };
  };

  config = {
    sops.secrets = {
      "bouncie/my-unique-key" = { };
      "hubitat/maker_api/app_id" = { };
      "hubitat/maker_api/access_token" = { };
    };

    services.n8n.declarative.credentials = {
      ${credentialIds.webhookKey} = {
        id = credentialIds.webhookKey;
        name = "Bouncie webhook key";
        type = "httpHeaderAuth";
        data = {
          name = cfg.webhookKeyHeader;
          value = placeholder."bouncie/my-unique-key";
        };
      };
      ${credentialIds.makerApi} = {
        id = credentialIds.makerApi;
        name = "Hubitat Maker API";
        type = "httpQueryAuth";
        data = {
          name = "access_token";
          value = placeholder."hubitat/maker_api/access_token";
        };
      };
    };

    services.n8n.declarative.workflows.bouncie-hubitat = {
      id = "bouncieHubitat01";
      name = "Bouncie -> Hubitat";
      nodes = [
        {
          id = "cfda6aaf-2ddf-4996-aecb-c6699993ef6e";
          name = "Bouncie webhook";
          type = "n8n-nodes-base.webhook";
          typeVersion = 2;
          position = [
            0
            0
          ];
          webhookId = "681de7e6-6fef-466b-84b3-ac5aea636d87";
          parameters = {
            httpMethod = "POST";
            path = "bouncie";
            authentication = "headerAuth";
            responseMode = "onReceived";
            options = { };
          };
          credentials.httpHeaderAuth = credentialRef credentialIds.webhookKey;
        }
        {
          id = "f666a042-e00e-47dd-8577-a117a8a53d28";
          name = "Map to Hubitat command";
          type = "n8n-nodes-base.code";
          typeVersion = 2;
          position = [
            240
            0
          ];
          parameters.jsCode = ''
            const devices = ${builtins.toJSON devicesByVin};
            const commands = ${builtins.toJSON cfg.eventCommands};
            const geozoneCommands = ${builtins.toJSON cfg.geozoneCommands};
            const out = [];
            for (const item of $input.all()) {
              const event = item.json.body ?? {};
              const deviceId = devices[event.vin];
              const command =
                event.eventType === "userGeozone"
                  ? geozoneCommands[event.geozone?.name]?.[event.geozone?.event]
                  : commands[event.eventType];
              if (deviceId !== undefined && command) {
                out.push({
                  json: { deviceId, command, eventType: event.eventType, geozone: event.geozone?.name },
                });
              }
            }
            return out;
          '';
        }
        {
          id = "c61a9501-778c-4b9c-8d6e-54213ab6d87f";
          name = "Hubitat Maker API";
          type = "n8n-nodes-base.httpRequest";
          typeVersion = 4.2;
          position = [
            480
            0
          ];
          parameters = {
            method = "GET";
            url = "=http://${cfg.hubitatAddress}/apps/api/${
              placeholder."hubitat/maker_api/app_id"
            }/devices/{{ $json.deviceId }}/{{ $json.command }}";
            authentication = "genericCredentialType";
            genericAuthType = "httpQueryAuth";
            options = { };
          };
          credentials.httpQueryAuth = credentialRef credentialIds.makerApi;
        }
      ];
      connections = {
        "Bouncie webhook".main = [
          [
            {
              node = "Map to Hubitat command";
              type = "main";
              index = 0;
            }
          ]
        ];
        "Map to Hubitat command".main = [
          [
            {
              node = "Hubitat Maker API";
              type = "main";
              index = 0;
            }
          ]
        ];
      };
    };
  };
}
