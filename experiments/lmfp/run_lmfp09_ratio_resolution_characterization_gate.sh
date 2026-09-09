#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-ratio-resolution-artifacts
mkdir -p lmfp09-ratio-resolution-artifacts
python3 experiments/lmfp/run_lmfp09_ratio_resolution_characterization.py \
  lmfp09-ratio-resolution-artifacts/F-LMFP09_RATIO_RESOLUTION_CHARACTERIZATION.json \
  | tee lmfp09-ratio-resolution-artifacts/F-LMFP09_RATIO_RESOLUTION_CHARACTERIZATION.stdout.json
