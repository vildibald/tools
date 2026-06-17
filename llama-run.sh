#!/usr/bin/env bash

set -euo pipefail

export GGML_CUDA_P2P=1

exec /opt/llama.cpp/build-cuda/bin/llama-server \
  --host 0.0.0.0 \
  --port 8080 \
  --model /opt/models/qwen36/27b/unsloth/Qwen3.6-27B-Q8_0.gguf \
  --ctx-size 262144 \
  --device CUDA0,CUDA1,CUDA2,CUDA3 \
  --fit off \
  --split-mode tensor \
  --tensor-split 1,1,1,1 \
  --gpu-layers all \
  --flash-attn on \
  --kv-offload \
  --cache-type-k f16 \
  --cache-type-v f16 \
  --batch-size 4096 \
  --ubatch-size 1024 \
  --parallel 1 \
  --jinja \
  --top-p 0.95 \
  --top-k 20 \
  --temp 0.6 \
  --min-p 0.00 \
  --spec-type draft-mtp \
  --spec-draft-n-max 3 \
  --no-spec-draft-backend-sampling \
  --no-cache-idle-slots \
  --ctx-checkpoints 64 \
  --checkpoint-min-step 2048 \
  --cache-ram 32768 \
  --presence-penalty 0.0 \
  --repeat-penalty 1.0 \
  --swa-full \
  --mmproj /opt/models/qwen36/27b/unsloth/mmproj-BF16.gguf \
  --image-min-tokens 1024
