#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi23-c3-attribution-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=394d064a0dad0a7f7852b129bae99713b9aeb4c0
PLAN=integration/f-si/F-SI23_GATE_C3_TRANSACTION_LOCAL_REFINEMENT_PLAN.json
PLAN_BLOB=599ee73cd8a8f71e51d42e83ac420066cbc66bb3
DRIVER=tests/fsi/test_fsi23_gate_c3_transaction_local_refinement.f90
DRIVER_BLOB=261cec4550e8333734b54710bb9a34e2ff708742
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI23_C3_ATTRIBUTION_FAIL $*" >&2; exit 1; }

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production source drift'
[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'C3 plan drift'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'C3 qualification driver drift'
echo 'FSI23_C3_ATTRIBUTION_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'TRIDAG generator drift'
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"

git show "HEAD:$DRIVER" > "$BUILD/diagnostic_case.f90"
python3 - "$BUILD/diagnostic_case.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
repls={
 'real(real64), parameter :: initial_head_cm = -75.0_real64':
   'real(real64), parameter :: initial_head_cm = -2.50000000000000000e+01_real64',
 'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':
   'real(real64), parameter :: predictor_bottom_head_cm = -2.50100000000000016e+01_real64'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('diagnostic case token drift: '+old)
    s=s.replace(old,new,1)
old="""      call s%solve(request, ws, result)\n      call require(result%status == SW_SOLVE_CONVERGED, 'C3 direct Richards solve converged')"""
new="""      call s%solve(request, ws, result)\n      if (result%status /= SW_SOLVE_CONVERGED) then\n        write(*,'(A,ES26.17E3,A,I0,A,ES26.17E3,A,I0,A,I0,A,I0,A,I0)') &\n             'FSI23_C3_SOLVE_FAILURE_CONTEXT:TOTAL_DT=',total_dt,':NS=',ns,':SUB_DT=',subdt, &\n             ':ISTEP=',istep,':STATUS=',result%status,':NITER=',result%diagnostics%nonlinear_iterations, &\n             ':BACKTRACK=',result%diagnostics%backtracking_attempts\n      end if\n      call require(result%status == SW_SOLVE_CONVERGED, 'C3 direct Richards solve converged')"""
if s.count(old)!=1: raise SystemExit('solve require token drift')
s=s.replace(old,new,1)
p.write_text(s)
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O0)
SRC=(
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
  "$BUILD/diagnostic_case.f90"
)
mkdir -p "$BUILD/o0"
objects=()
for src in "${SRC[@]}"; do
  obj="$BUILD/o0/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/o0" -I "$BUILD/o0" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran -O0 "${objects[@]}" -o "$BUILD/o0/c3_attribution"

set +e
"$BUILD/o0/c3_attribution" > "$BUILD/out.txt" 2>&1
rc=$?
set -e
cat "$BUILD/out.txt"
[[ "$rc" -ne 0 ]] || fail 'expected frozen case-2 failure did not reproduce'
grep -Fq 'FSI23_C3_SOLVE_FAILURE_CONTEXT:' "$BUILD/out.txt" || fail 'failure context missing'
grep -Fq 'FSI23_C3_FAIL C3 direct Richards solve converged' "$BUILD/out.txt" || fail 'original convergence failure missing'
[[ "$(grep -c '^FSI23_C3_SOLVE_FAILURE_CONTEXT:' "$BUILD/out.txt")" -eq 1 ]] || fail 'unexpected number of failure contexts'
echo 'FSI23_C3_ATTRIBUTION_REPRODUCED_EXPECTED_FAILURE=PASS'
echo 'FSI23_C3_ATTRIBUTION_DIAGNOSTIC_ONLY=PASS'
