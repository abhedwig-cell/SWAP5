#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-state-materialization-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2   tests/fpe/test_fpe_zero_waste01_state_materialization.f90 -o "$BUILD/test"

"$BUILD/test" 60 100000
"$BUILD/test" 200 50000
"$BUILD/test" 1000 10000

python3 - <<'PY'
from pathlib import Path
src=Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text(encoding="utf-8").lower()
assert "allocate(request%base_state%pressure_head" in src
assert "request%base_state%pressure_head = physical%pressure_head" in src
assert "request%base_state%water_content = physical%water_content" in src
tx=Path("src/transaction/mod_transaction_reference.f90").read_text(encoding="utf-8").lower()
assert tx.count("call model%advance(") >= 3
print("FPE_ZERO_WASTE01_STATE_MATERIALIZATION_BINDING_STATIC=PASS")
PY

echo 'FPE_ZERO_WASTE01_STATE_MATERIALIZATION=PASS'
