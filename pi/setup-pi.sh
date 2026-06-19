#!/usr/bin/env bash
set -euo pipefail

PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PI_WEB_CONFIG="$HOME/.pi/web-search.json"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
QWEN_BASE_URL="${QWEN_BASE_URL:-http://9800x3d-96-5080-3x5070ti:8080/v1}"
QWEN_MODEL="${QWEN_MODEL:-Qwen3.6-27B}"
GEMMA_MODEL="${GEMMA_MODEL:-Gemma-4-31B}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

write_json_files() {
  mkdir -p "$PI_AGENT_DIR" "$HOME/.pi"

  cp "$CONFIG_DIR/agent/models.json" "$PI_AGENT_DIR/models.json"
  cp "$CONFIG_DIR/agent/mcp.json" "$PI_AGENT_DIR/mcp.json"
  cp "$CONFIG_DIR/agent/settings.json" "$PI_AGENT_DIR/settings.json"
  cp "$CONFIG_DIR/agent/AGENTS.md" "$PI_AGENT_DIR/AGENTS.md"
  cp "$CONFIG_DIR/web-search.json" "$PI_WEB_CONFIG"
}

install_pi_and_packages() {
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent

  pi install npm:pi-mcp-extension
  pi install npm:pi-web-access
  pi install npm:pi-subagents
  pi install npm:@narumitw/pi-plan-mode
  pi install npm:pi-intercom
  pi install npm:pi-lens
}

validate_json() {
  node <<'EOF_NODE'
const fs = require("fs");
const home = process.env.HOME;
const agentDir = process.env.PI_CODING_AGENT_DIR || `${home}/.pi/agent`;
for (const file of [
  `${agentDir}/settings.json`,
  `${agentDir}/models.json`,
  `${agentDir}/mcp.json`,
  `${home}/.pi/web-search.json`,
]) {
  JSON.parse(fs.readFileSync(file, "utf8"));
  console.log(`ok ${file}`);
}
EOF_NODE
}

verify_pi() {
  pi --version
  pi --list-models qwen --offline
  pi --list-models gemma --offline

  if curl -fsS "$QWEN_BASE_URL/models" >/dev/null 2>&1; then
    pi --offline --no-session --no-tools -p "Reply with exactly: pi-qwen-ok"
  else
    echo "Skipped inference test: Qwen endpoint is not reachable at $QWEN_BASE_URL" >&2
  fi

  echo
  echo "GitLab MCP is configured as gitlab-telekom with eager OAuth startup."
  echo "To authenticate it later, run: pi"
  echo "Then inside Pi run: /mcp:auth gitlab-telekom"
}

main() {
  require_cmd npm
  require_cmd node
  require_cmd curl

  install_pi_and_packages
  write_json_files
  validate_json
  verify_pi
}

main "$@"
