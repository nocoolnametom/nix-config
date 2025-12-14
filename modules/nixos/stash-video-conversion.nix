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
  cfg = config.services.stash-video-conversion;

  # Fetch script: Query GraphQL, download first unconverted video
  fetchScript = pkgs.writeShellScript "stash-video-fetch.sh" ''
        set -euo pipefail

        STATE_DIR="${cfg.stateDirectory}"
        COMPLETED_IDS="$STATE_DIR/completed.ids"
        FAILED_IDS="$STATE_DIR/failed.ids"
        CURRENT_QUERY="$STATE_DIR/current-query"
        CURRENT_PAGE="$STATE_DIR/current-page"
        INCOMING_DIR="${cfg.incomingDir}"

        # Initialize state files
        mkdir -p "$STATE_DIR" "$INCOMING_DIR"
        touch "$COMPLETED_IDS" "$FAILED_IDS"

        # Read or initialize query state
        if [[ ! -f "$CURRENT_QUERY" ]]; then
          echo "high-res" > "$CURRENT_QUERY"
          echo "1" > "$CURRENT_PAGE"
        fi

        QUERY_TYPE=$(cat "$CURRENT_QUERY")
        PAGE=$(cat "$CURRENT_PAGE")

        echo "[INFO] Fetching videos - Query: $QUERY_TYPE, Page: $PAGE"

        # Build GraphQL query based on type using temp file
        QUERY_FILE=$(${pkgs.coreutils}/bin/mktemp)
        trap "rm -f $QUERY_FILE" EXIT

        if [[ "$QUERY_TYPE" == "high-res" ]]; then
          ${pkgs.coreutils}/bin/cat > "$QUERY_FILE" <<'QUERY_END'
    {"operationName":"FindScenes","variables":{"filter":{"q":"","page":PAGE_PLACEHOLDER,"per_page":LIMIT_PLACEHOLDER,"sort":"filesize","direction":"DESC"},"scene_filter":{"video_codec":{"value":"av1","modifier":"NOT_EQUALS"},"resolution":{"value":"FULL_HD","modifier":"GREATER_THAN"},"framerate":{"modifier":"LESS_THAN","value":50}}},"query":"query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType, $scene_ids: [Int!]){findScenes(filter:$filter,scene_filter:$scene_filter,scene_ids:$scene_ids){scenes{id files{path}}}}"}
    QUERY_END
        else
          ${pkgs.coreutils}/bin/cat > "$QUERY_FILE" <<'QUERY_END'
    {"operationName":"FindScenes","variables":{"filter":{"q":"","page":PAGE_PLACEHOLDER,"per_page":LIMIT_PLACEHOLDER,"sort":"filesize","direction":"DESC"},"scene_filter":{"video_codec":{"value":"av1","modifier":"NOT_EQUALS"},"resolution":{"value":"QUAD_HD","modifier":"LESS_THAN"}}},"query":"query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType, $scene_ids: [Int!]){findScenes(filter:$filter,scene_filter:$scene_filter,scene_ids:$scene_ids){scenes{id files{path}}}}"}
    QUERY_END
        fi

        # Replace placeholders
        ${pkgs.gnused}/bin/sed -i "s/PAGE_PLACEHOLDER/$PAGE/g" "$QUERY_FILE"
        ${pkgs.gnused}/bin/sed -i "s/LIMIT_PLACEHOLDER/${toString cfg.perPageLimit}/g" "$QUERY_FILE"

        # Make GraphQL request
        RESPONSE=$(${pkgs.curl}/bin/curl -s -X POST "${cfg.graphqlEndpoint}" \
          -H "Content-Type: application/json" \
          -H "ApiKey: $API_KEY" \
          -d @"$QUERY_FILE")

        echo "[DEBUG] GraphQL Response: $RESPONSE"

        # Parse response and extract scenes
        SCENES=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.data.findScenes.scenes // []')
        SCENE_COUNT=$(echo "$SCENES" | ${pkgs.jq}/bin/jq 'length')

        echo "[INFO] Found $SCENE_COUNT scenes in response"

        # If no scenes, try next page or switch query
        if [[ "$SCENE_COUNT" -eq 0 ]]; then
          if [[ "$QUERY_TYPE" == "high-res" ]]; then
            echo "[INFO] High-res query exhausted, switching to low-res"
            echo "low-res" > "$CURRENT_QUERY"
            echo "1" > "$CURRENT_PAGE"
            # Recursively call ourselves to try the next query
            exec "$0"
          else
            echo "[INFO] All queries exhausted, no more videos to convert"
            exit 0
          fi
        fi

        # Find first unconverted video
        FOUND_VIDEO=""
        for i in $(seq 0 $((SCENE_COUNT - 1))); do
          VIDEO_ID=$(echo "$SCENES" | ${pkgs.jq}/bin/jq -r ".[$i].id")
          VIDEO_PATH=$(echo "$SCENES" | ${pkgs.jq}/bin/jq -r ".[$i].files[0].path")

          # Check if already processed
          if grep -Fxq "$VIDEO_ID" "$COMPLETED_IDS" || grep -Fxq "$VIDEO_ID" "$FAILED_IDS"; then
            echo "[INFO] Skipping already processed video ID: $VIDEO_ID"
            continue
          fi

          FOUND_VIDEO="$VIDEO_ID:$VIDEO_PATH"
          break
        done

        # If no unconverted video found on this page, try next page
        if [[ -z "$FOUND_VIDEO" ]]; then
          NEXT_PAGE=$((PAGE + 1))
          echo "[INFO] No unconverted videos on page $PAGE, trying page $NEXT_PAGE"
          echo "$NEXT_PAGE" > "$CURRENT_PAGE"
          # Recursively call ourselves to try the next page
          exec "$0"
        fi

        # Parse found video
        VIDEO_ID=$(echo "$FOUND_VIDEO" | cut -d: -f1)
        VIDEO_PATH=$(echo "$FOUND_VIDEO" | cut -d: -f2-)

        echo "[INFO] Downloading video ID $VIDEO_ID from $VIDEO_PATH"

        # Rsync the video file
        ${pkgs.rsync}/bin/rsync -avz --progress \
          -e "${pkgs.openssh}/bin/ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
          "${cfg.remoteUser}@${cfg.remoteHost}:$VIDEO_PATH" \
          "$INCOMING_DIR/"

        # Store the video ID for the convert service to use
        echo "$VIDEO_ID" > "$STATE_DIR/current-video-id"

        echo "[INFO] Download complete"
  '';

  # Convert script: Convert all videos in incoming dir
  convertScript = pkgs.writeShellScript "stash-video-convert.sh" ''
    set -euo pipefail

    STATE_DIR="${cfg.stateDirectory}"
    INCOMING_DIR="${cfg.incomingDir}"
    TRANSCODING_DIR="${cfg.transcodingDir}"
    FINISHED_DIR="${cfg.finishedDir}"
    COMPLETED_IDS="$STATE_DIR/completed.ids"
    FAILED_IDS="$STATE_DIR/failed.ids"
    CURRENT_VIDEO_ID="$STATE_DIR/current-video-id"
    PRESET_FILE="${cfg.handbrakePresetJsonFilePath}"
    PRESET_NAME="${cfg.handbrakePreset}"
    EMPTY_FLAG="$STATE_DIR/empty-incoming-flag"

    mkdir -p "$TRANSCODING_DIR" "$FINISHED_DIR"

    # Check for files in incoming directory
    shopt -s nullglob
    FILES=("$INCOMING_DIR"/*)
    shopt -u nullglob

    if [[ ''${#FILES[@]} -eq 0 ]]; then
      echo "[ERROR] No files found in incoming directory!"
      # Set flag to prevent infinite loop
      touch "$EMPTY_FLAG"
      echo "[INFO] Starting upload service to sync any completed files before stopping"
      systemctl start stash-video-upload.service
      exit 1
    fi

    # Clear empty flag if it exists
    rm -f "$EMPTY_FLAG"

    # Process each file
    for input_file in "''${FILES[@]}"; do
      # Skip if not a video file
      if [[ ! -f "$input_file" ]]; then
        continue
      fi

      filename="$(basename "$input_file")"
      base_name="''${filename%.*}"
      output_file="$TRANSCODING_DIR/$base_name.webm"
      final_file="$FINISHED_DIR/$base_name.webm"

      # Get video ID if available
      VIDEO_ID=""
      if [[ -f "$CURRENT_VIDEO_ID" ]]; then
        VIDEO_ID=$(cat "$CURRENT_VIDEO_ID")
      fi

      echo "[INFO] Converting: $input_file -> $output_file"

      if ${pkgs.handbrake}/bin/HandBrakeCLI --preset-import-file "$PRESET_FILE" \
          --preset "$PRESET_NAME" \
          -i "$input_file" \
          -o "$output_file"; then

        echo "[INFO] Conversion successful, moving to finished directory"
        mv "$output_file" "$final_file"
        rm -f "$input_file"

        # Mark as completed
        if [[ -n "$VIDEO_ID" ]]; then
          echo "$VIDEO_ID" >> "$COMPLETED_IDS"
          echo "[INFO] Marked video ID $VIDEO_ID as completed"
        fi

        rm -f "$CURRENT_VIDEO_ID"
      else
        echo "[ERROR] Conversion failed for $input_file"
        rm -f "$output_file" "$input_file"

        # Mark as failed
        if [[ -n "$VIDEO_ID" ]]; then
          echo "$VIDEO_ID" >> "$FAILED_IDS"
          echo "[INFO] Marked video ID $VIDEO_ID as failed"
        fi

        rm -f "$CURRENT_VIDEO_ID"
      fi
    done

    echo "[INFO] All conversions complete"
  '';

  # Upload script: Rsync finished videos back to bert
  uploadScript = pkgs.writeShellScript "stash-video-upload.sh" ''
    set -euo pipefail

    STATE_DIR="${cfg.stateDirectory}"
    FINISHED_DIR="${cfg.finishedDir}"
    EMPTY_FLAG="$STATE_DIR/empty-incoming-flag"

    # Check for files to upload
    shopt -s nullglob
    FILES=("$FINISHED_DIR"/*.webm)
    shopt -u nullglob

    if [[ ''${#FILES[@]} -gt 0 ]]; then
      echo "[INFO] Uploading ''${#FILES[@]} converted files to ${cfg.remoteHost}"

      # Rsync all finished files back
      ${pkgs.rsync}/bin/rsync -avz --progress --remove-source-files \
        -e "${pkgs.openssh}/bin/ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
        "$FINISHED_DIR/" \
        "${cfg.remoteUser}@${cfg.remoteHost}:${cfg.remoteUploadDir}/"

      echo "[INFO] Upload complete, files removed from local system"
    else
      echo "[INFO] No files to upload"
    fi

    # Check if we should stop (empty flag was set by convert service)
    if [[ -f "$EMPTY_FLAG" ]]; then
      echo "[WARN] Empty incoming directory flag detected, stopping conversion cycle"
      # Exit successfully but let ExecStartPost handle not restarting
      exit 0
    fi

    echo "[INFO] Upload complete, will restart fetch service"
  '';

  # Launcher script: Just starts the fetch service and exits immediately
  launcherScript = pkgs.writeShellScript "stash-video-launcher.sh" ''
    set -euo pipefail
    echo "[INFO] Starting stash-video-conversion state machine"
    ${pkgs.systemd}/bin/systemctl start --no-block stash-video-fetch.service
  '';

in
{
  options.services.stash-video-conversion = {
    enable = mkEnableOption "Remote video conversion from bert";

    environmentFile = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Path to environment file containing secrets. Should define:
        - API_KEY: API key for GraphQL authentication
        - SSH_KEY_PATH: Path to SSH private key for rsync authentication

        Example using sops-nix:
        ```nix
        sops.secrets."bert-stashapp-api-key" = { };
        sops.secrets."stash-video-rsync-key" = {
          mode = "0600";
        };
        sops.templates."stash-video-conversion.env".content = '''
          API_KEY=''${config.sops.placeholder."bert-stashapp-api-key"}
          SSH_KEY_PATH=''${config.sops.secrets."stash-video-rsync-key".path}
        ''';
        services.stash-video-conversion.environmentFile =
          config.sops.templates."stash-video-conversion.env".path;
        ```
      '';
    };

    graphqlEndpoint = mkOption {
      type = str;
      description = "Full GraphQL endpoint URL (e.g., http://192.168.1.10:9999/graphql)";
      example = "http://192.168.1.10:9999/graphql";
    };

    remoteHost = mkOption {
      type = str;
      description = "Remote hostname or IP for rsync operations";
      example = "192.168.1.10";
    };

    remoteUser = mkOption {
      type = str;
      description = "Username for remote rsync operations";
    };

    remoteUploadDir = mkOption {
      type = str;
      description = "Remote directory path where converted files will be uploaded";
      example = "/arkenstone/stash/library/unorganized/_staging/finished";
    };

    incomingDir = mkOption {
      type = str;
      description = "Local directory for downloaded videos to be converted";
    };

    transcodingDir = mkOption {
      type = str;
      description = "Local directory for videos currently being transcoded";
    };

    finishedDir = mkOption {
      type = str;
      description = "Local directory for successfully converted videos";
    };

    handbrakePresetJsonFilePath = mkOption {
      type = str;
      description = "Path to Handbrake preset export file";
    };

    handbrakePreset = mkOption {
      type = str;
      description = "Name of Handbrake preset to use";
    };

    stateDirectory = mkOption {
      type = str;
      default = "/var/lib/stash-video-conversion";
      description = "Directory for storing state files (completed/failed IDs)";
    };

    perPageLimit = mkOption {
      type = int;
      default = 50;
      description = "Number of videos to request per GraphQL query page";
    };

    user = mkOption {
      type = str;
      default = "stash-video-conversion";
      description = "User account for running the conversion services";
    };

    group = mkOption {
      type = str;
      default = "stash-video-conversion";
      description = "Group for the conversion services user";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Bert video conversion service user";
    };

    users.groups.${cfg.group} = { };

    # Create directories with proper ownership via tmpfiles
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.incomingDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.transcodingDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.finishedDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Fetch service: Query GraphQL and download video
    systemd.services.stash-video-fetch = {
      description = "Stash Video Conversion - Fetch Service";

      # Rate limiting: max 5 restarts in 5 minutes
      startLimitIntervalSec = 300;
      startLimitBurst = 5;

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = fetchScript;
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        # Start convert service after successful completion (+ prefix runs as root)
        ExecStartPost = "+${pkgs.systemd}/bin/systemctl start --no-block stash-video-convert.service";
      };

      # Don't start on boot
      wantedBy = mkForce [ ];
    };

    # Convert service: Transcode videos
    systemd.services.stash-video-convert = {
      description = "Stash Video Conversion - Convert Service";

      # Rate limiting: max 5 restarts in 5 minutes
      startLimitIntervalSec = 300;
      startLimitBurst = 5;

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = convertScript;
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        # Start upload service after successful completion (+ prefix runs as root)
        ExecStartPost = "+${pkgs.systemd}/bin/systemctl start --no-block stash-video-upload.service";
      };

      # Don't start on boot
      wantedBy = mkForce [ ];
    };

    # Upload service: Rsync back to bert
    systemd.services.stash-video-upload = {
      description = "Stash Video Conversion - Upload Service";

      # Rate limiting: max 5 restarts in 5 minutes
      startLimitIntervalSec = 300;
      startLimitBurst = 5;

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = uploadScript;
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        # Loop back to fetch service only if upload was successful (no empty flag)
        # + prefix runs as root so systemctl has permission
        ExecStartPost =
          "+"
          + pkgs.writeShellScript "upload-post.sh" ''
            if [[ -f "${cfg.stateDirectory}/empty-incoming-flag" ]]; then
              echo "[INFO] Empty flag detected, not restarting fetch service"
              exit 0
            fi
            ${pkgs.systemd}/bin/systemctl start --no-block stash-video-fetch.service
          '';
      };

      # Don't start on boot
      wantedBy = mkForce [ ];
    };

    # Launcher service: Kicks off the state machine and returns immediately
    systemd.services.stash-video-launcher = {
      description = "Stash Video Conversion - Launcher";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = launcherScript;
      };

      # Don't start on boot
      wantedBy = mkForce [ ];
    };

    # Target to control all services
    systemd.targets.stash-video-conversion = {
      description = "Stash Video Conversion Target";
      wants = [
        "stash-video-launcher.service"
      ];
    };
  };
}
