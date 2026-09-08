#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

FPE02 = '2c28a4366440885faedbe2fbe3ce56104d82692e'
KERNEL = Path('src/kernel/mod_kernel_transactions.f90')
RUNTIME = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
KERNEL_PRE = '9f7c16e71cfb93b57f796ba759bae73824318a2f'
KERNEL_POST = 'af42c7d51ef545e20c76d3000f1ed1493690d68e'
RUNTIME_PRE = '1bb0c6d4683db2729d48de31babcea72bc1a6caf'

FIELDS = """    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
"""
ASSIGN = """    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
"""


def blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def committed_blob(path: Path) -> str:
    return subprocess.check_output(['git', 'rev-parse', f'HEAD:{path.as_posix()}'], text=True).strip()


def qualified_kernel() -> str:
    return subprocess.check_output(['git', 'show', f'{FPE02}:{KERNEL.as_posix()}'], text=True)


def verify():
    if blob(KERNEL) != KERNEL_POST:
        raise SystemExit(f'FMR14_KERNEL_POST_BLOB_MISMATCH actual={blob(KERNEL)} expected={KERNEL_POST}')
    r = RUNTIME.read_text()
    required = [
        FIELDS,
        ASSIGN,
        'integer :: solver_iterations = 0\n' + FIELDS,
        'diagnostic%retries = kernel_diag%retries\n' + ASSIGN,
    ]
    for item in required:
        if r.count(item) != 1:
            raise SystemExit('FMR14_RUNTIME_OBSERVER_DELTA_VERIFY_FAIL')
    forbidden = [
        'if (output%solver_nonlinear_iterations',
        'if (output%solver_headcalc_calls',
        'if (output%solver_backtracking_attempts',
    ]
    for item in forbidden:
        if item in r:
            raise SystemExit(f'FMR14_OBSERVER_COUNTER_USED_IN_DECISION_FAIL {item}')
    print('FMR14_KERNEL_EXACT_FPE02_QUALIFIED_POST_BLOB=PASS')
    print('FMR14_RUNTIME_OBSERVER_FIELDS_AND_ASSIGNMENTS=PASS')
    print('FMR14_OBSERVER_COUNTERS_NOT_USED_IN_DECISIONS=PASS')


def materialize():
    k = committed_blob(KERNEL)
    r = committed_blob(RUNTIME)
    if k != KERNEL_PRE:
        raise SystemExit(f'FMR14_KERNEL_PRE_BLOB_MISMATCH actual={k} expected={KERNEL_PRE}')
    if r != RUNTIME_PRE:
        raise SystemExit(f'FMR14_RUNTIME_PRE_BLOB_MISMATCH actual={r} expected={RUNTIME_PRE}')

    kp = qualified_kernel()
    KERNEL.write_text(kp)
    if blob(KERNEL) != KERNEL_POST:
        raise SystemExit('FMR14_QUALIFIED_KERNEL_MATERIALIZATION_FAIL')

    text = RUNTIME.read_text()
    field_anchor = '    integer :: solver_iterations = 0\n'
    assign_anchor = '    diagnostic%retries = kernel_diag%retries\n'
    if text.count(field_anchor) != 1 or text.count(assign_anchor) != 1:
        raise SystemExit('FMR14_RUNTIME_PREIMAGE_ANCHOR_FAIL')
    if FIELDS in text or ASSIGN in text:
        raise SystemExit('FMR14_RUNTIME_ALREADY_MATERIALIZED_UNEXPECTEDLY')
    text = text.replace(field_anchor, field_anchor + FIELDS, 1)
    text = text.replace(assign_anchor, assign_anchor + ASSIGN, 1)
    RUNTIME.write_text(text)
    verify()
    changed = subprocess.check_output(['git', 'diff', '--name-only', '--', 'src'], text=True).splitlines()
    expected = [KERNEL.as_posix(), RUNTIME.as_posix()]
    if sorted(changed) != sorted(expected):
        raise SystemExit(f'FMR14_UNEXPECTED_SOURCE_DELTA {changed}')
    print('FMR14_SOURCE_DELTA_EXACTLY_TWO_OBSERVER_PATHS=PASS')


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'verify'
    if mode == 'materialize':
        materialize()
    elif mode == 'verify':
        verify()
    else:
        raise SystemExit('usage: fmr14_materialize.py [materialize|verify]')
