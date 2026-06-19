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

function exploreAgent(model) {
  return {
    mode: "subagent",
    model: `llama.cpp/${model}`,
    description: "Explore the local repository only: find files, search symbols and keywords, inspect code paths, and answer codebase questions without external research or edits.",
    prompt: "Explore only. Inspect the local repository with read-only tools. Use grep/glob/list/read and safe shell search commands to find relevant files, symbols, call paths, and implementation details. Return concise findings with concrete file references. Do not modify files. Do not use web search or external documentation; delegate broader dependency/API research to the research subagent.",
    permission: {
      edit: "deny",
      grep: "allow",
      glob: "allow",
      list: "allow",
      read: "allow",
      bash: {
        "*": "ask",
        pwd: "allow",
        ls: "allow",
        "ls *": "allow",
        tree: "allow",
        "tree *": "allow",
        "find *": "allow",
        "fd *": "allow",
        rg: "allow",
        "rg *": "allow",
        "grep *": "allow",
        "git status*": "allow",
        "git diff*": "allow",
        "git log*": "allow",
        "git show*": "allow",
        "git branch*": "allow",
        "git rev-parse*": "allow",
        "git grep*": "allow",
        "git ls-files*": "allow",
      },
      webfetch: "deny",
      websearch: "deny",
    },
  };
}

function setPiOverride(overrides, name, model, thinking) {
  if (!overrides[name]) return;
  overrides[name].model = `llama.cpp/${model}`;
  if (Object.hasOwn(overrides[name], "thinking")) overrides[name].thinking = thinking;
}

function patchPiSettings(file) {
  if (!fs.existsSync(file)) return;
  const config = readJson(file);
  config.defaultProvider = "llama.cpp";
  config.defaultModel = qwenModel;
  config.enabledModels = [`llama.cpp/${qwenModel}`, `llama.cpp/${gemmaModel}`];

  const overrides = config.subagents?.agentOverrides || {};
  setPiOverride(overrides, "researcher", gemmaModel, "medium");
  setPiOverride(overrides, "scout", gemmaModel, "medium");
  setPiOverride(overrides, "planner", qwenModel, "high");
  setPiOverride(overrides, "worker", qwenModel, "high");
  setPiOverride(overrides, "reviewer", gemmaModel, "medium");
  setPiOverride(overrides, "oracle", qwenModel, "high");

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

function setOpenCodeAgent(agents, name, model) {
  if (!agents[name]) return;
  agents[name].model = `llama.cpp/${model}`;
}

function patchOpenCodeFile(file) {
  const config = readJson(file);
  ensureOpenCodeModels(config);

  const agents = config.agent || {};
  if (Object.keys(agents).length > 0) agents.explore = exploreAgent(gemmaModel);
  setOpenCodeAgent(agents, "explore", gemmaModel);
  setOpenCodeAgent(agents, "research", gemmaModel);
  setOpenCodeAgent(agents, "plan", qwenModel);
  setOpenCodeAgent(agents, "build", qwenModel);
  setOpenCodeAgent(agents, "review", gemmaModel);

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

echo "Configured Pi and OpenCode agents to use mixed Qwen/Gemma assignments."
