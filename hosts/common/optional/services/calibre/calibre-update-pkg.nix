{
  pkgs ? import <nixpkgs> { },
}:

# This is here instead of the global pkgs because calibre cannot be built on darwin
# and the global pkgs must be available for all systems
pkgs.writeShellApplication (
  let
    calibreFileUpdate = pkgs.writeShellApplication {
      name = "calibreFileUpdate";

      runtimeInputs = [
        pkgs.bash
        pkgs.stable.calibre
        pkgs.gnugrep
        pkgs.gawk
        pkgs.xxHash
        pkgs.unzip
        pkgs.coreutils
      ];

      text = ''
        epub_file="$1"
        checksum_file="$2"
        libraryPath="$3"
        username="$4"
        password="$5"

        # Check if the current EPUB file exists in the directory by hash
        file_hash=$(xxhsum "$epub_file" | awk "{print \$1}")
        path=$(grep "$file_hash" "$checksum_file" | awk "{print \$2}" || true)

        # If the exact same file is already in the library, then we do nothing and continue to the next.
        if [ -n "$path" ]; then
          exit 0;
        fi

        # Get the title and author of the current EPUB file
        title=$(unzip -p "$epub_file" OEBPS/content.opf | grep -Po "(?<=<dc:title id=\"epub-title-1\">)[^<]*(?=</dc:title>)" | head -1 || true)
        if [ -z "$title" ]; then
          # If the title was not found in "OEBPS/content.opf", try "EPUB/content.opf"
          title=$(unzip -p "$epub_file" EPUB/content.opf | grep -Po "(?<=<dc:title id=\"epub-title-1\">)[^<]*(?=</dc:title>)" | head -1 || true)
        fi

        author=$(unzip -p "$epub_file" OEBPS/content.opf | grep -Po "(?<=<dc:creator id=\"epub-creator-1\">)[^<]*(?=</dc:creator>)" | head -1 || true)
        if [ -z "$author" ]; then
          # If the author was not found in "OEBPS/content.opf", try "EPUB/content.opf"
          author=$(unzip -p "$epub_file" EPUB/content.opf | grep -Po "(?<=<dc:creator id=\"epub-creator-1\">)[^<]*(?=</dc:creator>)" | head -1 || true)
        fi

        if [ -z "$author" ]; then
          exit 0;
        fi

        # Use calibredb to find any existing EPUB files with the same title and author in the Calibre Server DB
        existing_file=$(calibredb --with-library "$libraryPath" --username "$username" --password "$password" list --fields "title,authors" | grep "$title" | grep "$author" | awk "/^[0-9]+/ { print \$1 }" || true)

        # if [ -n "$existing_file" ]; then
        #   # Remove the existing file and then upload the current EPUB file to the destination directory
        #   calibredb --with-library "$libraryPath" --username "$username" --password "$password" remove_format "$existing_file" EPUB
        #   calibredb --with-library "$libraryPath" --username "$username" --password "$password" add_format "$existing_file" "$epub_file"
        # else
        #   # Use calibredb to add the current EPUB file to the destination directory
        #   calibredb --with-library "$libraryPath" --username "$username" --password "$password" add "$epub_file"
        # fi

        if [ -n "$existing_file" ]; then
          # Remove the existing file and then upload the current EPUB file to the destination directory
          calibredb --with-library "$libraryPath" --username "$username" --password "$password" remove "$existing_file"
        fi

        # Use calibredb to add the current EPUB file to the destination directory
        calibredb --with-library "$libraryPath" --username "$username" --password "$password" add "$epub_file"
      '';
    };
  in
  {
    name = "calibre-update";

    runtimeInputs = [
      pkgs.bash
      pkgs.xxHash
      pkgs.coreutils
    ];

    # The shell script itself
    text = ''
      # Check if the required number of arguments was provided
      if [ $# -ne 2 ]; then
        echo "Usage: $0 <source_directory> <dest_directory>"
        exit 1
      fi

      # Set the directory variables
      source_directory=$1
      dest_directory=$2

      libraryBase=$(basename "$2")
      library=${"$"}{libraryBase// /_}

      libraryPath="http://127.0.0.1:8080/#$library"
      username="admin"
      password="admin123"

      # Get the checksums of all of the EPUB files in the dest_directory
      checksum_file=$(mktemp)
      find "$dest_directory" -type f -name "*.epub" -exec xxhsum {} \; > "$checksum_file"

      # Iterate over the EPUB files in the directory
      find "$source_directory" -type f -name "*.epub" -exec "${calibreFileUpdate}/bin/calibreFileUpdate" {} "$checksum_file" "$libraryPath" "$username" "$password" \;
      # rm "$checksum_file"
    '';
  }
)
