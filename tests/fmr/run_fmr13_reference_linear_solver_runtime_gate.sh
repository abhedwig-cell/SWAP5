#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr13-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fmr13_fmr09_gate.sh" "$ROOT/tests/fmr/.fmr13_fmr12_gate.sh"' EXIT
cd "$ROOT"

FMR12_BASE=e639ca5ae703d6bdb97829a0bd7d2762db1d8a9a
FSI19_CLOSEOUT=d3a1bc8eef243b6109af8871398c06e1840fb367
FSI19_MODULE_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
FSI19_ORACLE_BLOB=bf8c9d85c98157d128086d2c2fb20f6129b98e63
FMR12_ADAPTER_BLOB=9105126c219cbd06fadfa7757ba95d7b7bd0499b

expected_src=$'src/legacy/b1_10_port/headcalc.f90\nsrc/solver/mod_reference_linear_solver.f90\nsrc/solver/mod_reference_richards_workspace.f90'
actual_src="$(git diff --name-only "$FMR12_BASE" -- src | sort)"
[[ "$actual_src" == "$expected_src" ]] || {
  echo 'FMR13_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf 'expected:\n%s\nactual:\n%s\n' "$expected_src" "$actual_src" >&2
  exit 1
}
echo 'FMR13_PRODUCTION_DELTA_EXACTLY_THREE_SOLVER_SEAM_PATHS=PASS'

[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == "$FSI19_MODULE_BLOB" ]] || {
  echo 'FMR13_FSI19_MODULE_BLOB_LOCK=FAIL' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90)" == "$FMR12_ADAPTER_BLOB" ]] || {
  echo 'FMR13_FMR12_ADAPTER_PRESERVATION=FAIL' >&2; exit 1; }
python3 tools/fmr13_materialize.py verify

python3 - <<'PY'
from pathlib import Path
h = Path('src/legacy/b1_10_port/headcalc.f90').read_text().lower()
w = Path('src/solver/mod_reference_richards_workspace.f90').read_text().lower()
for required in [
    'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve',
    'call reference_tridag(',
    'call reference_band_solve(',
]:
    assert required in h, required
for forbidden in ['call tridag(', 'call bandec(', 'call banbks(', 'only: macp, mabbc']:
    assert forbidden not in h, forbidden
for required in [
    'real(real64), allocatable :: tridag_gamma(:)',
    'workspace%tridag_gamma(active_nodes)',
    'workspace%tridag_gamma = 0.0_real64',
    'workspace%tridag_gamma = qnan',
    'deallocate(workspace%tridag_gamma)',
    'size(workspace%tridag_gamma, kind=int64)',
]:
    assert required in w, required
print('FMR13_ARCHITECTURAL_LINEAR_SOLVER_SEAM=PASS')
PY

# Re-run the immutable F-SI19 direct solver oracle against the composed F-MR module.
[[ "$(git rev-parse "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90")" == "$FSI19_ORACLE_BLOB" ]] || {
  echo 'FMR13_FSI19_ORACLE_SOURCE_LOCK=FAIL' >&2; exit 1; }
git show "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90" > "$BUILD/test_fsi19_reference_linear_solver.f90"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/fsi19-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 "$BUILD/test_fsi19_reference_linear_solver.f90" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt"
  "$OUT/test" > "$OUT/run-b.txt"
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N1=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N7=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1000=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1002=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/run-a.txt"
  echo "FMR13_FSI19_DIRECT_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/fsi19-o0/run-a.txt" "$BUILD/fsi19-o2/run-a.txt"
echo 'FMR13_FSI19_DIRECT_ORACLE_O0_O2_IDENTITY=PASS'

# Reuse the full F-MR09 mass/rollback/replay gate unchanged except for the
# owner-qualified HeadCalc blob and the newly required linear-solver module in compile order.
export FMR13_HEADCALC_BLOB="$(git hash-object src/legacy/b1_10_port/headcalc.f90)"
python3 - <<'PY'
from pathlib import Path
import os
src = Path('tests/fmr/run_fmr09_root_sink_runtime_gate.sh').read_text()
old = 'check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353'
new = 'check_blob src/legacy/b1_10_port/headcalc.f90 ' + os.environ['FMR13_HEADCALC_BLOB']
assert src.count(old) == 1
src = src.replace(old, new, 1)
marker = '  src/solver/mod_reference_richards_workspace.f90\n'
assert src.count(marker) == 1
src = src.replace(marker, '  src/solver/mod_reference_linear_solver.f90\n' + marker, 1)
Path('tests/fmr/.fmr13_fmr09_gate.sh').write_text(src)
PY
bash tests/fmr/.fmr13_fmr09_gate.sh | tee "$BUILD/fmr09.txt"
grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_FULL_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_ROOT_SINK_RUNTIME_GATE PASS' "$BUILD/fmr09.txt"
echo 'FMR13_AUTHORITATIVE_MASS_TRANSACTION_REPLAY_REGRESSION=PASS'

# Reuse the full F-MR12 adapter/F-MR10 regression. Only its historical source-delta
# expectation and compile order are adapted to the new F-MR13 composition.
python3 - <<'PY'
from pathlib import Path
src = Path('tests/fmr/run_fmr12_crop_root_uptake_input_adapter_gate.sh').read_text()
assert src.count('BASE=b6a667035d5e900a7e2209e76491c1817ffd2043') == 1
assert src.count('NEW_SRC=src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90') == 1
src = src.replace('BASE=b6a667035d5e900a7e2209e76491c1817ffd2043',
                  'BASE=e639ca5ae703d6bdb97829a0bd7d2762db1d8a9a', 1)
src = src.replace('NEW_SRC=src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90',
                  "NEW_SRC=$'src/legacy/b1_10_port/headcalc.f90\\nsrc/solver/mod_reference_linear_solver.f90\\nsrc/solver/mod_reference_richards_workspace.f90'", 1)
marker = '  src/solver/mod_reference_richards_workspace.f90\n'
assert src.count(marker) == 1
src = src.replace(marker, '  src/solver/mod_reference_linear_solver.f90\n' + marker, 1)
Path('tests/fmr/.fmr13_fmr12_gate.sh').write_text(src)
PY
bash tests/fmr/.fmr13_fmr12_gate.sh | tee "$BUILD/fmr12.txt"
grep -Fq 'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_A_B_A_DETERMINISM=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_GATE PASS' "$BUILD/fmr12.txt"
echo 'FMR13_FMR12_FMR10_RUNTIME_REGRESSION=PASS'

# No rejected/trial state may be published by this composition; the inherited
# F-MR09/F-MR12 gates above exercise rollback/replay and authoritative mass.
git diff --exit-code -- tests/fmr/run_fmr09_root_sink_runtime_gate.sh tests/fmr/run_fmr12_crop_root_uptake_input_adapter_gate.sh

echo "FMR13_FMR09_OUTPUT_SHA256=$(sha256sum "$BUILD/fmr09.txt" | cut -d' ' -f1)"
echo "FMR13_FMR12_OUTPUT_SHA256=$(sha256sum "$BUILD/fmr12.txt" | cut -d' ' -f1)"
echo 'FMR13_REFERENCE_LINEAR_SOLVER_RUNTIME_GATE PASS'
