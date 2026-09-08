#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-adaptive-ratio-artifacts
mkdir -p lmfp09-adaptive-ratio-artifacts
python3 experiments/lmfp/run_lmfp09_adaptive_ratio_refinement.py \
  lmfp09-adaptive-ratio-artifacts/F-LMFP09_ADAPTIVE_RATIO_EVIDENCE.json \
  | tee lmfp09-adaptive-ratio-artifacts/F-LMFP09_ADAPTIVE_RATIO_EVIDENCE.stdout.json
