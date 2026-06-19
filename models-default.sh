#!/usr/bin/env bash
set -euo pipefail

QWEN_MODEL="${QWEN_MODEL:-Qwen3.6-27B}"
GEMMA_MODEL="${GEMMA_MODEL:-Gemma-4-31B}"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

node <<'EOF_NODE'
const fs = require("fs");
const path = require("path");

const qwenModel = process.env.QWEN_MODEL || "Qwen3.6-27B";
const gemmaModel = process.env.GEMMA_MODEL || "Gemma-4-31B";
const piAgentDir = process.env.PI_CODING_AGENT_DIR || `${process.env.HOME}/.pi/agent`;
const opencodeConfigDir = process.env.OPENCODE_CONFIG_DIR || `${process.env.HOME}/.config/opencode`;

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, data) {
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
  console.log(`updated ${file}`);
}

function ensureOpenCodeModels(config) {
  const provider = config.provider?.["llama.cpp"];
  if (!provider?.models) return;

  provider.models[qwenModel] = {
    name: "Qwen3.6 27B",
    attachment: true,
    modalities: { input: ["text", "image"], output: ["text"] },
    limit: { context: 262144, output: 65536 },
  };
  provider.models[gemmaModel] = {
    name: "Gemma 4 31B",
    attachment: true,
    modalities: { input: ["text", "image"], output: ["text"] },
    limit: { context: 262144, output: 65536 },
  };
}

function patchPiSettings(file) {
  if (!fs.existsSync(file)) return;
  const config = readJson(file);
  config.defaultProvider = "llama.cpp";
  config.defaultModel = qwenModel;
  config.enabledModels = [`llama.cpp/${qwenModel}`, `llama.cpp/${gemmaModel}`];

  const overrides = config.subagents?.agentOverrides || {};
  for (const override of Object.values(overrides)) {
    override.model = `llama.cpp/${qwenModel}`;
    if (Object.hasOwn(override, "thinking")) override.thinking = "high";
  }

  writeJson(file, config);
}

function upsertPiModel(models, model) {
  const existing = models.find((entry) => entry.id === model.id);
  if (existing) Object.assign(existing, model);
  else models.push(model);
}

function patchPiModels(file) {
  if (!fs.existsSync(file)) return;
  const config = readJson(file);
  const provider = config.providers?.["llama.cpp"];
  if (!provider?.models) return;

  const thinkingLevelMap = {
    off: null,
    minimal: "low",
    low: "low",
    medium: "medium",
    high: "high",
    xhigh: "high",
  };

  upsertPiModel(provider.models, {
    id: qwenModel,
    name: "Qwen3.6 27B",
    input: ["text", "image"],
    contextWindow: 262144,
    maxTokens: 65536,
    reasoning: true,
    thinkingLevelMap,
  });
  upsertPiModel(provider.models, {
    id: gemmaModel,
    name: "Gemma 4 31B",
    input: ["text", "image"],
    contextWindow: 262144,
    maxTokens: 65536,
    reasoning: true,
    thinkingLevelMap,
  });

  writeJson(file, config);
}

function patchOpenCodeFile(file) {
  const config = readJson(file);
  ensureOpenCodeModels(config);

  const agents = config.agent || {};
  for (const agent of Object.values(agents)) {
    agent.model = `llama.cpp/${qwenModel}`;
  }

  writeJson(file, config);
}

patchPiModels(path.join(piAgentDir, "models.json"));
patchPiSettings(path.join(piAgentDir, "settings.json"));

if (fs.existsSync(opencodeConfigDir)) {
  for (const name of fs.readdirSync(opencodeConfigDir)) {
    if (name.endsWith(".jsonc")) patchOpenCodeFile(path.join(opencodeConfigDir, name));
  }
}
EOF_NODE

echo "Configured Pi and OpenCode agents to use Qwen everywhere."
