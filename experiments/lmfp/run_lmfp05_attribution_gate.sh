#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-lmfp05-attribution-$$"
OUTDIR="$ROOT/lmfp05-artifacts"
mkdir -p "$BUILD" "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PATCHER="$ROOT/experiments/lmfp/lmfp05_patch_refined_stubs.py"
BASE_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
STUBS="$BUILD/lmfp05_refined_linear_stubs.f90"
DRIVER="$ROOT/experiments/lmfp/test_lmfp05_refined_fullrichards_reference.f90"
ANALYZER="$ROOT/experiments/lmfp/run_lmfp05_attribution.py"

python3 "$PATCHER" "$BASE_STUBS" "$STUBS"
python3 -m py_compile "$ANALYZER" "$ROOT/experiments/lmfp/run_lmfp04_ab.py" \
  "$ROOT/experiments/lmfp/run_lmfp03_column.py" "$ROOT/experiments/lmfp/run_lmfp02_testbench.py"

grep -Fq 'integer, parameter :: macp = 64' "$STUBS"
grep -Fq 'integer, parameter :: numnod = 64' "$STUBS"
grep -Fq 'subroutine tridag(n, a, b, c, r, u, ierror)' "$STUBS"
if grep -Fq 'solution(i) = 0.0d0' "$STUBS"; then
  echo 'F-LMFP05 fixture still contains zero-correction tridag stub' >&2
  exit 1
fi

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

"$BUILD/fullrichards" | tee "$OUTDIR/F-LMFP05_REFINED_FULLRICHARDS.txt"
grep -Fq 'F-LMFP05_REFINED_FULLRICHARDS_PASS' "$OUTDIR/F-LMFP05_REFINED_FULLRICHARDS.txt"
if grep -Fq 'BANDED_FALLBACK_USED' "$OUTDIR/F-LMFP05_REFINED_FULLRICHARDS.txt"; then
  echo 'F-LMFP05 FullRichards reference used forbidden banded fallback' >&2
  exit 1
fi

python3 "$ANALYZER" "$OUTDIR/F-LMFP05_REFINED_FULLRICHARDS.txt" "$OUTDIR/F-LMFP05_ATTRIBUTION_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP05_ATTRIBUTION_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP05_ATTRIBUTION_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
e = json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['tests']['all_reference_runs_present']['pass'] is True
assert e['tests']['reference_mass_closure']['pass'] is True
assert e['tests']['candidate_mass_closure']['pass'] is True
assert e['tests']['face_sweep_solved']['pass'] is True
print('F-LMFP05_ATTRIBUTION_STRUCTURAL_GATE PASS')
PY
