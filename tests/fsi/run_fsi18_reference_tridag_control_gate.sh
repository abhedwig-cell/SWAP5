#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE='a6470b90f100b7ed9837c5e092b39d011fd28476'
BUILD="${TMPDIR:-/tmp}/swap5-fsi18-real-tridag-$$"
EVIDENCE_DIR="${FSI18_TRIDAG_EVIDENCE_DIR:-$ROOT/fsi18-reference-tridag-evidence}"
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FSI18_TRIDAG_CONTROL_PRODUCTION_SOURCE_CHANGED=FAIL' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi
echo 'FSI18_TRIDAG_CONTROL_EXACT_FSI16_PRODUCTION_SOURCE=PASS'

[[ "$(git hash-object tests/fsi/fsi04_real_headcalc_stubs.f90)" == '23c00e4a188e88bc36ef95cbe4faaacdd6aad639' ]] || {
  echo 'FSI18_TRIDAG_CONTROL_STUB_SOURCE_LOCK=FAIL' >&2; exit 1; }
python3 tests/fsi/fsi18_make_reference_tridag_stubs.py \
  tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference-stubs.f90" \
  | tee "$EVIDENCE_DIR/generation.txt"
grep -Fq 'FSI18_ZERO_CORRECTION_TRIDAG_REPLACED=PASS' "$EVIDENCE_DIR/generation.txt"
sha256sum "$BUILD/reference-stubs.f90" > "$EVIDENCE_DIR/reference-stubs.sha256"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
REST=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  tests/fsi/mod_fsi07_top_provider.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  obj="$OUT/reference-stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/reference-stubs.f90" -o "$obj"
  objects+=("$obj")
  for src in "${REST[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fsi/test_fsi18_reference_convergence_cliff.F90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/test" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$OUT/run-a.txt"
  cp "$OUT/run-a.txt" "$EVIDENCE_DIR/reference-tridag-o${opt}.txt"
  sha256sum "$OUT/run-a.txt" > "$EVIDENCE_DIR/reference-tridag-o${opt}.sha256"
  echo "FSI18_REFERENCE_TRIDAG_O${opt}=PASS"
done

cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FSI18_REFERENCE_TRIDAG_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run-a.txt" <<'PY' | tee "$EVIDENCE_DIR/classification.txt"
from pathlib import Path
import sys
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()

def b(i, field): return vals[f'FSI18_CASE_{i}_{field}']=='T'
def n(i, field): return int(vals[f'FSI18_CASE_{i}_{field}'])
def r(i, field): return float(vals[f'FSI18_CASE_{i}_{field}'])

assert b(1,'CONVERGED')
all_nonzero_converged=all(b(i,'CONVERGED') for i in range(2,6))
higher=[i for i in range(2,6) if b(i,'CONVERGED') and n(i,'NONLINEAR_ITERATIONS')>1]
print('FSI18_REFERENCE_TRIDAG_ALL_NONZERO_CONVERGED=' + ('YES' if all_nonzero_converged else 'NO'))
print('FSI18_REFERENCE_TRIDAG_HIGHER_COST_ACCEPTED_CASES=' + ','.join(map(str,higher)))
for i in range(1,6):
    print(f"FSI18_REFERENCE_TRIDAG_CASE_{i}=converged:{b(i,'CONVERGED')},nl:{n(i,'NONLINEAR_ITERATIONS')},retry:{n(i,'INTERNAL_RETRIES')},bt:{n(i,'BACKTRACKING_ATTEMPTS')},balflags:{n(i,'FINAL_BALANCE_FLAG_COUNT')},headflags:{n(i,'FINAL_HEAD_FLAG_COUNT')},res:{r(i,'FINAL_MAX_ABS_RESIDUAL'):.17e}")
if all_nonzero_converged:
    classification='ZERO_CORRECTION_TRIDAG_STUB_CONFIRMED_AS_BINARY_CLIFF_CAUSE'
else:
    classification='CLIFF_OR_NONCONVERGENCE_PERSISTS_WITH_REFERENCE_TRIDAG_REQUIRES_FURTHER_SOLVER_DIAGNOSIS'
print('FSI18_REFERENCE_TRIDAG_CLASSIFICATION='+classification)
print('FSI18_PRODUCTION_CHANGE_AUTHORIZED=NO')
PY

cat "$EVIDENCE_DIR/classification.txt"
echo 'FSI18_REFERENCE_TRIDAG_CONTROL_GATE=PASS_DIAGNOSTIC_ONLY'
