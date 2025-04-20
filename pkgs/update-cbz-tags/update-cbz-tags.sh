#!/usr/bin/env bash

set -e

# ----------------------
# Parse Args
# ----------------------
if [ $# -lt 1 ]; then
    usage
fi

CBZ_FILE=""
BACKUP_MODE=false
VERBOSE=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        *.cbz)
            CBZ_FILE="$arg"
            ;;
        --backup)
            BACKUP_MODE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $arg"
            usage
            ;;
    esac
done

if [ ! -f "$CBZ_FILE" ]; then
    echo "Error: File '$CBZ_FILE' not found."
    exit 1
fi

# ----------------------
# Setup
# ----------------------
TMP_DIR=$(mktemp -d)
XML_FILE="$TMP_DIR/ComicInfo.xml"

unzip -qq "$CBZ_FILE" -d "$TMP_DIR"

# ----------------------
# Helper Functions
# ----------------------
log() {
    if [ "$VERBOSE" = true ] && [ -n "$1" ]; then
        echo "$1"
    fi
}

usage() {
    echo "Usage: $0 <file.cbz> [options]"
    echo ""
    echo "Options:"
    echo "  --backup         Write to <original>_updated.cbz instead of overwriting"
    echo "  --dry-run        Simulate changes, don't write to archive"
    echo "  -v, --verbose    Print debug/logging output"
    echo "  -h, --help       Show this help message"
    exit 0
}

# ----------------------
# Extract Web URL
# ----------------------
WEB_URL=$(xmlstarlet sel -t -v "//ComicInfo/Web" "$XML_FILE")

if [ -z "$WEB_URL" ]; then
    log "No <Web> URL found in ComicInfo.xml — skipping."
    rm -rf "$TMP_DIR"
    exit 0
fi

log "Web URL: $WEB_URL"

# ----------------------
# Fetch and Extract Tags (per domain)
# ----------------------

get_tags_fakku() {
    echo "$1" | pup 'a[href^="/tags/"] text{}' | sort -u
}

get_tags_anilist() {
    if ! echo "$1" | grep -q '<div[^>]*class="[^"]*\btags\b'; then
        log "No <div class=\"tags\"> block found on Anilist page."
        return 1
    fi
    echo "$1" | pup 'div.tag a.name text{}' | sort -u
}

TAGS_FROM_WEB=""
DOMAIN=$(echo "$WEB_URL" | awk -F/ '{print $3}')
HTML_CONTENT=$(curl -s "$WEB_URL")

log "Detected domain: $DOMAIN"

case "$DOMAIN" in
    *fakku.net)
        TAGS_FROM_WEB=$(get_tags_fakku "$HTML_CONTENT")
        ;;
    *anilist.co)
        TAGS_FROM_WEB=$(get_tags_anilist "$HTML_CONTENT") || {
            rm -rf "$TMP_DIR"
            exit 0
        }
        ;;
    *)
        log "Unsupported domain: $DOMAIN — skipping."
        rm -rf "$TMP_DIR"
        exit 0
        ;;
esac

if [ -z "$TAGS_FROM_WEB" ]; then
    log "No tags found on page — skipping."
    rm -rf "$TMP_DIR"
    exit 0
fi

log "Tags extracted from HTML:"
log "$TAGS_FROM_WEB"

# ----------------------
# Get Existing Tags (if any)
# ----------------------
TAGS_EXISTS=$(xmlstarlet sel -t -v "boolean(//ComicInfo/Tags)" "$XML_FILE")

if [ "$TAGS_EXISTS" = "true" ]; then
    EXISTING_TAGS=$(xmlstarlet sel -t -v "//ComicInfo/Tags" "$XML_FILE" | \
        tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//' | tr '[:upper:]' '[:lower:]')
else
    EXISTING_TAGS=""
fi

# ----------------------
# Merge Tags (avoid duplicates)
# ----------------------
NEW_TAGS=""
for tag in $TAGS_FROM_WEB; do
    tag_lower=$(echo "$tag" | tr '[:upper:]' '[:lower:]')
    if ! echo "$EXISTING_TAGS" | grep -qxF "$tag_lower"; then
        NEW_TAGS+=", $tag"
    fi
done

if [ "$TAGS_EXISTS" = "true" ]; then
    FINAL_TAGS=$(xmlstarlet sel -t -v "//ComicInfo/Tags" "$XML_FILE")"$NEW_TAGS"
else
    FINAL_TAGS=$(echo "$NEW_TAGS" | sed 's/^, //')
fi

log "Final merged tag list to write:"
log "$FINAL_TAGS"

# ----------------------
# Dry Run: Show, then Exit
# ----------------------
if [ "$DRY_RUN" = true ]; then
    echo "Dry run enabled — no changes written."
    [ "$TAGS_EXISTS" = "true" ] && echo "Would update <Tags> to:" || echo "Would insert new <Tags>:"
    echo "$FINAL_TAGS"
    rm -rf "$TMP_DIR"
    exit 0
fi

# ----------------------
# Write Tags
# ----------------------
if [ -n "$NEW_TAGS" ]; then
    if [ "$TAGS_EXISTS" = "true" ]; then
        xmlstarlet ed -L -u "//ComicInfo/Tags" -v "$FINAL_TAGS" "$XML_FILE"
    else
        xmlstarlet ed -L -s "//ComicInfo" -t elem -n "Tags" -v "$FINAL_TAGS" "$XML_FILE"
    fi
    log "Tags updated."
else
    log "No new tags to add."
fi

# ----------------------
# Repack Archive
# ----------------------
if [ "$BACKUP_MODE" = true ]; then
    OUTPUT_FILE="${CBZ_FILE%.cbz}_updated.cbz"
    log "Writing updated CBZ to: $OUTPUT_FILE"
else
    OUTPUT_FILE="$CBZ_FILE"
    log "Overwriting original CBZ file."
fi

zip -r -X -qq "$OUTPUT_FILE" -j "$TMP_DIR"/*

# ----------------------
# Clean up
# ----------------------
rm -rf "$TMP_DIR"

log "Done."
