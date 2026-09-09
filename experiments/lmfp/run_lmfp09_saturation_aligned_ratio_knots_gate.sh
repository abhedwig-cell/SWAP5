#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-saturation-aligned-artifacts
mkdir -p lmfp09-saturation-aligned-artifacts
python3 experiments/lmfp/run_lmfp09_saturation_aligned_ratio_knots.py \
  lmfp09-saturation-aligned-artifacts/F-LMFP09_SATURATION_ALIGNED_RATIO_KNOTS.json \
  | tee lmfp09-saturation-aligned-artifacts/F-LMFP09_SATURATION_ALIGNED_RATIO_KNOTS.stdout.json
