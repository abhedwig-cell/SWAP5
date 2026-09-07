#!/usr/bin/env python3
"""Materialize the F-SI07 explicit reference-Richards state binding.

The transformation is pinned to the qualified F-SI06 postimage. It moves
HeadCalc's mutable request/candidate hydraulic state behind an explicit
per-solve carrier. Legacy top-boundary calls are bridged transactionally at the
provider boundary so serial B1.10 behavior is retained. Richards expressions,
convergence criteria and numerical policy are not intentionally changed.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

PINS = {
    Path('src/legacy/b1_10_port/headcalc.f90'): '38de52dd9f13b70a61f418c29a5c2e4bc9a449a9',
    Path('src/legacy/b1_10_port/soilwater.f90'): 'aa072804768b7a982b275d3a7d6988bfed6b9faa',
    Path('src/adapter/mod_reference_richards_legacy_binding.f90'): 'f60f7ef2d60ccb8cc78e80d56ef88a739e50ab2e',
}

STATE_NAMES = [
    'thetm1', 'pondm1', 'gwlm1', 'gwlinp', 'kmean', 'dimoca', 'itnumb',
    'fllowgwl', 'fldecdt', 'numbit', 'dtold', 'runots', 'flrunoff', 'ftoph',
    'hsurf', 'qtop', 'qbot', 'hbot', 'theta', 'hm1', 'pond', 'gwl', 'q0', 'k', 'h',
]


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    header = f'blob {len(data)}\0'.encode()
    return hashlib.sha1(header + data).hexdigest()


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'F-SI07_MATERIALIZE FAIL {label}: expected {expected}, found {count}')
    return text.replace(old, new)


def replace_state_tokens(text: str) -> str:
    for name in STATE_NAMES:
        text = re.sub(rf'\b{name}\b', f'state%{name}', text, flags=re.IGNORECASE)
    return text


def transform_headcalc(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        'subroutine headcalc(worker, fsi_workspace, history)',
        'subroutine headcalc(worker, fsi_workspace, history, state_binding)',
        'HeadCalc signature',
    )
    text = replace_exact(
        text,
        '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n',
        '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n'
        '   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding\n',
        'HeadCalc state module use',
    )
    text = replace_exact(
        text,
        '   type(a23bu_solver_history_t), pointer :: hist\n!  local\n',
        '   type(a23bu_solver_history_t), pointer :: hist\n'
        '   type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n'
        '   type(reference_richards_state_binding_t), target :: local_state_binding\n'
        '   type(reference_richards_state_binding_t), pointer :: state\n'
        '   logical :: legacy_state_binding, state_ok\n!  local\n',
        'HeadCalc state declarations',
    )
    text = replace_exact(
        text,
        '   if (present(history)) then\n      hist => history\n   else\n      hist => local_history\n   end if\n   if (present(fsi_workspace)) then',
        '   if (present(history)) then\n      hist => history\n   else\n      hist => local_history\n   end if\n'
        '   legacy_state_binding = .not. present(state_binding)\n'
        '   if (present(state_binding)) then\n'
        '      state => state_binding\n'
        '      call validate_reference_state_binding(state, state_ok)\n'
        "      if (.not. state_ok) error stop 'HeadCalc: invalid explicit state binding'\n"
        '   else\n'
        '      state => local_state_binding\n'
        '      call capture_legacy_state(state)\n'
        '   end if\n'
        '   if (present(fsi_workspace)) then',
        'HeadCalc state selection',
    )

    exec_marker = '   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1\n'
    pos = text.find(exec_marker)
    if pos < 0:
        raise SystemExit('F-SI07_MATERIALIZE FAIL HeadCalc execution marker')
    split = pos + len(exec_marker)
    prefix, tail = text[:split], text[split:]
    tail = replace_state_tokens(tail)

    if tail.count('call boundtop(2)') != 1:
        raise SystemExit(f'F-SI07_MATERIALIZE FAIL boundtop call count={tail.count("call boundtop(2)")}')
    tail = tail.replace('call boundtop(2)', 'call boundtop_state_bridge(2)')
    pond_calls = tail.count('call pondrunoff ()')
    if pond_calls < 1:
        raise SystemExit('F-SI07_MATERIALIZE FAIL no pondrunoff calls found')
    tail = tail.replace('call pondrunoff ()', 'call pondrunoff_state_bridge()')

    contains_marker = '\ncontains\n'
    ci = tail.find(contains_marker)
    if ci < 0:
        raise SystemExit('F-SI07_MATERIALIZE FAIL HeadCalc contains marker')
    parent, internal = tail[:ci], tail[ci + len(contains_marker):]
    returns = re.findall(r'(?m)^(\s*)return\s*$', parent)
    if len(returns) != 5:
        raise SystemExit(f'F-SI07_MATERIALIZE FAIL parent return count: expected 5, found {len(returns)}')
    parent = re.sub(
        r'(?m)^(\s*)return\s*$',
        lambda m: f"{m.group(1)}if (legacy_state_binding) call publish_legacy_state(state)\n{m.group(1)}return",
        parent,
    )

    helpers = r'''

subroutine capture_legacy_state(s)
   type(reference_richards_state_binding_t), intent(inout) :: s
   s%active_nodes = numnod
   s%h = h(1:numnod)
   s%theta = theta(1:numnod)
   s%hm1 = hm1(1:numnod)
   s%thetm1 = thetm1(1:numnod)
   s%k = k(1:numnod)
   s%kmean = kmean(1:numnod+1)
   s%dimoca = dimoca(1:numnod)
   s%pond = pond
   s%pondm1 = pondm1
   s%gwl = gwl
   s%gwlm1 = gwlm1
   s%gwlinp = gwlinp
   s%dtold = dtold
   s%qtop = qtop
   s%qbot = qbot
   s%hbot = hbot
   s%itnumb = itnumb
   s%numbit = numbit
   s%fllowgwl = fllowgwl
   s%fldecdt = fldecdt
   s%q0 = q0
   s%hsurf = hsurf
   s%runots = runots
   s%flrunoff = flrunoff
   s%ftoph = ftoph
end subroutine capture_legacy_state

subroutine publish_legacy_state(s)
   type(reference_richards_state_binding_t), intent(in) :: s
   h(1:numnod) = s%h
   theta(1:numnod) = s%theta
   hm1(1:numnod) = s%hm1
   thetm1(1:numnod) = s%thetm1
   k(1:numnod) = s%k
   kmean(1:numnod+1) = s%kmean
   dimoca(1:numnod) = s%dimoca
   pond = s%pond
   pondm1 = s%pondm1
   gwl = s%gwl
   gwlm1 = s%gwlm1
   gwlinp = s%gwlinp
   dtold = s%dtold
   qtop = s%qtop
   qbot = s%qbot
   hbot = s%hbot
   itnumb = s%itnumb
   numbit = s%numbit
   fllowgwl = s%fllowgwl
   fldecdt = s%fldecdt
   q0 = s%q0
   hsurf = s%hsurf
   runots = s%runots
   flrunoff = s%flrunoff
   ftoph = s%ftoph
end subroutine publish_legacy_state

subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   if (legacy_state_binding) then
      call publish_legacy_state(state)
      call boundtop(task)
      call capture_legacy_state(state)
   else
      call capture_legacy_state(saved)
      call publish_legacy_state(state)
      call boundtop(task)
      call capture_legacy_state(state)
      call publish_legacy_state(saved)
   end if
end subroutine boundtop_state_bridge

subroutine pondrunoff_state_bridge()
   type(reference_richards_state_binding_t) :: saved
   if (legacy_state_binding) then
      call publish_legacy_state(state)
      call pondrunoff()
      call capture_legacy_state(state)
   else
      call capture_legacy_state(saved)
      call publish_legacy_state(state)
      call pondrunoff()
      call capture_legacy_state(state)
      call publish_legacy_state(saved)
   end if
end subroutine pondrunoff_state_bridge
'''

    text = prefix + parent + contains_marker + helpers + internal
    if 'state%state%' in text:
        raise SystemExit('F-SI07_MATERIALIZE FAIL doubled state token')
    if 'save :: legacy_worker' in text:
        raise SystemExit('F-SI07_MATERIALIZE FAIL hidden worker SAVE returned')
    path.write_text(text)


def transform_soilwater(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        '         subroutine headcalc(worker, fsi_workspace, history)\n'
        '            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n'
        '            use mod_reference_richards_workspace, only: reference_richards_workspace_t\n'
        '            type(a23bu_worker_context_t), intent(inout), optional :: worker\n'
        '            type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n'
        '            type(a23bu_solver_history_t), target, intent(inout), optional :: history\n'
        '         end subroutine headcalc',
        '         subroutine headcalc(worker, fsi_workspace, history, state_binding)\n'
        '            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n'
        '            use mod_reference_richards_workspace, only: reference_richards_workspace_t\n'
        '            use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n'
        '            type(a23bu_worker_context_t), intent(inout), optional :: worker\n'
        '            type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n'
        '            type(a23bu_solver_history_t), target, intent(inout), optional :: history\n'
        '            type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n'
        '         end subroutine headcalc',
        'SoilWater HeadCalc interface',
    )
    path.write_text(text)


def transform_adapter(path: Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        '  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &\n'
        '       reset_reference_workspace\n',
        '  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &\n'
        '       reset_reference_workspace\n'
        '  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &\n'
        '       initialize_reference_state_binding\n',
        'adapter state module use',
    )
    text = replace_exact(
        text,
        '  use MOD_swap_base, only: swmacro\n',
        '  use MOD_swap_base, only: swmacro\n'
        '  use MOD_top, only: q0, flrunoff, ftoph, hsurf\n',
        'adapter top compatibility imports',
    )
    text = replace_exact(
        text,
        '  use variables, only: h, theta, pond, gwl, hm1, thetm1, pondm1, gwlm1, dt, swbotb, &\n'
        '       maxit, maxbacktr, swkimpl, swkmean, dtmin, CritDevBalCp, CritDevBalTot, &\n'
        '       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, fldecdt, numbit\n',
        '  use variables, only: h, theta, pond, gwl, hm1, thetm1, pondm1, gwlm1, dt, swbotb, &\n'
        '       maxit, maxbacktr, swkimpl, swkmean, dtmin, CritDevBalCp, CritDevBalTot, &\n'
        '       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, fldecdt, numbit, &\n'
        '       hbot, gwlinp, dtold, itnumb, k, kmean, dimoca, fllowgwl, runots\n',
        'adapter compatibility state imports',
    )
    text = replace_exact(
        text,
        '     subroutine headcalc(worker, fsi_workspace, history)\n'
        '       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n'
        '       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n'
        '       type(a23bu_worker_context_t), intent(inout), optional :: worker\n'
        '       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n'
        '       type(a23bu_solver_history_t), target, intent(inout), optional :: history\n'
        '     end subroutine headcalc',
        '     subroutine headcalc(worker, fsi_workspace, history, state_binding)\n'
        '       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n'
        '       use mod_reference_richards_workspace, only: reference_richards_workspace_t\n'
        '       use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n'
        '       type(a23bu_worker_context_t), intent(inout), optional :: worker\n'
        '       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n'
        '       type(a23bu_solver_history_t), target, intent(inout), optional :: history\n'
        '       type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n'
        '     end subroutine headcalc',
        'adapter HeadCalc interface',
    )
    text = replace_exact(
        text,
        '    request%boundary%top_mode = FSI_LEGACY_TOP_CONTEXT\n    request%boundary%bottom_mode = swbotb\n',
        '    request%boundary%top_mode = FSI_LEGACY_TOP_CONTEXT\n'
        '    request%boundary%bottom_mode = swbotb\n'
        '    request%boundary%top_flux = qtop\n'
        '    request%boundary%bottom_flux = qbot\n'
        '    request%boundary%bottom_head = hbot\n',
        'adapter request boundary values',
    )

    start = text.find('    logical :: ok\n    type(a23bu_solver_history_t) :: call_history\n')
    stop = text.find('\n\n    if (self%reserved /= 0)', start)
    if start < 0 or stop < 0:
        raise SystemExit('F-SI07_MATERIALIZE FAIL adapter declaration block')
    text = text[:start] + (
        '    logical :: ok\n'
        '    type(a23bu_solver_history_t) :: call_history\n'
        '    type(reference_richards_state_binding_t) :: state_binding'
    ) + text[stop:]

    start = text.find('       allocate(h_saved(numnod), theta_saved(numnod), hm1_saved(numnod), thetm1_saved(numnod))')
    call_marker = '       call headcalc(ws%legacy_worker, ws%richards, call_history)'
    stop = text.find(call_marker, start)
    if start < 0 or stop < 0:
        raise SystemExit('F-SI07_MATERIALIZE FAIL adapter global overlay block')
    replacement = '''       call initialize_reference_state_binding(state_binding, request)
       state_binding%gwlinp = gwlinp
       state_binding%dtold = dtold
       state_binding%hbot = hbot
       state_binding%itnumb = itnumb
       state_binding%k = k(1:numnod)
       state_binding%kmean = kmean(1:numnod+1)
       state_binding%dimoca = dimoca(1:numnod)
       state_binding%fllowgwl = fllowgwl
       state_binding%q0 = q0
       state_binding%hsurf = hsurf
       state_binding%runots = runots
       state_binding%flrunoff = flrunoff
       state_binding%ftoph = ftoph

       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding)'''
    text = text[:start] + replacement + text[stop + len(call_marker):]

    replacements = {
        'result%candidate_state%pressure_head = h(1:numnod)': 'result%candidate_state%pressure_head = state_binding%h',
        'result%candidate_state%water_content = theta(1:numnod)': 'result%candidate_state%water_content = state_binding%theta',
        'result%candidate_state%ponding_depth = pond': 'result%candidate_state%ponding_depth = state_binding%pond',
        'result%candidate_state%groundwater_level = gwl': 'result%candidate_state%groundwater_level = state_binding%gwl',
        'result%top_flux = qtop': 'result%top_flux = state_binding%qtop',
        'result%bottom_flux = qbot': 'result%bottom_flux = state_binding%qbot',
        'if (fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then':
            'if (state_binding%fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then',
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new, f'adapter result mapping {old}')

    restore_start = text.find('       h(1:numnod) = h_saved')
    class_marker = '    class default\n'
    restore_stop = text.find(class_marker, restore_start)
    if restore_start < 0 or restore_stop < 0:
        raise SystemExit('F-SI07_MATERIALIZE FAIL adapter restore block')
    text = text[:restore_start] + text[restore_stop:]

    solve_start = text.find('  subroutine reference_richards_legacy_solve')
    solve_stop = text.find('  end subroutine reference_richards_legacy_solve', solve_start)
    solve = text[solve_start:solve_stop]
    forbidden = [
        r'(?m)^\s*h\s*\(', r'(?m)^\s*theta\s*\(', r'(?m)^\s*hm1\s*\(', r'(?m)^\s*thetm1\s*\(',
        r'(?m)^\s*pond\s*=', r'(?m)^\s*gwl\s*=', r'(?m)^\s*pondm1\s*=', r'(?m)^\s*gwlm1\s*=',
        r'(?m)^\s*qtop\s*=', r'(?m)^\s*qbot\s*=', r'(?m)^\s*fldecdt\s*=', r'(?m)^\s*numbit\s*=',
    ]
    for pat in forbidden:
        if re.search(pat, solve):
            raise SystemExit(f'F-SI07_MATERIALIZE FAIL adapter still writes shared solver state: {pat}')
    path.write_text(text)


def main() -> None:
    for path, expected in PINS.items():
        actual = git_blob_sha(path)
        if actual != expected:
            raise SystemExit(f'F-SI07_MATERIALIZE FAIL preimage {path}: {actual} != {expected}')
    transform_headcalc(Path('src/legacy/b1_10_port/headcalc.f90'))
    transform_soilwater(Path('src/legacy/b1_10_port/soilwater.f90'))
    transform_adapter(Path('src/adapter/mod_reference_richards_legacy_binding.f90'))
    print('F-SI07_MATERIALIZE PASS')
    print('solver_physics_change_intended=false')
    print('numerical_policy_change_intended=false')
    print('transaction_semantics_change_intended=false')
    print('full_real_parallel_admission=false')


if __name__ == '__main__':
    main()
