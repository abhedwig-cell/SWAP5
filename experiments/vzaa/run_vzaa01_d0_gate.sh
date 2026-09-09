#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-vzaa01-d0-$$"
OUTDIR="$ROOT/vzaa01-d0-artifacts"
mkdir -p "$BUILD" "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

LINEAR_PATCHER="$ROOT/experiments/lmfp/lmfp04_patch_linear_stubs.py"
TRAJECTORY_PATCHER="$ROOT/experiments/vzaa/vzaa01_d0_patch_fullrichards_trajectory.py"
BASE_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
STUBS="$BUILD/vzaa01_d0_real_linear_stubs.f90"
BASE_DRIVER="$ROOT/experiments/lmfp/test_lmfp04_fullrichards_reference.f90"
DRIVER="$BUILD/test_vzaa01_d0_fullrichards_trajectory.f90"
RUNNER="$ROOT/experiments/vzaa/run_vzaa01_d0_gate_driver.py"
SUMMARY="$OUTDIR/F-VZAA01_D0_DONOR_SEPARABILITY_SUMMARY.json"
ROWS="$OUTDIR/F-VZAA01_D0_DONOR_SEPARABILITY_ROWS.jsonl"
TRAJECTORY="$OUTDIR/F-VZAA01_D0_FULLRICHARDS_TRAJECTORY.txt"

python3 "$LINEAR_PATCHER" "$BASE_STUBS" "$STUBS"
python3 "$TRAJECTORY_PATCHER" "$BASE_DRIVER" "$DRIVER"
python3 -m py_compile \
  "$TRAJECTORY_PATCHER" \
  "$ROOT/experiments/vzaa/run_vzaa01_d0_donor_separability.py" \
  "$RUNNER" \
  "$ROOT/experiments/lmfp/run_lmfp02_testbench.py" \
  "$ROOT/experiments/lmfp/run_lmfp03_column.py" \
  "$ROOT/experiments/lmfp/run_lmfp04_ab.py" \
  "$ROOT/experiments/lmfp/run_lmfp06_darcian_reference.py" \
  "$ROOT/experiments/lmfp/run_lmfp07_transient_abc.py" \
  "$ROOT/experiments/lmfp/run_lmfp08_physics_informed_correction.py" \
  "$ROOT/experiments/lmfp/run_lmfp08_logk_candidate.py" \
  "$ROOT/experiments/lmfp/run_lmfp08_constrained_mfp_ratio.py"

grep -Fq 'subroutine tridag(n, a, b, c, r, u, ierror)' "$STUBS"
if grep -Fq 'solution(i) = 0.0d0' "$STUBS"; then
  echo 'F-VZAA01 D0 fixture still contains zero-correction tridag stub' >&2
  exit 1
fi
grep -Fq "do case_id = 1, 4" "$DRIVER"
grep -Fq "'D0STEP'" "$DRIVER"
grep -Fq "'D0NODE'" "$DRIVER"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O2)
MOD="$BUILD/mod"
mkdir -p "$MOD"

compile() {
  local src="$1" obj="$2"
  gfortran "${COMMON[@]}" -J "$MOD" -I "$MOD" -c "$src" -o "$BUILD/$obj"
}

compile "$STUBS" stubs.o
compile "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" worker.o
compile "$ROOT/src/solver/mod_soil_water_solver_contract.f90" contract.o
compile "$ROOT/src/solver/mod_reference_richards_workspace.f90" workspace.o
compile "$ROOT/src/solver/mod_reference_richards_state_binding.f90" state.o
compile "$ROOT/tests/fsi/mod_fsi07_top_provider.f90" top.o
compile "$ROOT/tests/fsi/mod_fsi08_provider_fixture.f90" sources.o
compile "$ROOT/src/solver/mod_b110_default_mvg_provider.f90" hydraulics.o
compile "$ROOT/src/legacy/b1_10_port/headcalc.f90" headcalc.o
compile "$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90" adapter.o
compile "$DRIVER" driver.o

gfortran -O2 "$BUILD/driver.o" "$BUILD/adapter.o" "$BUILD/headcalc.o" "$BUILD/hydraulics.o" \
  "$BUILD/sources.o" "$BUILD/top.o" "$BUILD/state.o" "$BUILD/workspace.o" "$BUILD/contract.o" \
  "$BUILD/worker.o" "$BUILD/stubs.o" -o "$BUILD/fullrichards"

"$BUILD/fullrichards" | tee "$TRAJECTORY"
grep -Fq 'F-LMFP04_FULLRICHARDS_REFERENCE_PASS' "$TRAJECTORY"

grep -Fq 'D0STEP 1 1 1' "$TRAJECTORY"
grep -Fq 'D0NODE 1 1 1 1' "$TRAJECTORY"

python3 "$RUNNER" "$TRAJECTORY" "$SUMMARY" "$ROWS" | tee "$OUTDIR/F-VZAA01_D0_DONOR_SEPARABILITY.stdout.json"

python3 - "$SUMMARY" "$ROWS" <<'PY'
import json
import pathlib
import sys
summary = json.loads(pathlib.Path(sys.argv[1]).read_text())
rows = pathlib.Path(sys.argv[2]).read_text().splitlines()
assert summary['execution_complete'] is True
assert summary['structural_mass_gate']['pass'] is True
assert summary['scientific_pass_threshold'] is None
assert summary['scientific_decision'] == 'UNSET_CHARACTERIZATION_REQUIRES_EVIDENCE_REVIEW'
assert summary['production_admission'] == 'NONE'
assert summary['reference_families']['ordinary']['rows_total'] > 0
assert summary['reference_families']['stress']['rows_total'] > 0
assert rows
print('F-VZAA01_D0_EXECUTION_GATE PASS')
PY
