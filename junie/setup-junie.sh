#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TARGET_DIR="${JUNIE_HOME:-$HOME/.junie}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

copy_config() {
  mkdir -p "$TARGET_DIR/models" "$TARGET_DIR/mcp"

  cp "$CONFIG_DIR/config.json" "$TARGET_DIR/config.json"
  cp "$CONFIG_DIR/models/"*.json "$TARGET_DIR/models/"
  cp "$CONFIG_DIR/mcp/mcp.json" "$TARGET_DIR/mcp/mcp.json"
}

validate_json() {
  node <<'EOF_NODE'
const fs = require("fs");
const path = require("path");

const targetDir = process.env.JUNIE_HOME || `${process.env.HOME}/.junie`;
const files = [
  path.join(targetDir, "config.json"),
  path.join(targetDir, "mcp", "mcp.json"),
  ...fs.readdirSync(path.join(targetDir, "models"))
    .filter((name) => name.endsWith(".json"))
    .map((name) => path.join(targetDir, "models", name)),
];

for (const file of files) {
  JSON.parse(fs.readFileSync(file, "utf8"));
  console.log(`ok ${file}`);
}
EOF_NODE
}

verify_junie() {
  if command -v junie >/dev/null 2>&1; then
    junie --version
  else
    echo "Junie is not installed or not on PATH; config was copied only." >&2
  fi
}

main() {
  require_cmd node

  copy_config
  validate_json
  verify_junie
}

main "$@"
