#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tests/research/test_gc_low01c_branch_boundaries.py | tee "$BUILD/low01c.txt"

for marker in   'GC_LOW01C_SOURCE_AUTHORITY=PASS'   'GC_LOW01C_NODE_SNAP_ASYMMETRY=PASS'   'GC_LOW01C_BOTTOM_NODE_SWITCH=PASS'   'GC_LOW01C_PHYSICAL_BOTTOM_FACE_DISTINCTION=PASS'   'GC_LOW01C_REVERSE_REPLAY=PASS'   'GC_LOW01C_CLASSIFIER_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/low01c.txt"
done

git diff --check --   integration/research/GC_LOW01C_PREREGISTRATION.json   tests/research/test_gc_low01c_branch_boundaries.py   tests/research/run_gc_low01c.sh

echo 'GC_LOW01C_CHARACTERIZATION=PASS'
