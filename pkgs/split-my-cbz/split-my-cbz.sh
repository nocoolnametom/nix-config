#!/usr/bin/env bash

# Check if the .cbz file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <cbz_file>"
  exit 1
fi

# Input .cbz file
cbz_file="$1"
base_name=$(basename "$cbz_file" .cbz)

# Temporary directory to extract files
temp_dir=$(mktemp -d)

# Extract the .cbz file
unzip -q "$cbz_file" -d "$temp_dir"

# Path to the ComicInfo.xml file
xml_file="$temp_dir/ComicInfo.xml"

# Check if ComicInfo.xml exists
if [ ! -f "$xml_file" ]; then
  echo "ComicInfo.xml not found in the archive."
  rm -rf "$temp_dir"
  exit 1
fi

# Extract the original Title from the root XML
original_title=$(xmlstarlet sel -t -v "//Title" "$xml_file")

# Extract the list of pages with bookmarks
bookmarks=$(xmlstarlet sel -t -m "//Page[@Bookmark]" -v "@Image" -o " " "$xml_file")

# Split the bookmarks into an array
IFS=' ' read -r -a bookmark_array <<< "$bookmarks"

# Add the last page as a bookmark to handle the final segment
last_page=$(xmlstarlet sel -t -v "count(//Page)" "$xml_file")
bookmark_array+=("$last_page")

# Get the list of image files in alphanumeric order, handling spaces in filenames
image_files=()
while IFS= read -r -d '' file; do
  image_files+=("$file")
done < <(find "$temp_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.webp" -o -iname "*.jpeg" -o -iname "*.gif" \) -print0 | sort -z)

# Check if image files were found
if [ ${#image_files[@]} -eq 0 ]; then
  echo "No image files found in the archive."
  rm -rf "$temp_dir"
  exit 1
fi

# Initialize variables
start_page=0
archive_number=1

# Loop through the bookmarks and create smaller archives
for bookmark in "${bookmark_array[@]}"; do
  # Create a new directory for the current segment
  segment_dir="$temp_dir/segment_$archive_number"
  mkdir -p "$segment_dir"

  # Copy the ComicInfo.xml file without the Pages and PageCount tags
  xmlstarlet ed -d "//Pages" -d "//PageCount" "$xml_file" > "$segment_dir/ComicInfo.xml"

  # Update the ComicInfo.xml file for the sub-archive
  xmlstarlet ed -L \
    -u "//Number" -v "$archive_number" \
    -u "//LanguageISO" -v "en" \
    "$segment_dir/ComicInfo.xml"

  # Ensure the LanguageISO tag exists with a value of "en"
  if ! xmlstarlet sel -t -v "//LanguageISO" "$segment_dir/ComicInfo.xml" > /dev/null 2>&1; then
    xmlstarlet ed -L -s "//ComicInfo" -t elem -n "LanguageISO" -v "en" "$segment_dir/ComicInfo.xml"
  fi

  # Set the Title for the sub-archive
  if [ "$archive_number" -gt 1 ]; then
    # Get the Bookmark value for the current segment's starting page
    bookmark_title=$(xmlstarlet sel -t -m "//Page[@Image=$((start_page))]" -v "@Bookmark" "$xml_file")
    if [ -n "$bookmark_title" ]; then
      xmlstarlet ed -L -u "//Title" -v "$bookmark_title" "$segment_dir/ComicInfo.xml"
    else
      # Default to the original Title if no Bookmark value is found
      xmlstarlet ed -L -u "//Title" -v "$original_title" "$segment_dir/ComicInfo.xml"
    fi
  else
    # For the first archive, use the original Title
    xmlstarlet ed -L -u "//Title" -v "$original_title" "$segment_dir/ComicInfo.xml"
  fi

  # Copy the images for the current segment
  for ((i=start_page; i<bookmark; i++)); do
    cp "${image_files[$i]}" "$segment_dir/"
  done

  # Create the new .cbz archive
  new_cbz_file="${base_name} c$(printf "%02d" $archive_number).cbz"
  (cd "$segment_dir" && zip -q -r "$new_cbz_file" .)
  mv "$segment_dir/$new_cbz_file" .

  # Update the start page for the next segment
  start_page=$bookmark
  archive_number=$((archive_number + 1))
done

# Clean up
rm -rf "$temp_dir"

echo "Splitting completed successfully."

