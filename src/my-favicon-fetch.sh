#!/usr/bin/env bash
################################################################################
# src/my-favicon-fetch.sh
#
# Fetch favicons from a URL and save them to a local directory.
# ICO files are automatically extracted to PNGs via ImageMagick.
#
# Usage:
#   chmod +x ./src/my-favicon-fetch.sh
#   my-favicon-fetch --install
#   my-favicon-fetch -u https://codeberg.org
#   my-favicon-fetch -u https://sidisinsane.github.io/vscode-theme-humanuals/
################################################################################

SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "$SCRIPT_DIR/libs/core.sh"

BIN_NAME=$(get_bin_name)

DEFAULT_OUTPUT=$(get_config "output")
mapfile -t ICONS < <(get_config_array "icons")

ARGS=(
  "u|url|value||true|target URL (e.g. https://codeberg.org)"
  "o|output|value|$DEFAULT_OUTPUT|true|output directory"
)

DEPS=("curl" "magick")

# _fetch_favicon <url> <output_path>
# Downloads a single favicon if it returns HTTP 200.
# Returns 0 on success, 1 if not found.
_fetch_favicon() {
  local url="$1"
  local output="$2"
  local dir
  dir=$(dirname "$output")

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url")

  if [[ "$http_code" -eq 200 ]]; then
    mkdir -p "$dir"
    echo -e "${PURPLE}Saving '$url' → '$output'${COLOR_OFF}"
    curl -s -o "$output" "$url"
    return 0
  fi

  return 1
}

# _extract_ico <file> <dir>
# Extracts all sizes from an ICO file as individual PNGs.
_extract_ico() {
  local file="$1"
  local dir="$2"

  echo -e "${PURPLE}Extracting PNGs from '$file'${COLOR_OFF}"
  magick "$file" -set filename:size "%wx%h" "$dir/favicon-%[filename:size].png" > /dev/null 2>&1
}

main() {
  url_parse "$URL"

  local base_dir="$OUTPUT/$URL_HOST"
  [[ -n "$URL_PATH" ]] && base_dir="$OUTPUT/$URL_HOST/$URL_PATH"

  local found=0

  for icon in "${ICONS[@]}"; do
    local file ext target output
    file=$(basename "$icon")
    ext="${file##*.}"
    target="${URL%/}/$icon"
    output="$base_dir/$file"

    if _fetch_favicon "$target" "$output"; then
      (( found++ ))
      [[ "$ext" == "ico" ]] && _extract_ico "$output" "$base_dir"
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    echo -e "${YELLOW}No favicons found at $URL${COLOR_OFF}"
  else
    echo -e "${GREEN}$found favicon(s) saved to '$base_dir'${COLOR_OFF}"
  fi
}

run "$@"