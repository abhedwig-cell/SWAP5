#!/usr/bin/env python3
"""Materialize the F-SI06 HeadCalc history-isolation seam.

Transforms only the exact qualified F-SI05 postimage. The change makes hidden
HeadCalc SAVE ownership explicit in the legacy caller and gives HeadCalc an
explicit optional history carrier. No Richards expression, convergence
criterion, time-step policy or transaction semantic is changed.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

PINS = {
    Path('src/legacy/b1_10_port/headcalc.f90'): 'e22251c8f562839857cdb7a609a8148d1f2d58f8',
    Path('src/legacy/b1_10_port/soilwater.f90'): '74e2e115b735a9a8c341603fca8b01ef44710da7',
    Path('src/adapter/mod_reference_richards_legacy_binding.f90'): 'e02882bd45f67b42ede118de14a6b5b8b16fdb80',
}


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    header = f'blob {len(data)}\0'.encode()
    return hashlib.sha1(header + data).hexdigest()


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'F-SI06_MATERIALIZE FAIL {label}: expected {expected}, found {count}')
    return text.replace(old, new)


def transform_headcalc(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        'subroutine headcalc(worker, fsi_workspace)',
        'subroutine headcalc(worker, fsi_workspace, history)',
        'headcalc signature',
    )
    text = replace_exact(
        text,
        '   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker',
        '   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker',
        'headcalc worker use',
    )
    text = replace_exact(
        text,
        '   type(reference_richards_workspace_t), pointer :: fsi_ws\n!  local\n   type(a23bu_worker_context_t), target, save :: legacy_worker\n   type(a23bu_worker_context_t), pointer :: ctx',
        '   type(reference_richards_workspace_t), pointer :: fsi_ws\n   type(a23bu_solver_history_t), target, intent(inout), optional :: history\n   type(a23bu_solver_history_t), target :: local_history\n   type(a23bu_solver_history_t), pointer :: hist\n!  local\n   type(a23bu_worker_context_t), target :: local_worker\n   type(a23bu_worker_context_t), pointer :: ctx',
        'headcalc history declarations',
    )
    text = replace_exact(
        text,
        '   canonical_trial = present(worker)\n   if (canonical_trial) then\n      ctx => worker\n   else\n      ctx => legacy_worker\n   end if\n   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)\n   if (present(fsi_workspace)) then',
        '   canonical_trial = present(worker)\n   if (canonical_trial) then\n      ctx => worker\n   else\n      ctx => local_worker\n   end if\n   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)\n   if (present(history)) then\n      hist => history\n   else\n      hist => local_history\n   end if\n   if (present(fsi_workspace)) then',
        'headcalc explicit worker/history selection',
    )
    history_count = text.count('ctx%history%')
    if history_count != 12:
        raise SystemExit(f'F-SI06_MATERIALIZE FAIL history references: expected 12, found {history_count}')
    text = text.replace('ctx%history%', 'hist%')
    if 'save :: legacy_worker' in text or 'ctx%history%' in text:
        raise SystemExit('F-SI06_MATERIALIZE FAIL hidden HeadCalc history/singleton remains')
    path.write_text(text)


def transform_soilwater(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        'module MOD_SoilWater\n\n   private',
        'module MOD_SoilWater\n\n   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n   implicit none\n   type(a23bu_worker_context_t), save :: legacy_headcalc_worker\n   type(a23bu_solver_history_t), save :: legacy_headcalc_history\n\n   private',
        'soilwater explicit legacy compatibility context',
    )
    text = replace_exact(
        text,
        '      use MOD_swap_base, only: swmacro, swinco, swhyst, swsolve\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n      use MOD_arrays,    only: mabbc',
        '      use MOD_swap_base, only: swmacro, swinco, swhyst, swsolve\n      use MOD_arrays,    only: mabbc',
        'soilwater subroutine worker import',
    )
    text = replace_exact(
        text,
        '         subroutine headcalc(worker)\n            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n            type(a23bu_worker_context_t), intent(inout), optional :: worker\n         end subroutine headcalc',
        '         subroutine headcalc(worker, fsi_workspace, history)\n            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n            use mod_reference_richards_workspace, only: reference_richards_workspace_t\n            type(a23bu_worker_context_t), intent(inout), optional :: worker\n            type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n            type(a23bu_solver_history_t), target, intent(inout), optional :: history\n         end subroutine headcalc',
        'soilwater HeadCalc interface',
    )
    text = replace_exact(
        text,
        '            call headcalc(worker)',
        '            if (present(worker)) then\n               call headcalc(worker, history=worker%history)\n            else\n               call headcalc(legacy_headcalc_worker, history=legacy_headcalc_history)\n            end if',
        'soilwater explicit legacy call',
    )
    path.write_text(text)


def transform_adapter(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        '  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &\n       a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control',
        '  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, &\n       a23bu_initialize_worker, a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control',
        'adapter worker/history use',
    )
    text = replace_exact(
        text,
        '     subroutine headcalc(worker, fsi_workspace)\n       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n       type(a23bu_worker_context_t), intent(inout), optional :: worker\n       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n     end subroutine headcalc',
        '     subroutine headcalc(worker, fsi_workspace, history)\n       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n       type(a23bu_worker_context_t), intent(inout), optional :: worker\n       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n       type(a23bu_solver_history_t), target, intent(inout), optional :: history\n     end subroutine headcalc',
        'adapter HeadCalc interface',
    )
    text = replace_exact(
        text,
        '    logical :: ok\n    real(real64), allocatable :: h_saved(:), theta_saved(:), hm1_saved(:), thetm1_saved(:)',
        '    logical :: ok\n    type(a23bu_solver_history_t) :: call_history\n    real(real64), allocatable :: h_saved(:), theta_saved(:), hm1_saved(:), thetm1_saved(:)',
        'adapter call history declaration',
    )
    text = replace_exact(
        text,
        '       call headcalc(ws%legacy_worker, ws%richards)',
        '       call headcalc(ws%legacy_worker, ws%richards, call_history)',
        'adapter explicit call-local history',
    )
    path.write_text(text)


def main() -> None:
    for path, expected in PINS.items():
        actual = git_blob_sha(path)
        if actual != expected:
            raise SystemExit(f'F-SI06_MATERIALIZE FAIL preimage {path}: {actual} != {expected}')
    transform_headcalc(Path('src/legacy/b1_10_port/headcalc.f90'))
    transform_soilwater(Path('src/legacy/b1_10_port/soilwater.f90'))
    transform_adapter(Path('src/adapter/mod_reference_richards_legacy_binding.f90'))
    print('F-SI06_MATERIALIZE PASS')
    print('physics_change_intended=false')
    print('numerical_policy_change_intended=false')
    print('transaction_semantics_change_intended=false')


if __name__ == '__main__':
    main()
