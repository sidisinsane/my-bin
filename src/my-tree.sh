#!/usr/bin/env bash
################################################################################
# src/my-tree.sh
#
# Generate a project tree and write it to a file.
#
# Usage:
#   chmod +x ./src/my-tree.sh
#   my-tree --install       # create bin symlink (first time only)
#   my-tree
#   my-tree -o PROJECT.txt
################################################################################

SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "$SCRIPT_DIR/libs/core.sh"

BIN_NAME=$(get_bin_name)
ROOT_NAME=$(get_root_name)

DEFAULT_OUTPUT=$(get_config "output")
mapfile -t IGNORE_FILES < <(get_config_array "ignore-files")

ARGS=(
  "o|output|value|$DEFAULT_OUTPUT|true|output file"
)

DEPS=("fd" "tree")

main() {
  local ignore_file=""

  for f in "${IGNORE_FILES[@]}"; do
    if [[ -f "$PWD/$f" ]]; then
      ignore_file="$f"
      break
    fi
  done

  if [[ -z "$ignore_file" ]]; then
    echo -e "${PURPLE}No ignore file found, including all files.${COLOR_OFF}"
    fd --hidden --no-ignore | sort | tree --fromfile --dirsfirst --noreport -a -F -o "$OUTPUT"
  else
    echo -e "${PURPLE}Using $ignore_file.${COLOR_OFF}"
    fd --hidden --no-ignore --ignore-file "$ignore_file" | sort | tree --fromfile --dirsfirst --noreport -a -F -o "$OUTPUT"
  fi

  # Replace leading dot with the project root name (portable: macOS + Linux)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "1s|^\.|${ROOT_NAME}|" "$OUTPUT"
  else
    sed -i "1s|^\.|${ROOT_NAME}|" "$OUTPUT"
  fi
}

run "$@"
