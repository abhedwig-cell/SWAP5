#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-near-saturation-artifacts
mkdir -p lmfp09-near-saturation-artifacts
python3 experiments/lmfp/run_lmfp09_near_saturation_oracle_diagnostic.py \
  lmfp09-near-saturation-artifacts/F-LMFP09_NEAR_SATURATION_ORACLE_EVIDENCE.json \
  | tee lmfp09-near-saturation-artifacts/F-LMFP09_NEAR_SATURATION_ORACLE_EVIDENCE.stdout.json
