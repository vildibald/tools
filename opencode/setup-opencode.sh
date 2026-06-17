#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TARGET_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
OPENCODE_VERSION="${OPENCODE_VERSION:-1.17.7}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

copy_config() {
  mkdir -p "$TARGET_DIR"
  cp "$CONFIG_DIR"/*_opencode.jsonc "$TARGET_DIR"/
  cp "$CONFIG_DIR/opencode.jsonc" "$TARGET_DIR/opencode.jsonc"
  cp "$CONFIG_DIR/package.json" "$TARGET_DIR/package.json"
  cp "$CONFIG_DIR/package-lock.json" "$TARGET_DIR/package-lock.json"
  cp "$CONFIG_DIR/.gitignore" "$TARGET_DIR/.gitignore"
}

install_opencode() {
  npm install -g "opencode-ai@${OPENCODE_VERSION}"
  npm --prefix "$TARGET_DIR" install
}

validate_config() {
  node <<'EOF_NODE'
const fs = require("fs");
const path = require("path");
const dir = process.env.OPENCODE_CONFIG_DIR || `${process.env.HOME}/.config/opencode`;
for (const file of fs.readdirSync(dir).filter((name) => name.endsWith(".jsonc"))) {
  JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
  console.log(`ok ${path.join(dir, file)}`);
}
EOF_NODE
}

verify_opencode() {
  opencode --version
}

main() {
  require_cmd npm
  require_cmd node

  copy_config
  install_opencode
  validate_config
  verify_opencode
}

main "$@"
