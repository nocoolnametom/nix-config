#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix
#shellcheck shell=bash

# Bumps pkgVersion/pkgBuild and every platform hash in ./default.nix.
#
#   ./update_hashes.sh              # latest non-prerelease GitHub release
#   ./update_hashes.sh 3.5.0-release.1585   # a specific upstream version
#
# Upstream versions carry a build-channel infix (3.5.0-release.1585), which this
# splits into pkgVersion (3.5.0) and pkgBuild (1585).

set -euo pipefail

dirname="$(cd "$(dirname "$0")" && pwd)"
input_file="$dirname/default.nix"
repo="Whisparr/Whisparr-Eros"

# Platform attr name in default.nix -> release asset infix
declare -A platforms=(
	["aarch64-darwin"]="osx-arm64"
	["aarch64-linux"]="linux-arm64"
	["x86_64-darwin"]="osx-x64"
	["x86_64-linux"]="linux-x64"
)

if [ -n "${1:-}" ]; then
	url_version=$1
else
	echo "Fetching the latest release of $repo..."
	url_version=$(
		curl -sf "https://api.github.com/repos/$repo/releases" |
			jq -r 'map(select(.prerelease == false)) | .[0].tag_name' |
			sed 's/^v//'
	)
fi

if [ -z "$url_version" ] || [ "$url_version" = "null" ]; then
	echo "Could not determine a version to update to." >&2
	exit 1
fi

# 3.5.0-release.1585 -> pkgVersion=3.5.0, pkgBuild=1585
pkg_version=${url_version%%-*}
pkg_build=${url_version##*.}

if [ "$pkg_version" = "$url_version" ] || [ -z "$pkg_build" ]; then
	echo "Unexpected version format '$url_version' (want e.g. 3.5.0-release.1585)." >&2
	exit 1
fi

current_version=$(sed -n 's/.*pkgVersion = "\(.*\)".*/\1/p' "$input_file")
current_build=$(sed -n 's/.*pkgBuild = "\(.*\)".*/\1/p' "$input_file")
echo "Current: $current_version.$current_build"
echo "Target:  $pkg_version.$pkg_build  (upstream $url_version)"

if [ "$current_version.$current_build" = "$pkg_version.$pkg_build" ]; then
	echo "whisparr-eros is up-to-date."
	exit 0
fi

for platform in "${!platforms[@]}"; do
	name=${platforms[$platform]}
	url="https://github.com/$repo/releases/download/v${url_version}/Whisparr.eros.${url_version}.${name}.tar.gz"

	echo "Fetching the hash for the \`$platform\` system..."
	hash=$(
		nix store prefetch-file --json \
			--name "whisparr-eros-${url_version}-${name}.tar.gz" "$url" |
			jq -r .hash
	)

	if [ -z "$hash" ] || [ "$hash" = "null" ]; then
		echo "Failed to fetch the hash for platform: $platform ($name)" >&2
		exit 1
	fi

	# Scope the replacement to the matching platform block so the four hashes
	# don't overwrite each other.
	sed -i "/^    $platform = {/,/};/ s|hash = \".*\"|hash = \"${hash}\"|" "$input_file"
done

sed -i "s/pkgVersion = \".*\"/pkgVersion = \"${pkg_version}\"/" "$input_file"
sed -i "s/pkgBuild = \".*\"/pkgBuild = \"${pkg_build}\"/" "$input_file"

echo "Updated whisparr-eros to $pkg_version.$pkg_build with new hashes."
