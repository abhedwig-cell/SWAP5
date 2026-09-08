#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-mfp-c1-artifacts
mkdir -p lmfp09-mfp-c1-artifacts
python3 experiments/lmfp/run_lmfp09_mfp_c1_candidates.py \
  lmfp09-mfp-c1-artifacts/F-LMFP09_MFP_C1_EVIDENCE.json \
  | tee lmfp09-mfp-c1-artifacts/F-LMFP09_MFP_C1_EVIDENCE.stdout.json
