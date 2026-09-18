#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e3a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD" "${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e3a}"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E3A_FAIL $*" >&2; exit 1; }

bash tests/publication/build_pub_gc_real_swap_bridge.sh "$BUILD/libpub_gc_e3a_swap.so"
export FGC44_SWAP_LIB="$BUILD/libpub_gc_e3a_swap.so"
export PUB_GC_EVIDENCE_DIR="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e3a}"
python3 tests/publication/run_pub_gc_e3a.py | tee "$PUB_GC_EVIDENCE_DIR/run.txt"

grep -Fq 'PUB_GC_E3A_MATRIX_ATTEMPTED=PASS' "$PUB_GC_EVIDENCE_DIR/run.txt" || fail "matrix marker"
grep -Fq 'PUB_GC_E3A_ZERO_OFFSET_CONTROL=PASS' "$PUB_GC_EVIDENCE_DIR/run.txt" || fail "zero-offset control"
grep -Fq 'PUB_GC_E3A_EVIDENCE_RUN=PASS' "$PUB_GC_EVIDENCE_DIR/run.txt" || fail "evidence marker"

echo 'PUB-GC E3A REAL-SWAP ENVELOPE CHARACTERIZATION GATE PASS'
