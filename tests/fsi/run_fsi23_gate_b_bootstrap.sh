#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi23-bootstrap-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=394d064a0dad0a7f7852b129bae99713b9aeb4c0
PLAN=integration/f-si/F-SI23_GATE_B_BOOTSTRAP_PLAN.json
PLAN_BLOB=a7a1b8c426149ad6e390ca245d261fd0a358fc05
DRIVER=tests/fsi/test_fsi23_right_derivative_bootstrap.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90

fail() { echo "FSI23_GATE_B_FAIL $*" >&2; exit 1; }

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  || fail 'production Richards/runtime source drift from F-VQ29 closeout'
[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'Gate B plan drift after freeze'
echo 'FSI23_GATE_B_SOURCE_AND_PLAN_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI23_GATE_B_REFERENCE_TRIDAG=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

build_and_run() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 300s "$out/test" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "bootstrap execution failed opt=$tag"
  }
  grep -Fq 'FSI23_RIGHT_DERIVATIVE_BOOTSTRAP PASS' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "bootstrap PASS marker missing opt=$tag"
  }
  [[ "$(grep -c '^FSI23_BOOTSTRAP_CASE:' "$out/output.txt")" -eq 12 ]] || fail "unexpected case count opt=$tag"
  [[ "$(grep -c '^FSI23_BOOTSTRAP_POINT:' "$out/output.txt")" -eq 60 ]] || fail "unexpected point count opt=$tag"
  echo "FSI23_GATE_B_RUN=PASS:OPT=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output drift'
}
echo 'FSI23_GATE_B_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  || fail 'production source changed during Gate B'
echo 'FSI23_GATE_B_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI23_GATE_B PASS'
