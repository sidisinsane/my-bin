#!/usr/bin/env bash
################################################################################
# src/my-img-stitcher.sh
#
# Stitch multiple images together using config-defined jobs.
#
# Usage:
#   chmod +x ./src/my-img-stitcher.sh
#   my-img-stitcher --install
#   my-img-stitcher
#   my-img-stitcher -vt
################################################################################

SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "$SCRIPT_DIR/libs/core.sh"

BIN_NAME=$(get_bin_name)

ARGS=(
  "vt|vertical|bool||false|stitch vertically"
)

DEPS=("jq" "magick")

main() {
  local jobs
  jobs=$(get_config_json "images")

  while IFS= read -r job; do
    local gap output
    gap=$(echo "$job"         | jq -r '.gap')
    output=$(echo "$job"      | jq -r '.output')

    mapfile -t input_files < <(echo "$job" | jq -r '.input[]')
    local count="${#input_files[@]}"

    local geometry tile
    if [[ "$VERTICAL" == "true" ]]; then
      geometry="+0+$((gap / 2))"
      tile="1x${count}"
    else
      geometry="+$((gap / 2))+0"
      tile="${count}x1"
    fi

    magick montage \
      "${input_files[@]}" \
      -background none \
      -geometry "$geometry" \
      -tile "$tile" \
      "$output"

  done < <(echo "$jobs" | jq -c '.[]')
}

run "$@"