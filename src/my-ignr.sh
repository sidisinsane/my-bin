#!/usr/bin/env bash
################################################################################
# src/my-ignr.sh
#
# Generate an ignore file for the current project.
#
# Usage:
#   chmod +x ./src/my-ignr.sh
#   my-ignr --install       # create bin symlink (first time only)
#   my-ignr
#   my-ignr -o .fdignore
#   my-ignr -o .gitignore -l python
################################################################################

SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "$SCRIPT_DIR/libs/core.sh"

BIN_NAME=$(get_bin_name)

DEFAULT_OUTPUT=$(get_config "output")

ARGS=(
  "o|output|value|$DEFAULT_OUTPUT|true|output file"
  "l|lang|value||false|language to add (e.g. python, node)"
)

DEPS=("jq" "ignr")

main() {
  if [[ -f "$OUTPUT" ]]; then
    echo -e "${PURPLE}$OUTPUT already exists, skipping.${COLOR_OFF}"
    return
  fi

  if [[ -n "$LANG" ]]; then
    ignr generate --no-detect --print --force --add macos --add vscode --add "$LANG" | tee "$OUTPUT"
  else
    ignr generate --print --force | tee "$OUTPUT"
  fi
}

run "$@"
