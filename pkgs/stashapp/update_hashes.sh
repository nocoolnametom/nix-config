#!/usr/bin/env bash

# Check if version number is provided
if [ -z "$1" ]; then
  echo "Please provide a version number."
  exit 1
fi

# Assign the new version number
new_version=$1

# Input file where the original content is stored
input_file="./default.nix"

# Backup the original file before modifying
cp "$input_file" "${input_file}.bak"

# Declare an associative array of platform names
declare -A platforms
platforms=(
  ["aarch64-darwin"]="macos"
  ["aarch64-linux"]="linux-arm64v8"
  ["armv6l-linux"]="linux-arm32v6"
  ["armv7l-linux"]="linux-arm32v7"
  ["x86_64-linux"]="linux"
)

# Iterate through the platforms and fetch new hashes
for platform in "${!platforms[@]}"; do
  name=${platforms[$platform]}
  url="https://github.com/stashapp/stash/releases/download/v${new_version}/stash-${name}"
  
  # Fetch new sha256 using nix-prefetch-url
  new_hash=$(nix-prefetch-url --executable "$url")
  
  if [ -z "$new_hash" ]; then
    echo "Failed to fetch hash for platform: $platform, name: $name"
    exit 1
  fi
  
  # Use sed to update the corresponding sha256 hash in the file
  # This sed command ensures that we match the right platform block and update the hash
  sed -i.bak "/$platform/,/sha256/ s|sha256 = \".*\"|sha256 = \"${new_hash}\"|" "$input_file"
done

# Update the version number in the file
sed -i.bak "s/pkgVersion = \".*\"/pkgVersion = \"${new_version}\"/" "$input_file"

# Remove the backup files
rm "${input_file}.bak"

echo "File updated successfully with version $new_version and new hashes."
