#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reuse the exact admitted F-GC44 qualification build and end-to-end gate.
# Sourcing deliberately keeps its temporary BUILD and shared library alive
# until this outer research runner exits.
source tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh

test -f "$BUILD/bridge/libfgc44_swap.so" || {
  echo "GC_DSW22_FAIL missing reused F-GC44 bridge library" >&2
  exit 1
}

FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_real_fgc44_response_storage_scan.py | tee "$BUILD/dsw22-semantic-scan.txt"

grep -Fq 'GC_DSW22_LIVE_GATE=PASS' "$BUILD/dsw22-semantic-scan.txt" || {
  echo "GC_DSW22_FAIL missing live gate" >&2
  exit 1
}

echo 'GC_DSW22_REAL_SWAP_SEMANTIC_SCAN=PASS'
