#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-saturation-aligned-matrix-artifacts
mkdir -p lmfp09-saturation-aligned-matrix-artifacts
python3 experiments/lmfp/run_lmfp09_saturation_aligned_homogeneous_matrix.py \
  lmfp09-saturation-aligned-matrix-artifacts/F-LMFP09_SATURATION_ALIGNED_HOMOGENEOUS_MATRIX.json \
  | tee lmfp09-saturation-aligned-matrix-artifacts/F-LMFP09_SATURATION_ALIGNED_HOMOGENEOUS_MATRIX.stdout.json
