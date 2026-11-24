{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:
let
  strataCacheDir = "/var/lib/strata";
  strataInklingModelDir = "${strataCacheDir}/Models/inkling-2-mini";
in
{
  imports = [ ];

  # Inkling-2-Mini GGUF variant via llama.cpp b12600+
  # NOTE: Strata SQ-20 variant deferred until nixpkgs updates to strata >= 0.2.20
  # (Strata 0.2.15 in nixpkgs is too old; overriding it proved incompatible with nixpkgs build)
  # TODO: Once nixpkgs strata >= 0.2.20, can re-enable strata-inkling services below
  #       and add strata-inkling snapshots to barliman's snapshot list

  # Pin llama.cpp to b12600+ for Inkling-2-Mini GGUF support
  nixpkgs.overlays = [
    (
      final: prev:
      lib.optionalAttrs (prev ? llama-cpp) {
        llama-cpp = prev.llama-cpp.overrideAttrs (old: {
          version = "b12600";
          src = final.fetchFromGitHub {
            owner = "ggml-org";
            repo = "llama.cpp";
            rev = "b12600";
            hash = "sha256-VFFVg4h9/EKcqZVVFVS1LKry0TAeXeK4ZZ9W35xirS0=";
          };
        });
      }
    )
  ];

  # TODO: Uncomment strata-inkling services and tmpfiles rules once nixpkgs strata >= 0.2.20
  # For now, just the GGUF variant is available via llama.cpp

  # # Create cache directories with proper permissions for strata-inkling
  # systemd.tmpfiles.rules = [
  #   "d '${strataInklingModelDir}' 0755 root root - -"
  #   "d '${strataCacheDir}/mtp' 0755 root root - -"
  #   "d '${strataCacheDir}/pack' 0755 root root - -"
  # ];

  # # strata-inkling: separate Strata engine process for Inkling-2-Mini Strata quantized pack (SQ-20)
  # # Runs alongside strata-engine (for Qwen 3.8) without conflicts.
  # # Requires models to be downloaded first (via extended snapshot mechanism in barliman/default.nix)
  # systemd.services.strata-inkling = {
  # description = "Strata inference server for Inkling-2-Mini SQ-20 quantized pack";
  # wants = [ "network-online.target" ];
  # after = [
  #   "network-online.target"
  #   "lemonade-extra-snapshots.service"
  #   "strata-inkling-prepare.service"
  # ];
  # wantedBy = [ "multi-user.target" ];
  # preStart = ''
  #   if [ ! -d "${strataInklingModelDir}/sq-20" ]; then
  #     echo "ERROR: Strata model directory not found"
  #     exit 1
  #   fi
  # '';
  # serviceConfig = { ... };
  # };

  # # Prepare Strata quantized pack: symlink from HF cache to strata directory
  # systemd.services.strata-inkling-prepare = {
  #   ...
  # };
}
