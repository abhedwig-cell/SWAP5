#!/usr/bin/env python3
from pathlib import Path
import hashlib

HEAD = Path('src/legacy/b1_10_port/headcalc.f90')
TEST = Path('tests/fsi/test_fsi07_state_binding.F90')

EXPECTED = {
    HEAD: '1701d9e9410db206dfe28e42a6ad87d02bc2f432',
    TEST: '2a6fe4e22189df8ae9b092f70337c0f4deda60b3',
}

def blob_sha(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI07_FIX FAIL {label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)

for path, sha in EXPECTED.items():
    actual = blob_sha(path)
    if actual != sha:
        raise SystemExit(f'F-SI07_FIX FAIL source drift {path}: {actual} != {sha}')

h = HEAD.read_text()
h = replace_once(
    h,
    '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror\n',
    '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit\n',
    'local loop carrier declaration')
h = replace_once(
    h,
    '   do state%numbit = 1, MaxIt1\n      ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1\n',
    '   do solver_numbit = 1, MaxIt1\n      state%numbit = solver_numbit\n      ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1\n',
    'Newton iteration carrier')
h = replace_once(
    h,
    '   ! end do state%numbit = 1, MaxIt1\n   end do\n\n!  Convergence could not been reached\n',
    '   ! end do solver_numbit = 1, MaxIt1\n   end do\n   ! Preserve the legacy DO-variable value after normal loop exhaustion.\n   state%numbit = solver_numbit\n\n!  Convergence could not been reached\n',
    'post-loop legacy numbit semantics')
HEAD.write_text(h)

t = TEST.read_text()
t = replace_once(
    t,
    '    real(real64) :: residual, out_qtop, out_qbot\n    real(real64) :: global_h(numnod), global_theta(numnod), global_hm1(numnod), global_thetm1(numnod)\n    real(real64) :: global_pond, global_pondm1, global_gwl, global_gwlm1, global_qtop, global_qbot\n    integer :: i, expected_alternative, out_numbit\n',
    '    real(real64) :: residual, out_qtop, out_qbot\n#ifndef FSI07_PREIMAGE\n#ifndef FSI07_COMPAT_CALL\n    real(real64) :: global_h(numnod), global_theta(numnod), global_hm1(numnod), global_thetm1(numnod)\n    real(real64) :: global_pond, global_pondm1, global_gwl, global_gwlm1, global_qtop, global_qbot\n#endif\n#endif\n    integer :: i, expected_alternative, out_numbit\n',
    'test-only sentinel declarations')
TEST.write_text(t)

print('F-SI07_FIX_NUMBIT_CARRIER MATERIALIZED')
