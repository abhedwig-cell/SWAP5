#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi24-gate-b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=81185df08c5231d3990c9a941591d444e880a077
THEORY_COMMIT=b262a5e9be35f278703fe602b577cbf595f8d9bf
PLAN_COMMIT=cbe977ef9ce06d37e8ce9bf5a586ecb0d990e2d6
DRIVER_COMMIT=1353b7a3c8b476536b05f572a3c7b0bc5ff2f877
THEORY=integration/f-si/F-SI24_GATE_A_LINEAR_DEFECT_BOUND_DERIVATION.json
PLAN=integration/f-si/F-SI24_GATE_B_EXACT_MANUFACTURED_PLAN.json
DRIVER=tests/fsi/test_fsi24_gate_b_exact_manufactured_bound.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90

fail() { echo "FSI24_GATE_B_RUNNER_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$THEORY_COMMIT" HEAD || fail 'Gate-A derivation commit not in branch history'
git merge-base --is-ancestor "$PLAN_COMMIT" HEAD || fail 'Gate-B frozen plan commit not in branch history'
git merge-base --is-ancestor "$DRIVER_COMMIT" HEAD || fail 'Gate-B driver commit not in branch history'
git diff --quiet "$THEORY_COMMIT" -- "$THEORY" || fail 'Gate-A derivation drift after freeze'
git diff --quiet "$PLAN_COMMIT" -- "$PLAN" || fail 'Gate-B plan drift after freeze'
git diff --quiet "$DRIVER_COMMIT" -- "$DRIVER" || fail 'Gate-B driver drift after freeze'

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  || fail 'production Richards/runtime source drift from F-SI24 base'
echo 'FSI24_GATE_B_SOURCE_PLAN_DRIVER_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI24_GATE_B_REFERENCE_TRIDAG=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_source_sink_provider.f90
  tests/fsi/mod_fsi23_mms_providers.f90
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
    fail "Gate-B execution failed opt=$tag"
  }
  grep -Fq 'FSI24_GATE_B_EXACT_MANUFACTURED_BOUND PASS' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "Gate-B PASS marker missing opt=$tag"
  }
  [[ "$(grep -c '^FSI24_GB_PRECHECK:' "$out/output.txt")" -eq 1 ]] || fail "unexpected precheck count opt=$tag"
  [[ "$(grep -c '^FSI24_GB_POINT:AXIS=SINGLE' "$out/output.txt")" -eq 5 ]] || fail "unexpected single-mode point count opt=$tag"
  [[ "$(grep -c '^FSI24_GB_POINT:AXIS=MULTI' "$out/output.txt")" -eq 5 ]] || fail "unexpected multimode point count opt=$tag"
  [[ "$(grep -c '^FSI24_GB_MASS:' "$out/output.txt")" -eq 10 ]] || fail "unexpected mass row count opt=$tag"
  echo "FSI24_GATE_B_RUN=PASS:OPT=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output drift'
}
echo 'FSI24_GATE_B_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  || fail 'production source changed during Gate B'
echo 'FSI24_GATE_B_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI24_GATE_B PASS'
