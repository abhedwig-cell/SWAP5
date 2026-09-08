#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-homogeneous-c1-coarse-artifacts
mkdir -p lmfp09-homogeneous-c1-coarse-artifacts
python3 experiments/lmfp/run_lmfp09_homogeneous_c1_coarse.py \
  lmfp09-homogeneous-c1-coarse-artifacts/F-LMFP09_HOMOGENEOUS_C1_COARSE_EVIDENCE.json \
  | tee lmfp09-homogeneous-c1-coarse-artifacts/F-LMFP09_HOMOGENEOUS_C1_COARSE_EVIDENCE.stdout.json
