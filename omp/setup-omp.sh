#!/usr/bin/env bash
set -euo pipefail

OMP_AGENT_DIR="${OMP_AGENT_DIR:-$HOME/.omp/agent}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
OMP_VERSION="${OMP_VERSION:-17.0.5}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

copy_config() {
  mkdir -p "$OMP_AGENT_DIR"
  cp "$CONFIG_DIR/config.yml" "$OMP_AGENT_DIR/config.yml"
  cp "$CONFIG_DIR/models.yml" "$OMP_AGENT_DIR/models.yml"
}

install_omp() {
  if command -v omp >/dev/null 2>&1; then
    local current_version
    current_version="$(omp --version 2>&1 | head -1)"
    echo "omp already installed: $current_version"
    return
  fi

  echo "Installing omp v${OMP_VERSION}..."
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  local tmp
  tmp="$(mktemp)"
  curl -fsSL "https://github.com/anthropics/omp/releases/download/v${OMP_VERSION}/omp-linux-${arch}" -o "$tmp"
  chmod +x "$tmp"
  mkdir -p "$HOME/.local/bin"
  mv "$tmp" "$HOME/.local/bin/omp"
  echo "Installed omp v${OMP_VERSION} to $HOME/.local/bin/omp"
}

validate_config() {
  node <<'EOF_NODE'
const fs = require("fs");
const path = require("path");
const home = process.env.HOME;
const agentDir = process.env.OMP_AGENT_DIR || `${home}/.omp/agent`;
for (const file of [
  `${agentDir}/config.yml`,
  `${agentDir}/models.yml`,
]) {
  const content = fs.readFileSync(file, "utf8");
  // Basic YAML sanity: non-empty, starts with valid content
  if (!content.trim()) {
    throw new Error(`${file} is empty`);
  }
  console.log(`ok ${file}`);
}
EOF_NODE
}

verify_omp() {
  omp --version
}

main() {
  require_cmd curl
  require_cmd node

  install_omp
  copy_config
  validate_config
  verify_omp
}

main "$@"
