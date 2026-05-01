# my-bin

A lightweight personal script manager for Bash. Write a script once, install it
as a named command, and never look up the arguments again.

---

## How It Works

`my-bin` provides a small library (`src/libs/core.sh`) that handles the
repetitive parts of writing CLI scripts — argument parsing, dependency checks,
config lookup, help generation, and bin installation. Each script sources the
library, declares its interface, and implements `main()`. Everything else is
taken care of.

Scripts are installed as symlinks in `bin/` and exposed on your `PATH`, so
`my-tree` works from anywhere just like any other command.

---

## Structure

```text
my-bin/
├── bin/                    # Symlinks to src scripts (auto-created on first run)
│   ├── my-ignr
│   └── my-tree
├── src/
│   ├── libs/
│   │   └── core.sh         # The library — source this in every script
│   ├── my-ignr.sh
│   └── my-tree.sh
├── config.json             # System config (defaults for all scripts)
├── dependencies.json       # Dependency registry (descriptions, URLs, install commands)
├── my-bin.config.json      # User config (overrides system config, lives in PWD)
└── README.md
```

### Config Layering

`core.sh` merges two config files at runtime. The user config always wins.

| File | Location | Purpose |
|---|---|---|
| `config.json` | repo root | System defaults, checked into version control |
| `my-bin.config.json` | `PWD` | Local overrides, can be gitignored |

Scripts never touch `jq` directly — use `get_config` and `get_config_array`
instead (see below).

### Dependency Registry

`dependencies.json` is the single source of truth for all external dependencies.
It stores descriptions, URLs, and install commands. Scripts declare which deps
they need by name only — the library handles the rest, including install hints
in error messages and the help menu.

---

## Usage

### Setup

Add `bin/` to your `PATH` in `~/.bashrc`:

```bash
export PATH="$HOME/path/to/my-bin/bin:$PATH"
```

### Running A Script

```bash
my-ignr                        # use defaults from config
my-ignr -o .fdignore           # override output file
my-ignr -o .gitignore -l node  # add a language-specific ignore pattern
my-tree
my-tree -o PROJECT.txt
```

### Help

Every script exposes a help menu:

```bash
my-tree --help
```

### Installing A Script Manually

On first successful run, a script installs itself automatically. To install
without running `main()`:

```bash
my-tree --install
```

---

## Adding A New Script

1. **Register in `config.json`** with any defaults your script needs:

```json
"my-thing": {
  "output": "output.txt"
}
```

2. **Register any new dependencies in `dependencies.json`:**

```json
"curl": {
  "description": "transfer data with URLs",
  "url": "https://curl.se",
  "cmds": {
    "check": "brew info curl",
    "install": "brew install curl"
  }
}
```

3. **Create `src/my-thing.sh`** and source the library:

```bash
#!/usr/bin/env bash

SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source "$SCRIPT_DIR/libs/core.sh"

BIN_NAME=$(get_bin_name)
```

4. **Pull config values** (optional):

```bash
DEFAULT_OUTPUT=$(get_config "output")
mapfile -t SOME_LIST < <(get_config_array "some-list")
```

5. **Declare arguments:**

```bash
# Format: short|long|type|default|required|description
# type: "value" | "bool"
ARGS=(
  "o|output|value|$DEFAULT_OUTPUT|true|output file"
  "v|verbose|bool||false|enable verbose output"
)
```

6. **Declare dependencies** (names only — details come from `dependencies.json`):

```bash
DEPS=("jq" "curl")
```

7. **Implement `main()`:**

```bash
main() {
  echo "output: $OUTPUT"
  [[ "$VERBOSE" == "true" ]] && echo "verbose mode on"
}
```

8. **Call `run()`:**

```bash
run "$@"
```

9. **Make it executable and run it once** to auto-install the symlink:

```bash
chmod +x ./src/my-thing.sh
./src/my-thing.sh
```

It will now be available as `my-thing` from anywhere on your `PATH`.
