#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

BASE = 'e639ca5ae703d6bdb97829a0bd7d2762db1d8a9a'
MODULE_PATH = 'src/solver/mod_reference_linear_solver.f90'
MODULE_BLOB = 'b292d284e5549049eac1c80df4cc30008154eb96'
PREIMAGE = {
    'src/legacy/b1_10_port/headcalc.f90': '420fe2996199e6d3f162b7669957e1a95919f353',
    'src/solver/mod_reference_richards_workspace.f90': '93285b2ca24669494c93c00403e3783fca6758e9',
}

TRANSFORMS = {
    'src/legacy/b1_10_port/headcalc.f90': [
        (
            '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n',
            '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n'
            '   use mod_reference_linear_solver, only: reference_tridag, reference_band_solve\n',
        ),
        ('   use MOD_arrays,         only: macp, mabbc\n', '   use MOD_arrays,         only: mabbc\n'),
        (
            '      call tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, fsi_ws%residual, fsi_ws%delta_head, ierror)\n',
            '      call reference_tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, &\n'
            '           fsi_ws%residual, fsi_ws%delta_head, fsi_ws%tridag_gamma, ierror)\n',
        ),
        ('   real(8)                    :: d\n', ''),
        (
            '   call bandec(fsi_ws%band_matrix, NN, 1, 1, macp, 3, fsi_ws%band_aux, 1, fsi_ws%band_pivots, d)\n',
            '',
        ),
        (
            '   call banbks(fsi_ws%band_matrix,nn,1,1,macp,3,fsi_ws%band_aux,1,fsi_ws%band_pivots,fsi_ws%band_rhs)\n',
            '   call reference_band_solve(fsi_ws%band_matrix, fsi_ws%band_aux, fsi_ws%band_pivots(1:NN), &\n'
            '        fsi_ws%band_rhs(1:NN))\n',
        ),
    ],
    'src/solver/mod_reference_richards_workspace.f90': [
        (
            '     real(real64), allocatable :: delta_head(:)\n',
            '     real(real64), allocatable :: delta_head(:)\n'
            '     real(real64), allocatable :: tridag_gamma(:)\n',
        ),
        (
            '       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes))\n',
            '       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))\n',
        ),
        (
            '    workspace%delta_head = 0.0_real64\n',
            '    workspace%delta_head = 0.0_real64\n'
            '    workspace%tridag_gamma = 0.0_real64\n',
        ),
        (
            '    workspace%delta_head = qnan\n',
            '    workspace%delta_head = qnan\n'
            '    workspace%tridag_gamma = qnan\n',
        ),
        (
            '    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n',
            '    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n'
            '    if (allocated(workspace%tridag_gamma)) deallocate(workspace%tridag_gamma)\n',
        ),
        (
            '    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n',
            '    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n'
            '    if (allocated(workspace%tridag_gamma)) nreal = nreal + size(workspace%tridag_gamma, kind=int64)\n',
        ),
    ],
}


def git(*args: str) -> str:
    return subprocess.check_output(['git', *args], text=True).strip()


def apply() -> None:
    module_blob = git('rev-parse', f'HEAD:{MODULE_PATH}')
    if module_blob != MODULE_BLOB:
        raise SystemExit(f'FMR13_MODULE_BLOB_LOCK_FAIL expected={MODULE_BLOB} actual={module_blob}')

    for path, expected in PREIMAGE.items():
        actual = git('hash-object', path)
        if actual != expected:
            raise SystemExit(f'FMR13_PREIMAGE_BLOB_LOCK_FAIL {path} expected={expected} actual={actual}')

    for path, transforms in TRANSFORMS.items():
        p = Path(path)
        text = p.read_text()
        for old, new in transforms:
            count = text.count(old)
            if count != 1:
                raise SystemExit(f'FMR13_PATCH_MATCH_FAIL {path} count={count} fragment={old[:80]!r}')
            text = text.replace(old, new, 1)
        p.write_text(text)

    print('FMR13_FAIL_CLOSED_MATERIALIZATION=PASS')


def verify() -> None:
    module_blob = git('rev-parse', f'HEAD:{MODULE_PATH}')
    if module_blob != MODULE_BLOB:
        raise SystemExit(f'FMR13_MODULE_BLOB_LOCK_FAIL expected={MODULE_BLOB} actual={module_blob}')

    for path, transforms in TRANSFORMS.items():
        current = Path(path).read_text()
        reverted = current
        for old, new in transforms:
            if new:
                count = reverted.count(new)
                if count != 1:
                    raise SystemExit(f'FMR13_COMPOSED_POSTIMAGE_FAIL {path} count={count} fragment={new[:80]!r}')
                reverted = reverted.replace(new, old, 1)
            else:
                # Removal-only transformations are restored at their unique qualified anchor.
                if old.strip().startswith('real(8)'):
                    anchor = '   integer                    :: i\n'
                    if reverted.count(anchor) != 1:
                        raise SystemExit(f'FMR13_COMPOSED_POSTIMAGE_FAIL {path} removal-anchor=d')
                    reverted = reverted.replace(anchor, anchor + old, 1)
                elif 'call bandec' in old:
                    anchor = '   fsi_ws%band_rhs(1:NN) = fsi_ws%residual(1:NN)\n'
                    if reverted.count(anchor) != 1:
                        raise SystemExit(f'FMR13_COMPOSED_POSTIMAGE_FAIL {path} removal-anchor=bandec')
                    reverted = reverted.replace(anchor, old + anchor, 1)
                else:
                    raise SystemExit('FMR13_INTERNAL_VERIFY_UNHANDLED_REMOVAL')
        base = subprocess.check_output(['git', 'show', f'{BASE}:{path}'], text=True)
        if reverted != base:
            raise SystemExit(f'FMR13_COMPOSED_POSTIMAGE_NOT_EXACT_BASE_PLUS_FSI19_DELTA {path}')

    print('FMR13_EXACT_BASE_PLUS_FSI19_DELTA=PASS')


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'apply'
    if mode == 'apply':
        apply()
    elif mode == 'verify':
        verify()
    else:
        raise SystemExit('usage: fmr13_materialize.py [apply|verify]')
