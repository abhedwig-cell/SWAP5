#!/usr/bin/env python3
from pathlib import Path
import subprocess

KERNEL = Path('src/kernel/mod_kernel_transactions.f90')
RUNTIME = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
EXPECTED_KERNEL = '9f7c16e71cfb93b57f796ba759bae73824318a2f'
EXPECTED_RUNTIME = '1bb0c6d4683db2729d48de31babcea72bc1a6caf'
EXPECTED_QUALIFIED_KERNEL_POST = 'af42c7d51ef545e20c76d3000f1ed1493690d68e'
PROTECTED = {
    'src/process/mod_snow_process.f90': '54702d71b4c84dce2842813549bd14c57301a383',
    'src/runtime/mod_fmr_serialized_reference_backend.f90': '202ab846cbd30d149d0d450249b3d517e333994f',
    'tests/fmr/test_fmr06_snow_smoke.f90': '4f45bb0623fef3fb6d091579e8f435563c858a69',
}


def blob(path: Path | str) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def require_blob(path: Path | str, expected: str) -> None:
    actual = blob(path)
    if actual != expected:
        raise SystemExit(f'FPE05_COMPOSE_PREIMAGE_MISMATCH path={path} expected={expected} actual={actual}')


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FPE05_COMPOSE_{label}: expected one marker, found {count}')
    return text.replace(old, new, 1)


require_blob(KERNEL, EXPECTED_KERNEL)
require_blob(RUNTIME, EXPECTED_RUNTIME)
for path, expected in PROTECTED.items():
    require_blob(path, expected)

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
'KERNEL_FIELDS')
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
'KERNEL_MAPPING')
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
'RUNTIME_FIELDS')
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
'RUNTIME_MAPPING')
RUNTIME.write_text(r)

changed = subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
expected_changed = [str(KERNEL), str(RUNTIME)]
if changed != expected_changed:
    raise SystemExit(f'FPE05_COMPOSE_SCOPE_MISMATCH changed={changed}')

kernel_post = blob(KERNEL)
runtime_post = blob(RUNTIME)
if kernel_post != EXPECTED_QUALIFIED_KERNEL_POST:
    raise SystemExit(f'FPE05_COMPOSE_KERNEL_POST_MISMATCH expected={EXPECTED_QUALIFIED_KERNEL_POST} actual={kernel_post}')
for path, expected in PROTECTED.items():
    require_blob(path, expected)

print('FPE05_DIAGNOSTICS_COMPOSITION_SCOPE=PASS')
print('FPE05_KERNEL_DIAGNOSTICS_POST_REUSES_QUALIFIED_BLOB=PASS')
print('FPE05_PROTECTED_SNOW_SOURCE_UNCHANGED=PASS')
print('FPE05_KERNEL_POST_BLOB=' + kernel_post)
print('FPE05_RUNTIME_COMPOSED_POST_BLOB=' + runtime_post)
print('FPE05_DIAGNOSTICS_COMPOSITION MATERIALIZED_NOT_YET_QUALIFIED')
