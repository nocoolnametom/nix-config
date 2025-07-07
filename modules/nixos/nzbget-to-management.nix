{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
with lib.attrsets;
with lib.lists;
with lib.options;
with lib.types;

let
  cfg = config.services.nzbget-to-management;
in
{
  options.services.nzbget-to-management = {
    enable = mkEnableOption "Video Sync from Sauron Windows PC";

    downloadedDestDir = mkOption {
      description = "Path to directory where to-be-transcoded videos are placed by downloader.";
      type = str;
    };

    unpackingDirName = mkOption {
      description = "Name of unpacking directory downloader uses for unpacking partial files.";
      type = str;
      default = "_unpack";
    };

    transcodingTempDir = mkOption {
      description = "Path to directory where transcoded videos are placed while being transcoded.";
      type = str;
    };

    finishedVideoDir = mkOption {
      description = "Path to directory where fully-transcoded videos are placed.";
      type = str;
    };

    handbrakePresetJsonFilePath = mkOption {
      description = "Path to Handbrake preset export file with preset to be used.";
      type = str;
    };

    handbrakePreset = mkOption {
      description = "Handbrake preset to be used.";
      type = str;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nzbget-to-management =
      let
        transcodeScript = pkgs.writeShellScriptBin "transcodeVideoFiles.sh" ''
          set -euo pipefail

          INPUT_ROOT="${cfg.downloadedDestDir}"
          TRANSCODE_DIR="${cfg.transcodingTempDir}"
          FINAL_DIR="${cfg.finishedVideoDir}"
          PRESET_FILE="${cfg.handbrakePresetJsonFilePath}"
          PRESET_NAME="${cfg.handbrakePreset}"
          REGISTRY_FILE="/var/lib/nzbget-to-management/transcoded.log"

          LOCKFILE="/tmp/transcode_daemon.lock"

          mkdir -p "$(dirname "$REGISTRY_FILE")"
          touch "$REGISTRY_FILE"

          # Only allow one instance at a time
          exec 200>"$LOCKFILE"
          ${pkgs.util-linux}/bin/flock -n 200 || exit 0

          echo "Starting transcoding daemon..."

          transcode_video() {
              local input_file="$1"
              local filename="$(basename "$input_file")"
              local base_name="${"$"}{filename%.*}"
              local output_file="$TRANSCODE_DIR/$base_name.webm"
              local final_file="$FINAL_DIR/$base_name.webm"
              local lock_file="$TRANSCODE_DIR/$base_name.inprogress"

              if [[ -e "$lock_file" ]]; then
                  echo "[WARN] Skipping in-progress: $input_file"
                  return
              fi

              touch "$lock_file"

              echo "[INFO] Transcoding: $input_file → $output_file"
              if ${pkgs.handbrake}/bin/HandBrakeCLI --preset-import-file "$PRESET_FILE" \
                  --preset "$PRESET_NAME" \
                  -i "$input_file" \
                  -o "$output_file"; then

                  echo "[INFO] Moving: $output_file → $final_file"
                  mv "$output_file" "$final_file"
                  mark_transcoded "$input_file"
                  rm -f "$lock_file"
              else
                  echo "[ERROR] Transcoding failed: $input_file"
                  rm -f "$output_file" "$lock_file"
              fi
          }

          is_already_transcoded() {
              grep -Fxq "$1" "$REGISTRY_FILE"
          }

          mark_transcoded() {
              echo "$1" >> "$REGISTRY_FILE"
          }

          wait_for_stability() {
              local file="$1"
              local prev_size=0
              local size=1

              while [[ "$prev_size" -ne "$size" ]]; do
                  prev_size="$size"
                  sleep 5
                  size=$(stat -c%s "$file")
              done
          }

          process_files() {
              while true; do
                  # Find finished video files, excluding _unpack directories
                  mapfile -t files < <(find "$INPUT_ROOT" -type f \( -iname '*.mp4' -o -iname '*.mkv' \) \
                      -not -path "*/${cfg.unpackingDirName}/*" \
                      -not -path "*/.*" \
                      -print | sort)

                  if [[ "${"$"}{#files[@]}" -eq 0 ]]; then
                      echo "[INFO] No videos to process. Waiting for changes..."
                      # Wait for filesystem changes
                      ${pkgs.inotify-tools}/bin/inotifywait -r -e create,move,close_write "$INPUT_ROOT"
                      continue
                  fi

                  for file in "${"$"}{files[@]}"; do
                      if is_already_transcoded "$file"; then
                          echo "[INFO] Already transcoded (registry): $file"
                          continue
                      fi

                      wait_for_stability "$file"
                      transcode_video "$file"
                  done
              done
          }

          # Actually begin processing the files
          process_files
        '';
      in
      {
        enable = mkDefault true;
        description = "Video Transcoder Daemon";
        after = [ "default.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          StateDirectory = "nzbget-to-management";
          Restart = "on-failure";

          # Fix stashapp dir permissions before we run
          ExecStartPre = [
            "${pkgs.coreutils}/bin/chmod 755 /var/lib/stashapp"
          ];
        };
        script = "${transcodeScript}/bin/transcodeVideoFiles.sh";
      };
  };
}
