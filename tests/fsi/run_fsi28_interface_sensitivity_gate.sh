#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
FSI27_FIXTURE_HEAD="f7b891ce636b63bdae7e43f0ed54195f067f8bcc"
FSI27_MATERIALIZATION="5dfd4528245e63a087426197b0d8cb28598deae8"
FSI27_ADAPTER_BLOB="2cb1126397147b9e447634b131c93932c097177d"
HEADCALC_BLOB="55893f1f5ccba2052ad681743aa155b69f351246"
BUILD="${TMPDIR:-/tmp}/swap5-fsi28-interface-sensitivity-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI28_RUNNER_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail 'canonical base missing'
git cat-file -e "$FSI27_FIXTURE_HEAD^{commit}" || fail 'F-SI27 fixture head missing'
git cat-file -e "$FSI27_MATERIALIZATION^{commit}" || fail 'F-SI27 materialization commit missing'
git merge-base --is-ancestor "$BASE" HEAD || fail 'branch does not descend from pinned canonical base'
git merge-base --is-ancestor "$FSI27_MATERIALIZATION" HEAD || fail 'qualified F-SI27 materialization not in candidate ancestry'

changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
expected_src="$(cat <<'EOF'
src/adapter/mod_reference_richards_legacy_binding.f90
src/solver/mod_reference_linear_solver.f90
src/solver/mod_reference_richards_workspace.f90
src/solver/mod_soil_water_solver_contract.f90
EOF
)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FSI28_RUNNER_FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
[[ "$(git rev-parse "$FSI27_MATERIALIZATION:src/adapter/mod_reference_richards_legacy_binding.f90")" == "$FSI27_ADAPTER_BLOB" ]] || \
  fail 'qualified F-SI27 adapter materialization drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$HEADCALC_BLOB" ]] || fail 'HeadCalc blob drift'

grep -Fq 'logical :: request_interface_sensitivity = .false.' src/solver/mod_soil_water_solver_contract.f90 || \
  fail 'explicit sensitivity request missing'
grep -Fq 'interface_sensitivity_backsolves = 0' src/solver/mod_soil_water_solver_contract.f90 || \
  fail 'sensitivity backsolve diagnostic missing'
grep -Fq 'public :: reference_tridag_backsolve' src/solver/mod_reference_linear_solver.f90 || \
  fail 'reusable TRIDAG backsolve seam missing'
grep -Fq 'capture_in_gamma = size(gamma) >= 2*n' src/solver/mod_reference_linear_solver.f90 || \
  fail 'temporary factorization capture missing'
grep -Fq 'ws%richards%band_rhs(n) = 1.0_real64' src/adapter/mod_reference_richards_legacy_binding.f90 || \
  fail 'native qbot e_N tangent RHS missing'
grep -Fq "result%interface_sensitivity%method = 'same-tridag-factor'" src/adapter/mod_reference_richards_legacy_binding.f90 || \
  fail 'same-factorization provenance missing'
grep -Fq 'ws%legacy_worker%diagnostics%alternative_solver_calls == 0' src/adapter/mod_reference_richards_legacy_binding.f90 || \
  fail 'alternative-solver fail-closed guard missing'
grep -Fq 'fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot' src/legacy/b1_10_port/headcalc.f90 || \
  fail 'native qbot residual sign authority missing'
echo 'FSI28_STATIC_SOURCE_LOCK=PASS'

# Use the exact qualified F-SI27 candidate fixture as the physical test source.
git show "$FSI27_FIXTURE_HEAD:tests/fsi/test_fsi27_explicit_prescribed_qbot.f90" > "$BUILD/fsi27_fixture.f90"
git show "$FSI27_FIXTURE_HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90" > "$BUILD/fsi04_real_headcalc_stubs.f90"

python3 - "$BUILD/fsi27_fixture.f90" "$BUILD/test_fsi28_interface_sensitivity.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
src = src.replace('program test_fsi27_explicit_prescribed_qbot',
                  'program test_fsi28_interface_sensitivity', 1)
src = src.replace('end program test_fsi27_explicit_prescribed_qbot',
                  'end program test_fsi28_interface_sensitivity', 1)
src = src.replace('soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED',
                  'soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED', 1)

call_marker = '  ! D: nearby unowned mode remains fail closed.'
if call_marker not in src:
    raise SystemExit('FSI28_TRANSFORM_FAIL call insertion marker missing')
call_block = r'''  ! F-SI28 stays inside the locally qualified F-SI27 mode-2 neighborhood:
  ! exact A equilibrium, exact C 0.99*qeq perturbation, and the fixed symmetric
  ! 1.01*qeq companion. This is a scope binding, not convergence/tolerance tuning.
  ! Finite-difference replays start from the identical base state; the production
  ! tangent itself is never FD-derived.
  call check_fsi28_tangent(qeq, qeq, 'equilibrium')
  call check_fsi28_tangent(qeq, qpert, 'fsi27-perturbed')
  call check_fsi28_tangent(qeq, 1.01_real64*qeq, 'symmetric-neighbor')

  ! Transactional seam: first publish a valid tangent, then force the same
  ! F-SI27 C physics through a one-Newton-iteration policy. The retry result
  ! must fail closed and may not leak the preceding accepted sensitivity.
  call check_fsi28_retry(qeq, qpert)

'''
src = src.replace(call_marker, call_block + call_marker, 1)

contains_marker = 'contains\n\n'
if contains_marker not in src:
    raise SystemExit('FSI28_TRANSFORM_FAIL contains marker missing')
proc = r'''contains

  subroutine check_fsi28_tangent(qtop_case, qbot_case, label)
    real(real64), intent(in) :: qtop_case, qbot_case
    character(len=*), intent(in) :: label
    type(soil_water_solve_request_t) :: req_off, req_on, req_plus, req_minus, req_replay
    type(soil_water_solve_result_t) :: res_off, res_on, res_plus, res_minus, res_replay, res_aba
    type(reference_richards_legacy_workspace_t) :: ws_off, ws_on, ws_plus, ws_minus
    real(real64) :: fd_step, fd_tangent, tangent, metric

    call configure_request(req_off, parameters, constitutive, source_sink, top_provider, initial_state, &
         qtop_case, qbot_case)
    call solver%solve(req_off, ws_off, res_off)
    call require(res_off%status == SW_SOLVE_CONVERGED, label//' OFF solve converged')
    call require(.not. res_off%interface_sensitivity%available, label//' OFF sensitivity unavailable')
    call require(res_off%diagnostics%interface_sensitivity_backsolves == 0, label//' OFF zero tangent backsolves')

    req_on = req_off
    req_on%request_interface_sensitivity = .true.
    call solver%solve(req_on, ws_on, res_on)
    call require(res_on%status == SW_SOLVE_CONVERGED, label//' ON solve converged')
    call require(res_on%interface_sensitivity%available, label//' ON sensitivity available')
    call require(trim(res_on%interface_sensitivity%method) == 'same-tridag-factor', label//' tangent provenance')
    call require(ieee_is_finite(res_on%interface_sensitivity%dh_bottom_dq_bottom), label//' finite tangent')
    call require(res_on%diagnostics%interface_sensitivity_backsolves == 1, label//' exactly one tangent backsolve')
    call require(res_on%diagnostics%nonlinear_iterations == res_off%diagnostics%nonlinear_iterations, &
         label//' no extra nonlinear trajectory')
    call require(res_on%diagnostics%jacobian_builds == res_off%diagnostics%jacobian_builds, &
         label//' no extra Jacobian build')
    call require(res_on%diagnostics%linear_solves == res_off%diagnostics%linear_solves, &
         label//' normal linear-solve count preserved')
    call require(res_on%diagnostics%alternative_solver_calls == 0, label//' normal TRIDAG route')
    call require_states_bitwise_equal(res_off%candidate_state, res_on%candidate_state, label//' ON/OFF state identity')
    call require(same_bits(res_off%top_flux,res_on%top_flux), label//' ON/OFF top flux identity')
    call require(same_bits(res_off%bottom_flux,res_on%bottom_flux), label//' ON/OFF qbot identity')
    call require(same_bits(res_off%unrounded_mass_balance_residual,res_on%unrounded_mass_balance_residual), &
         label//' ON/OFF mass identity')
    call require_state_unchanged(req_on%base_state, initial_state, label//' request/base state unchanged')
    call require(size(ws_on%richards%tridag_gamma) == numnod, label//' temporary factorization scratch released')

    ! Predeclared central-FD step: 1e-5 cm d-1 for this frozen qbot range.
    fd_step = 1.0e-5_real64
    req_plus = req_off
    req_plus%boundary%bottom_flux = qbot_case + fd_step
    req_minus = req_off
    req_minus%boundary%bottom_flux = qbot_case - fd_step
    call solver%solve(req_plus, ws_plus, res_plus)
    call solver%solve(req_minus, ws_minus, res_minus)
    call require(res_plus%status == SW_SOLVE_CONVERGED, label//' plus-FD converged')
    call require(res_minus%status == SW_SOLVE_CONVERGED, label//' minus-FD converged')
    call require(.not.res_plus%interface_sensitivity%available .and. .not.res_minus%interface_sensitivity%available, &
         label//' FD trajectories do not request production tangent')
    fd_tangent = (res_plus%candidate_state%pressure_head(numnod) - &
                  res_minus%candidate_state%pressure_head(numnod))/(2.0_real64*fd_step)
    tangent = res_on%interface_sensitivity%dh_bottom_dq_bottom
    metric = abs(tangent-fd_tangent)/max(1.0_real64,abs(fd_tangent))
    call require(ieee_is_finite(fd_tangent), label//' finite independent FD tangent')
    call require(metric <= 1.0e-6_real64, label//' frozen tangent metric <= 1e-6')
    if (abs(fd_tangent) > 1024.0_real64*epsilon(1.0_real64)) &
         call require(tangent*fd_tangent > 0.0_real64, label//' native qbot tangent sign agrees with FD')

    ! A/B/A reuse on the same worker workspace: an OFF replay must clear any
    ! prior sensitivity, and a repeated ON solve must reproduce it exactly.
    req_replay = req_off
    call solver%solve(req_replay, ws_on, res_replay)
    call require(.not.res_replay%interface_sensitivity%available, label//' ON->OFF stale sensitivity cleared')
    call require(res_replay%diagnostics%interface_sensitivity_backsolves == 0, label//' ON->OFF no stale cost counter')
    call solver%solve(req_on, ws_on, res_aba)
    call require(res_aba%interface_sensitivity%available, label//' A/B/A final ON sensitivity available')
    call require(same_bits(res_aba%interface_sensitivity%dh_bottom_dq_bottom,tangent), &
         label//' A/B/A tangent bitwise replay')
    call require_states_bitwise_equal(res_on%candidate_state,res_aba%candidate_state,label//' A/B/A state replay')
    call require(size(ws_on%richards%tridag_gamma) == numnod, label//' A/B/A scratch compact after return')

    write(*,'(A,A,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'FSI28_TANGENT:',trim(label),':ANALYTIC=',tangent,':FD=',fd_tangent,':METRIC=',metric
  end subroutine check_fsi28_tangent

  subroutine check_fsi28_retry(qtop_case, qbot_case)
    real(real64), intent(in) :: qtop_case, qbot_case
    type(soil_water_solve_request_t) :: req_accepted, req_retry
    type(soil_water_solve_result_t) :: res_accepted, res_retry
    type(reference_richards_legacy_workspace_t) :: ws

    call configure_request(req_accepted, parameters, constitutive, source_sink, top_provider, initial_state, &
         qtop_case, qbot_case)
    req_accepted%request_interface_sensitivity = .true.
    call solver%solve(req_accepted, ws, res_accepted)
    call require(res_accepted%status == SW_SOLVE_CONVERGED, 'retry seam accepted precursor converged')
    call require(res_accepted%interface_sensitivity%available, 'retry seam accepted precursor tangent available')
    call require(res_accepted%diagnostics%interface_sensitivity_backsolves == 1, &
         'retry seam accepted precursor exactly one tangent backsolve')

    req_retry = req_accepted
    req_retry%numerical%max_iterations = 1
    call solver%solve(req_retry, ws, res_retry)
    call require(res_retry%status == SW_SOLVE_RETRY_ADVISED, 'retry seam returns RETRY_ADVISED')
    call require(res_retry%retry_advised, 'retry seam retry flag set')
    call require(.not.res_retry%interface_sensitivity%available, 'retry seam publishes no stale tangent')
    call require(res_retry%diagnostics%interface_sensitivity_backsolves == 0, 'retry seam performs no tangent backsolve')
    call require_states_bitwise_equal(res_retry%candidate_state, initial_state, 'retry seam candidate rolled back to base state')
    call require_state_unchanged(req_retry%base_state, initial_state, 'retry seam request/base state unchanged')
    call require(size(ws%richards%tridag_gamma) == numnod, 'retry seam factorization scratch released')

    write(*,'(A,I0,A,I0,A,I0)') 'FSI28_RETRY_SEAM:STATUS=',res_retry%status, &
         ':NONLINEAR=',res_retry%diagnostics%nonlinear_iterations, &
         ':TANGENT_BACKSOLVES=',res_retry%diagnostics%interface_sensitivity_backsolves
  end subroutine check_fsi28_retry

'''
src = src.replace(contains_marker, proc, 1)
pass_stmt = "  write(*,'(A)') 'FSI27_EXPLICIT_PRESCRIBED_QBOT_GATE PASS'"
if pass_stmt not in src:
    raise SystemExit('FSI28_TRANSFORM_FAIL pass marker missing')
src = src.replace(pass_stmt, pass_stmt + "\n  write(*,'(A)') 'FSI28_INTERFACE_SENSITIVITY_GATE PASS'", 1)
Path(sys.argv[2]).write_text(src)
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
  "$BUILD/fsi04_real_headcalc_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  "$BUILD/test_fsi28_interface_sensitivity.f90"
)

compile_and_run() {
  local opt="$1" out="$BUILD/o$1" src obj
  local objects=()
  mkdir -p "$out"
  for src in "${MODULE_SRC[@]}"; do
    [[ -f "$src" ]] || fail "compile dependency missing: $src"
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fsi28"
  if ! timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test_fsi28" > "$out/output.txt"; then
    cat "$out/output.txt"
    fail "O${opt} executable failed"
  fi
  grep -Fq 'FSI27_EXPLICIT_PRESCRIBED_QBOT_GATE PASS' "$out/output.txt" || fail "O${opt} F-SI27 fixture regression failed"
  grep -Fq 'FSI28_INTERFACE_SENSITIVITY_GATE PASS' "$out/output.txt" || fail "O${opt} F-SI28 marker missing"
  [[ "$(grep -c '^FSI28_TANGENT:' "$out/output.txt")" == 3 ]] || fail "O${opt} expected three tangent cases"
  [[ "$(grep -c '^FSI28_RETRY_SEAM:' "$out/output.txt")" == 1 ]] || fail "O${opt} expected one retry seam case"
  cat "$out/output.txt"
  echo "FSI28_O${opt}=PASS"
}

compile_and_run 0
compile_and_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 observable output differs'
echo 'FSI28_O0_O2_IDENTITY=PASS'
echo 'FSI28_INTERFACE_SENSITIVITY_RUNNER PASS'
