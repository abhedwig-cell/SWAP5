#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

KERNEL = Path('src/kernel/mod_kernel_transactions.f90')
RUNTIME = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
TEST = Path('tests/fmr/test_fmr05_serialized_multiswap.f90')
EXPECTED_KERNEL = '9f7c16e71cfb93b57f796ba759bae73824318a2f'
EXPECTED_RUNTIME = 'e4f5bc0bf47e2721d689e62107b5224196a093d9'
EXPECTED_TEST = '51dc410308c1d0e6a8aa8c7ad26d08b87333d0a1'


def blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-PE02 {label}: expected one marker, found {count}')
    return text.replace(old, new, 1)


def require_preimage(path: Path, expected: str) -> None:
    actual = blob(path)
    if actual != expected:
        raise SystemExit(f'F-PE02 preimage mismatch {path}: expected={expected} actual={actual}')


def materialize() -> None:
    require_preimage(KERNEL, EXPECTED_KERNEL)
    require_preimage(RUNTIME, EXPECTED_RUNTIME)

    k = KERNEL.read_text()
    k = once(k,
'''    integer :: checkpoint_time_rejections = 0
    real(real64) :: max_abs_step_mass_residual = 0.0_real64''',
'''    integer :: checkpoint_time_rejections = 0
    integer :: nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    real(real64) :: max_abs_step_mass_residual = 0.0_real64''',
'kernel diagnostics fields')
    k = once(k,
'''    diagnostics%mass_rejections = runtime_diagnostics%mass_rejections
    diagnostics%max_abs_step_mass_residual = runtime_diagnostics%max_abs_step_mass_residual''',
'''    diagnostics%mass_rejections = runtime_diagnostics%mass_rejections
    diagnostics%nonlinear_iterations = runtime_diagnostics%nonlinear_iterations
    diagnostics%internal_retries = runtime_diagnostics%internal_retries
    diagnostics%headcalc_calls = runtime_diagnostics%headcalc_calls
    diagnostics%jacobian_builds = runtime_diagnostics%jacobian_builds
    diagnostics%linear_solves = runtime_diagnostics%linear_solves
    diagnostics%backtracking_attempts = runtime_diagnostics%backtracking_attempts
    diagnostics%alternative_solver_calls = runtime_diagnostics%alternative_solver_calls
    diagnostics%max_abs_step_mass_residual = runtime_diagnostics%max_abs_step_mass_residual''',
'kernel diagnostics mapping')
    KERNEL.write_text(k)

    r = RUNTIME.read_text()
    r = once(r,
'''    character(len=32) :: solver_route = 'not-run'
    integer :: solver_iterations = 0
    integer(int64) :: initial_revision = -1_int64''',
'''    character(len=32) :: solver_route = 'not-run'
    integer :: solver_iterations = 0
    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
    integer(int64) :: initial_revision = -1_int64''',
'F-MR column result fields')
    r = once(r,
'''    diagnostic%attempts = kernel_diag%attempts
    diagnostic%retries = kernel_diag%retries
    candidate_ready = candidate%ready()''',
'''    diagnostic%attempts = kernel_diag%attempts
    diagnostic%retries = kernel_diag%retries
    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
    candidate_ready = candidate%ready()''',
'F-MR column diagnostic propagation')
    RUNTIME.write_text(r)

    changed = subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
    expected = [str(KERNEL), str(RUNTIME)]
    if changed != expected:
        raise SystemExit(f'F-PE02 unexpected materialization scope: {changed}')
    print('FPE02_DIAGNOSTICS_MATERIALIZATION PASS')
    print('kernel_post_blob=' + blob(KERNEL))
    print('runtime_post_blob=' + blob(RUNTIME))


def instrument_test() -> None:
    require_preimage(TEST, EXPECTED_TEST)
    t = TEST.read_text()
    t = once(t,
'''      call require(results(i)%solver_iterations >= 1, 'solver iterations')
      call require(results(i)%initial_revision == 0_int64 .and. results(i)%final_revision == 1_int64, &''',
'''      call require(results(i)%solver_iterations >= 1, 'solver iterations')
      call require(results(i)%accepted_substeps >= 1, 'accepted substeps propagated')
      call require(results(i)%solver_nonlinear_iterations >= 1, 'nonlinear iterations propagated')
      call require(results(i)%solver_internal_retries >= 0, 'internal retries propagated')
      call require(results(i)%solver_headcalc_calls >= 1, 'HeadCalc calls propagated')
      call require(results(i)%solver_jacobian_builds >= 1, 'Jacobian builds propagated')
      call require(results(i)%solver_linear_solves >= 1, 'linear solves propagated')
      call require(results(i)%solver_backtracking_attempts >= 0, 'backtracking attempts propagated')
      call require(results(i)%solver_alternative_solver_calls >= 0, 'alternative solver calls propagated')
      call require(results(i)%initial_revision == 0_int64 .and. results(i)%final_revision == 1_int64, &''',
'F-MR success assertions')
    t = once(t,
'''  baseline_max_abs_residual = max_abs_residual(baseline_results)

  do i = 1, nbatch''',
'''  baseline_max_abs_residual = max_abs_residual(baseline_results)
  write(*,'(A,I0)') 'FPE02_ACCEPTED_SUBSTEPS=', baseline_results(1)%accepted_substeps
  write(*,'(A,I0)') 'FPE02_NONLINEAR_ITERATIONS=', baseline_results(1)%solver_nonlinear_iterations
  write(*,'(A,I0)') 'FPE02_INTERNAL_RETRIES=', baseline_results(1)%solver_internal_retries
  write(*,'(A,I0)') 'FPE02_HEADCALC_CALLS=', baseline_results(1)%solver_headcalc_calls
  write(*,'(A,I0)') 'FPE02_JACOBIAN_BUILDS=', baseline_results(1)%solver_jacobian_builds
  write(*,'(A,I0)') 'FPE02_LINEAR_SOLVES=', baseline_results(1)%solver_linear_solves
  write(*,'(A,I0)') 'FPE02_BACKTRACKING_ATTEMPTS=', baseline_results(1)%solver_backtracking_attempts
  write(*,'(A,I0)') 'FPE02_ALTERNATIVE_SOLVER_CALLS=', baseline_results(1)%solver_alternative_solver_calls
  write(*,'(A)') 'FPE02_DIAGNOSTICS_PROPAGATION=PASS'

  do i = 1, nbatch''',
'F-MR diagnostic evidence output')
    t = once(t,
'''         trim(left%solver_route) == trim(right%solver_route) .and. left%solver_iterations == right%solver_iterations .and. &
         left%initial_revision == right%initial_revision .and. left%final_revision == right%final_revision .and. &''',
'''         trim(left%solver_route) == trim(right%solver_route) .and. left%solver_iterations == right%solver_iterations .and. &
         left%accepted_substeps == right%accepted_substeps .and. &
         left%solver_nonlinear_iterations == right%solver_nonlinear_iterations .and. &
         left%solver_internal_retries == right%solver_internal_retries .and. &
         left%solver_headcalc_calls == right%solver_headcalc_calls .and. &
         left%solver_jacobian_builds == right%solver_jacobian_builds .and. &
         left%solver_linear_solves == right%solver_linear_solves .and. &
         left%solver_backtracking_attempts == right%solver_backtracking_attempts .and. &
         left%solver_alternative_solver_calls == right%solver_alternative_solver_calls .and. &
         left%initial_revision == right%initial_revision .and. left%final_revision == right%final_revision .and. &''',
'F-MR diagnostic identity comparison')
    TEST.write_text(t)
    print('FPE02_TEST_INSTRUMENTATION PASS')


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {'materialize', 'instrument-test'}:
        raise SystemExit('usage: fpe02_diagnostics_candidate.py materialize|instrument-test')
    if sys.argv[1] == 'materialize':
        materialize()
    else:
        instrument_test()


if __name__ == '__main__':
    main()
