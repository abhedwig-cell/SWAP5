#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 tests/research/test_gc_real_swap_map07_qu_derivative.py | tee /tmp/gc-map07.txt

for marker in \
  'GC_MAP07_PRODUCTION_FORMULA_AUTHORITY=PASS' \
  'GC_MAP07_HISTORICAL_QU_RECONSTRUCTION=PASS' \
  'GC_MAP07_PREDICTOR_FAMILY_CANCELLATION_IDENTITY=PASS' \
  'GC_MAP07_E4_PLATEAU_AUTHORITY_PRESERVED=PASS' \
  'GC_MAP07_DIAGNOSTIC_GATE=PASS'; do
  grep -Fq "$marker" /tmp/gc-map07.txt || { echo "GC_MAP07_FAIL missing $marker" >&2; exit 1; }
done

git diff --check -- \
  integration/research/GC_REAL_SWAP_MAP07_DIAGNOSTIC_DESIGN.json \
  tests/research/test_gc_real_swap_map07_qu_derivative.py \
  tests/research/run_gc_real_swap_map07.sh

echo 'GC REAL SWAP MAP07 DIAGNOSTIC PASS'
