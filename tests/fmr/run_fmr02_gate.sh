#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 tools/fmr/fmr02_shared_postimage_gate.py

# Preserve the complete deterministic MultiSWAP runtime qualification. This
# transitively preserves F-KT05 and its earlier transaction/kernel gates.
bash tests/fmr/run_fmr01_gate.sh

# Re-run the exact F-SI05 focused production workspace seam qualification on
# the shared postimage. This remains a focused seam qualification only and
# must not be interpreted as parallel HeadCalc/reference-backend admission.
bash tests/fsi/run_fsi05_gate.sh

echo 'F-MR02_SHARED_FKT05_FSI05_FOCUSED_POSTIMAGE_GATE PASS'
