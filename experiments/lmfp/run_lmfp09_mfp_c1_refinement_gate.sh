#!/usr/bin/env bash
set -euo pipefail
rm -rf lmfp09-mfp-c1-refinement-artifacts
mkdir -p lmfp09-mfp-c1-refinement-artifacts
python3 experiments/lmfp/run_lmfp09_mfp_c1_refinement.py \
  lmfp09-mfp-c1-refinement-artifacts/F-LMFP09_MFP_C1_REFINEMENT_EVIDENCE.json \
  | tee lmfp09-mfp-c1-refinement-artifacts/F-LMFP09_MFP_C1_REFINEMENT_EVIDENCE.stdout.json
