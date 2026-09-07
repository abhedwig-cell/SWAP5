#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="c76f794b93522bea3a80a6880bc95ef5671cb914"
BUILD="${TMPDIR:-/tmp}/swap5-fsi05-gate-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
SOILWATER="$ROOT/src/legacy/b1_10_port/soilwater.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRANSACTION="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
DRIVER="$ROOT/tests/fsi/test_fsi05_production_headcalc.F90"
FSI04_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
FSI03_STUBS="$ROOT/tests/fsi/fsi03_legacy_binding_stubs.f90"
FSI03_TEST="$ROOT/tests/fsi/test_fsi03_reference_binding.f90"
FSI02_TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"

# F-SI05 may change only F-SI-owned solver seam/source. F-KT and legacy caller
# semantics remain the exact qualified F-SI04 preimage.
for path in \
  src/legacy/b1_10_port/soilwater.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90; do
  if [[ "$(git rev-parse "$BASE:$path")" != "$(git rev-parse "HEAD:$path")" ]]; then
    echo "F-SI05_PROTECTED_SOURCE FAIL changed $path" >&2
    exit 1
  fi
done

# Pin the materialized production postimage so later drift fails closed.
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "e22251c8f562839857cdb7a609a8148d1f2d58f8" ]] || { echo 'F-SI05_PIN FAIL HeadCalc' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" == "93285b2ca24669494c93c00403e3783fca6758e9" ]] || { echo 'F-SI05_PIN FAIL workspace' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "e02882bd45f67b42ede118de14a6b5b8b16fdb80" ]] || { echo 'F-SI05_PIN FAIL adapter' >&2; exit 1; }

# Production HeadCalc now exposes an optional worker/job-owned workspace, while
# the old one-argument call remains source-compatible.
grep -Eq '^subroutine[[:space:]]+headcalc\(worker,[[:space:]]*fsi_workspace\)' "$HEADCALC" || { echo 'F-SI05_SEAM FAIL signature' >&2; exit 1; }
grep -Fq 'optional :: fsi_workspace' "$HEADCALC" || { echo 'F-SI05_SEAM FAIL workspace not optional' >&2; exit 1; }
grep -Fq 'fsi_ws => local_fsi_workspace' "$HEADCALC" || { echo 'F-SI05_SEAM FAIL compatibility workspace' >&2; exit 1; }
grep -Fq 'call headcalc(ws%legacy_worker, ws%richards)' "$ADAPTER" || { echo 'F-SI05_SEAM FAIL adapter does not pass workspace' >&2; exit 1; }
grep -Fq 'call headcalc(worker)' "$SOILWATER" || { echo 'F-SI05_SEAM FAIL legacy SoilWater compatibility call lost' >&2; exit 1; }

# Heavy main and fallback scratch may no longer be automatic HeadCalc arrays.
if grep -Eiq 'dimension\(macp\).*::.*(dFdhL|dFdhM|dFdhU|difh|sink|source|hold|flnonconv1|flnonconv2|indx|a1|band_rhs)' "$HEADCALC"; then
  echo 'F-SI05_SCRATCH FAIL local solver scratch remains' >&2
  exit 1
fi
if grep -Fqi 'ctx%headcalc%dkdh' "$HEADCALC"; then
  echo 'F-SI05_SCRATCH FAIL legacy worker dkdh remains on production solver path' >&2
  exit 1
fi
for token in band_matrix band_aux band_rhs band_pivots dfdh_lower dfdh_main dfdh_upper residual delta_head; do
  grep -Fqi "fsi_ws%$token" "$HEADCALC" || { echo "F-SI05_SCRATCH FAIL missing fsi_ws%$token" >&2; exit 1; }
done
for token in 'band_matrix(:,:)' 'band_aux(:,:)' 'band_rhs(:)' 'band_pivots(:)'; do
  grep -Fq "$token" "$WORKSPACE" || { echo "F-SI05_WORKSPACE FAIL missing $token" >&2; exit 1; }
done

# Build F-SI05 test stubs from the exact F-SI04 fixture, adding only a switch
# that forces TRIDAG failure so the real alternative band solver route executes.
STUBS="$BUILD/fsi05_stubs.f90"
python3 - "$FSI04_STUBS" "$STUBS" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
marker = 'subroutine tridag(n, upper, main, lower, rhs, solution, ierror)\n  implicit none\n'
insert = '''module fsi05_fixture_control
  implicit none
  logical :: force_tridag_failure = .false.
end module fsi05_fixture_control

subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  use fsi05_fixture_control, only: force_tridag_failure
  implicit none
'''
if src.count(marker) != 1:
    raise SystemExit('F-SI05 stub transform failed: tridag marker')
src = src.replace(marker, insert, 1)
old = '  ierror = 0\nend subroutine tridag\n'
new = '''  if (force_tridag_failure) then
    ierror = 1
  else
    ierror = 0
  end if
end subroutine tridag
'''
if src.count(old) != 1:
    raise SystemExit('F-SI05 stub transform failed: ierror marker')
src = src.replace(old, new, 1)
Path(sys.argv[2]).write_text(src)
PY

PREIMAGE="$BUILD/headcalc_fsi04_preimage.f90"
git show "$BASE:src/legacy/b1_10_port/headcalc.f90" > "$PREIMAGE"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_preimage() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$PREIMAGE" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -DFSI05_PREIMAGE -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

compile_new() {
  local opt="$1" out="$2" compat="$3"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  local cpp=(-cpp)
  [[ "$compat" == yes ]] && cpp+=(-DFSI05_COMPAT_CALL)
  gfortran "${COMMON[@]}" -O"$opt" "${cpp[@]}" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

for opt in 0 2; do
  pre="$BUILD/pre-o$opt"
  explicit="$BUILD/explicit-o$opt"
  compat="$BUILD/compat-o$opt"
  compile_preimage "$opt" "$pre"
  compile_new "$opt" "$explicit" no
  compile_new "$opt" "$compat" yes
  "$pre/replay" > "$pre/output.txt"
  "$explicit/replay" > "$explicit/output.txt"
  "$compat/replay" > "$compat/output.txt"
  cmp "$pre/output.txt" "$explicit/output.txt"
  cmp "$pre/output.txt" "$compat/output.txt"
  grep -Fq 'F-SI05_PRODUCTION_HEADCALC PASS' "$explicit/output.txt"
  grep -Fq 'BAND-A1' "$explicit/output.txt"
  echo "F-SI05_REAL_REPLAY_O$opt PASS"
done
cmp "$BUILD/pre-o0/output.txt" "$BUILD/pre-o2/output.txt"
cmp "$BUILD/explicit-o0/output.txt" "$BUILD/explicit-o2/output.txt"
cmp "$BUILD/compat-o0/output.txt" "$BUILD/compat-o2/output.txt"
echo 'F-SI05_O0_O2_IDENTITY PASS'

# Re-run the F-SI03 adapter behavior with a signature-adjusted test double. This
# changes no behavior of the test double; it only accepts the now-explicit workspace.
FSI03_PATCHED="$BUILD/fsi03_stubs_workspace.f90"
python3 - "$FSI03_STUBS" "$FSI03_PATCHED" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
s = s.replace('subroutine headcalc(worker)\n', 'subroutine headcalc(worker, fsi_workspace)\n', 1)
s = s.replace('  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n',
              '  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n  use mod_reference_richards_workspace, only: reference_richards_workspace_t\n', 1)
s = s.replace('  type(a23bu_worker_context_t), intent(inout), optional :: worker\n',
              '  type(a23bu_worker_context_t), intent(inout), optional :: worker\n  type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n', 1)
Path(sys.argv[2]).write_text(s)
PY
for opt in 0 2; do
  out="$BUILD/adapter-o$opt"
  mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" \
    "$WORKER" "$CONTRACT" "$WORKSPACE" "$FSI03_PATCHED" "$ADAPTER" "$FSI03_TEST" -o "$out/fsi03_test"
  "$out/fsi03_test" >/dev/null
done
echo 'F-SI05_ADAPTER_REGRESSION PASS'

# Common workspace remains isolated under 1/2/4/8 worker execution at O0/O2.
for opt in 0 2; do
  out="$BUILD/fsi02-o$opt"
  mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -O"$opt" -J "$out" \
    "$CONTRACT" "$WORKSPACE" "$FSI02_TEST" -o "$out/fsi02_test"
  for threads in 1 2 4 8; do
    OMP_NUM_THREADS="$threads" "$out/fsi02_test" >/dev/null
  done
done
echo 'F-SI05_WORKSPACE_1_2_4_8 PASS'

echo 'F-SI05_GATE PASS'
