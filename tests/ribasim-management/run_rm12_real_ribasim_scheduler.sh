#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm12-${GITHUB_RUN_ID:-local}-$$"
RIBASIM_ROOT="${RM12_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_DIR="$RIBASIM_ROOT/generated_testmodels/swap5_rm12"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM12_FAIL $*" >&2; exit 1; }

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace   -J "$BUILD" -I "$BUILD" -c src/runtime/mod_fmr_ribasim_management_scheduler.f90 -o "$BUILD/scheduler.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace   -J "$BUILD" -I "$BUILD" -c tests/ribasim-management/emit_rm12_scheduler_targets.f90 -o "$BUILD/emitter.o"
gfortran "$BUILD/scheduler.o" "$BUILD/emitter.o" -o "$BUILD/emitter"
"$BUILD/emitter" > "$BUILD/schedule.txt"
cat "$BUILD/schedule.txt"
grep -Fq 'RM12_SCHEDULER_TARGET_EMISSION=PASS' "$BUILD/schedule.txt" || fail "scheduler emitter marker"

TARGETS="$(awk -F= '/^RM12_UPDATE_TARGET_S=/{gsub(/[[:space:]]/,"",$2); print $2}' "$BUILD/schedule.txt" | paste -sd, -)"
SOLVES="$(awk -F= '/^RM12_SOLVE_BOUNDARY_S=/{gsub(/[[:space:]]/,"",$2); print $2}' "$BUILD/schedule.txt" | paste -sd, -)"
python3 - "$TARGETS" "$SOLVES" <<'PY'
import sys
targets=[float(x) for x in sys.argv[1].split(",") if x]
solves=[float(x) for x in sys.argv[2].split(",") if x]
assert targets == [18000.0,21600.0,36000.0,43200.0,54000.0,64800.0,72000.0,86400.0], targets
assert solves == [0.0,18000.0,36000.0,54000.0,72000.0], solves
PY
echo "RM12_COMPILED_SCHEDULER_SEQUENCE=PASS targets=$TARGETS solves=$SOLVES"

RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "Ribasim exact-release checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "RM12_RIBASIM_PRODUCT_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/ribasim-management/generate_rm12_real_ribasim.py" "$MODEL_DIR"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/ribasim-management/rm12_real_ribasim_scheduler.jl"     "$MODEL_DIR/ribasim.toml" "$TARGETS"
) > "$BUILD/ribasim.txt" 2>&1 || { cat "$BUILD/ribasim.txt" >&2; fail "real Ribasim scheduler trajectory"; }

cat "$BUILD/ribasim.txt"
grep -Fq 'RM12 REAL RIBASIM SCHEDULER TRAJECTORY GATE PASS' "$BUILD/ribasim.txt" || fail "missing final marker"
echo 'RM12_EXACT_RELEASE_SCHEDULER_TRAJECTORY_GATE=PASS'
