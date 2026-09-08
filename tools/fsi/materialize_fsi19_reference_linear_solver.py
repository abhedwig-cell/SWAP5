#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT / 'src/solver/mod_reference_richards_workspace.f90'
HEADCALC = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
EXPECTED = {
    WORKSPACE: 'a09ba3457a8ce3685df446bfacbf5220cd401507',
    HEADCALC: 'd92f77963329d61ab3feb988f912252c0161436c',
}


def blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], cwd=ROOT, text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI19 materializer: {label} expected once, found {count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED.items():
    actual = blob(path)
    if actual != expected:
        raise SystemExit(f'F-SI19 preimage mismatch {path.relative_to(ROOT)} {actual} != {expected}')

w = WORKSPACE.read_text(encoding='utf-8')
w = replace_once(w,
    '     real(real64), allocatable :: delta_head(:)\n',
    '     real(real64), allocatable :: delta_head(:)\n     real(real64), allocatable :: tridag_gamma(:)\n',
    'workspace declaration')
w = replace_once(w,
    '       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes))\n',
    '       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))\n',
    'workspace allocation')
w = replace_once(w,
    '    workspace%delta_head = 0.0_real64\n',
    '    workspace%delta_head = 0.0_real64\n    workspace%tridag_gamma = 0.0_real64\n',
    'workspace reset')
w = replace_once(w,
    '    workspace%delta_head = qnan\n',
    '    workspace%delta_head = qnan\n    workspace%tridag_gamma = qnan\n',
    'workspace poison')
w = replace_once(w,
    '    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n',
    '    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n    if (allocated(workspace%tridag_gamma)) deallocate(workspace%tridag_gamma)\n',
    'workspace release')
w = replace_once(w,
    '    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n',
    '    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n    if (allocated(workspace%tridag_gamma)) nreal = nreal + size(workspace%tridag_gamma, kind=int64)\n',
    'workspace accounting')
WORKSPACE.write_text(w, encoding='utf-8')

h = HEADCALC.read_text(encoding='utf-8')
h = replace_once(h,
    '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n',
    '   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n'
    '   use mod_reference_linear_solver, only: reference_tridag, reference_band_solve\n',
    'HeadCalc solver import')
h = replace_once(h,
    '   use MOD_arrays,         only: macp, mabbc\n',
    '   use MOD_arrays,         only: mabbc\n',
    'HeadCalc macp import')
pattern = re.compile(r'(?m)^(\s*)call tridag\(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, fsi_ws%residual, fsi_ws%delta_head, ierror\)$')
m = pattern.search(h)
if not m:
    raise SystemExit('F-SI19 materializer: HeadCalc TRIDAG call not found exactly once')
if len(pattern.findall(h)) != 1:
    raise SystemExit('F-SI19 materializer: HeadCalc TRIDAG call not unique')
indent = m.group(1)
h = pattern.sub(
    indent + 'call reference_tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, &\n' +
    indent + '     fsi_ws%residual, fsi_ws%delta_head, fsi_ws%tridag_gamma, ierror)', h, count=1)
h = replace_once(h,
    '   real(8)                    :: d\n',
    '',
    'alternative solver obsolete d')
old = '''   call bandec(fsi_ws%band_matrix, NN, 1, 1, macp, 3, fsi_ws%band_aux, 1, fsi_ws%band_pivots, d)\n   fsi_ws%band_rhs(1:NN) = fsi_ws%residual(1:NN)\n   call banbks(fsi_ws%band_matrix,nn,1,1,macp,3,fsi_ws%band_aux,1,fsi_ws%band_pivots,fsi_ws%band_rhs)\n'''
new = '''   fsi_ws%band_rhs(1:NN) = fsi_ws%residual(1:NN)\n   call reference_band_solve(fsi_ws%band_matrix, fsi_ws%band_aux, fsi_ws%band_pivots(1:NN), &\n        fsi_ws%band_rhs(1:NN))\n'''
h = replace_once(h, old, new, 'HeadCalc band fallback calls')
for forbidden in ('call tridag(', 'call bandec(', 'call banbks(', 'only: macp, mabbc'):
    if forbidden.lower() in h.lower():
        raise SystemExit(f'F-SI19 materializer: forbidden legacy linear-solver dependency remains: {forbidden}')
HEADCALC.write_text(h, encoding='utf-8')

print('F-SI19_MATERIALIZER PASS')
print('changed src/solver/mod_reference_richards_workspace.f90')
print('changed src/legacy/b1_10_port/headcalc.f90')
