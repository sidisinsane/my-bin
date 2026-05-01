#!/usr/bin/env bash
################################################################################
# src/libs/core.sh
#
# A robust, "pure Bash" library for argument parsing, config management,
# and dependency validation.
#
# Features:
#   - Layered config: system config (config.json) + user overrides
#     (my-bin.config.json in PWD). User config always wins.
#   - Dependency registry: declare deps by name only; descriptions, URLs,
#     and install hints are looked up from dependencies.json automatically.
#   - Structured argument parsing: short/long flags, booleans, defaults,
#     and required validation.
#   - Auto-generated help menu with dep install hints.
#   - Clean script contract: define BIN_NAME, ARGS, DEPS, main() then run().
#
# Usage:
#   SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
#   SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
#   source "$SCRIPT_DIR/libs/core.sh"
#
#   BIN_NAME=$(get_bin_name)
#
#   # Fetch config values — user config overrides system config automatically.
#   # get_config <key>          → scalar value
#   # get_config_array <key>    → one item per line (use with mapfile)
#   DEFAULT_OUTPUT=$(get_config "output")
#   mapfile -t IGNORE_FILES < <(get_config_array "ignore-files")
#
#   # Format: short|long|type|default|required|description
#   # type: "value" | "bool"
#   ARGS=(
#     "o|output|value|$DEFAULT_OUTPUT|true|output file"
#     "v|verbose|bool||false|enable verbose output"
#     "d|dry-run|bool||false|simulate execution"
#   )
#
#   # Dep names only — details are looked up from dependencies.json.
#   DEPS=("jq" "fd" "tree")
#
#   main() {
#     echo "output:  $OUTPUT"
#     echo "verbose: $VERBOSE"
#   }
#
#   run "$@"
################################################################################

# Prevent execution (must be sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "❌ This script is a library and must be sourced, not executed." >&2
  exit 1
fi

################################################################################
# ANSI COLORS
################################################################################

RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
COLOR_OFF="\033[0m"

################################################################################
# PATHS
################################################################################

_LIB_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
_BIN_DIR="$_LIB_DIR/../../bin"
_SYSTEM_CONFIG="$_LIB_DIR/../../config.json"
_DEPS_REGISTRY="$_LIB_DIR/../../dependencies.json"
_USER_CONFIG="$PWD/my-bin.config.json"

################################################################################
# CONFIG
################################################################################

# get_config <key>
# Returns a scalar value for the current BIN_NAME from the merged config.
# User config wins over system config; empty string if not found in either.
get_config() {
  local key="$1"
  local val=""

  if [[ -f "$_USER_CONFIG" ]]; then
    val=$(jq -r --arg bin "$BIN_NAME" --arg key "$key" \
      '.[$bin][$key] // empty' "$_USER_CONFIG" 2>/dev/null)
  fi

  if [[ -z "$val" && -f "$_SYSTEM_CONFIG" ]]; then
    val=$(jq -r --arg bin "$BIN_NAME" --arg key "$key" \
      '.[$bin][$key] // empty' "$_SYSTEM_CONFIG" 2>/dev/null)
  fi

  echo "$val"
}

# get_config_array <key>
# Returns array values one per line for use with mapfile.
# User config wins over system config; empty output if not found in either.
get_config_array() {
  local key="$1"
  local val=""

  if [[ -f "$_USER_CONFIG" ]]; then
    val=$(jq -r --arg bin "$BIN_NAME" --arg key "$key" \
      '.[$bin][$key] // empty | if type == "array" then .[] else . end' \
      "$_USER_CONFIG" 2>/dev/null)
  fi

  if [[ -z "$val" && -f "$_SYSTEM_CONFIG" ]]; then
    val=$(jq -r --arg bin "$BIN_NAME" --arg key "$key" \
      '.[$bin][$key] // empty | if type == "array" then .[] else . end' \
      "$_SYSTEM_CONFIG" 2>/dev/null)
  fi

  echo "$val"
}

################################################################################
# DEPS
################################################################################

# _get_dep_field <bin> <field>
# Looks up a field (description | url | cmds.install) for a dep in the registry.
_get_dep_field() {
  local bin="$1"
  local field="$2"

  [[ ! -f "$_DEPS_REGISTRY" ]] && return

  jq -r --arg bin "$bin" --arg field "$field" \
    '.[$bin][$field] // empty' "$_DEPS_REGISTRY" 2>/dev/null
}

# _get_dep_install <bin>
# Returns the install command for a dep, e.g. "brew install fd".
_get_dep_install() {
  local bin="$1"

  [[ ! -f "$_DEPS_REGISTRY" ]] && return

  jq -r --arg bin "$bin" \
    '.[$bin].cmds.install // empty' "$_DEPS_REGISTRY" 2>/dev/null
}

################################################################################
# ENGINE
################################################################################

get_bin_name() {
  local base
  base=$(basename "$(realpath "$0")")
  echo "${base%.*}"
}

get_root_name() {
  basename "$(pwd)"
}

to_var_name() {
  echo "$1" | tr '[:lower:]-' '[:upper:]_'
}

show_help() {
  local exit_code="${1:-0}"

  echo "Usage: $BIN_NAME [OPTIONS]"
  echo ""
  echo "Options:"

  for entry in "${ARGS[@]}"; do
    IFS='|' read -r s l type d req desc <<< "$entry"

    local status=""
    [[ "$req" == "true" && "$type" != "bool" ]] && status="[REQUIRED]"
    [[ -n "$d" && "$type" == "value" ]]          && status="[Default: $d]"
    [[ "$type" == "bool" ]]                       && status="[flag]"

    printf "  %-20s %-38s %s\n" "-$s, --$l" "$desc" "$status"
  done

  printf "  %-20s %-38s %s\n" "-h, --help" "show this help message" "[flag]"

  if [[ ${#DEPS[@]} -gt 0 ]]; then
    echo ""
    echo "Dependencies:"
    for bin in "${DEPS[@]}"; do
      local desc url install
      desc=$(_get_dep_field "$bin" "description")
      url=$(_get_dep_field "$bin" "url")
      install=$(_get_dep_install "$bin")

      printf "  - %-13s %-38s" "$bin" "${desc:-n/a}"
      [[ -n "$url" ]]     && printf " %s" "$url"
      echo ""
      [[ -n "$install" ]] && printf "    install: %s\n" "$install"
    done
  fi

  exit "$exit_code"
}

install_bin() {
  local bin_dir="$_LIB_DIR/../../bin"
  local target="$bin_dir/$BIN_NAME"

  if [[ -L "$target" ]]; then
    echo -e "${PURPLE}$BIN_NAME is already installed in bin/.${COLOR_OFF}"
  else
    mkdir -p "$bin_dir"
    ln -s "$(realpath "$0")" "$target"
    echo -e "${GREEN}$BIN_NAME installed to bin/.${COLOR_OFF}"
  fi
}

init_defaults() {
  for entry in "${ARGS[@]}"; do
    IFS='|' read -r s l type d req desc <<< "$entry"

    local var_name
    var_name=$(to_var_name "$l")

    if [[ "$type" == "bool" ]]; then
      declare -g "$var_name"="false"
    elif [[ -n "$d" ]]; then
      declare -g "$var_name"="$d"
    fi
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help 0
        ;;
      --install)
        install_bin
        exit 0
        ;;
      *)
        local found=false

        for entry in "${ARGS[@]}"; do
          IFS='|' read -r s l type d req desc <<< "$entry"

          if [[ "$1" == "-$s" || "$1" == "--$l" ]]; then
            local var_name
            var_name=$(to_var_name "$l")

            if [[ "$type" == "bool" ]]; then
              declare -g "$var_name"="true"
              shift
            else
              if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo -e "❌ ${RED}Error:${COLOR_OFF} Option '$1' requires a value\n"
                show_help 1
              fi
              declare -g "$var_name"="$2"
              shift 2
            fi

            found=true
            break
          fi
        done

        if ! $found; then
          echo -e "❌ ${RED}Error:${COLOR_OFF} Unknown option '$1'\n"
          show_help 1
        fi
        ;;
    esac
  done
}

check_dependencies() {
  for bin in "${DEPS[@]}"; do
    if ! command -v "$bin" &>/dev/null; then
      local desc install
      desc=$(_get_dep_field "$bin" "description")
      install=$(_get_dep_install "$bin")

      echo -e "❌ ${RED}Error:${COLOR_OFF} Missing dependency '$bin'"
      [[ -n "$desc" ]]    && echo -e "   description: $desc"
      [[ -n "$install" ]] && echo -e "   install:     $install"
      echo ""
      exit 1
    fi
  done
}

validate_required_args() {
  for entry in "${ARGS[@]}"; do
    IFS='|' read -r s l type d req desc <<< "$entry"

    if [[ "$req" == "true" ]]; then
      local var_name
      var_name=$(to_var_name "$l")

      if [[ "$type" == "bool" ]]; then
        if [[ "${!var_name}" != "true" ]]; then
          echo -e "❌ ${RED}Error:${COLOR_OFF} Missing required flag --$l (-$s)\n"
          show_help 1
        fi
      else
        if [[ -z "${!var_name:-}" ]]; then
          echo -e "❌ ${RED}Error:${COLOR_OFF} Missing required argument --$l (-$s)\n"
          show_help 1
        fi
      fi
    fi
  done
}

print_enabled_flags() {
  for entry in "${ARGS[@]}"; do
    IFS='|' read -r s l type d req desc <<< "$entry"

    if [[ "$type" == "bool" ]]; then
      local var_name
      var_name=$(to_var_name "$l")
      [[ "${!var_name}" == "true" ]] && echo -e "${BLUE}${l} enabled${COLOR_OFF}"
    fi
  done
}

validate_contract() {
  [[ -z "${BIN_NAME:-}" ]]          && { echo "❌ BIN_NAME is not set"; exit 1; }
  [[ ${#ARGS[@]} -eq 0 ]]           && { echo "❌ ARGS is empty"; exit 1; }
  [[ "$(type -t main)" != "function" ]] && { echo "❌ main() is not defined"; exit 1; }
}

run() {
  validate_contract
  init_defaults
  parse_args "$@"
  check_dependencies
  validate_required_args

  echo -e "${YELLOW}▶ ${BIN_NAME}${COLOR_OFF}"
  print_enabled_flags

  main "$@"

  # Auto-install on first successful run; --install can still force it manually
  local target="$_BIN_DIR/$BIN_NAME"
  [[ ! -L "$target" ]] && install_bin

  echo -e "✅ ${GREEN}${BIN_NAME} done.${COLOR_OFF}"
}
