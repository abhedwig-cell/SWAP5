#!/usr/bin/env python3
from __future__ import annotations
import hashlib
from pathlib import Path

PINS = {
    Path('src/legacy/b1_10_port/headcalc.f90'): '3cd34bff45b57c38ef9b41f1b8b8f0865154f99d',
    Path('tools/fsi/fsi07_materialize_state_binding.py'): '36ecd6180d980c1cacfefaf8a42863f4a46b53b9',
}

def blob_sha(path: Path) -> str:
    b=path.read_bytes()
    return hashlib.sha1(f'blob {len(b)}\0'.encode()+b).hexdigest()

def one(text: str, old: str, new: str, label: str) -> str:
    n=text.count(old)
    if n != 1:
        raise SystemExit(f'F-SI07_NUMBIT_FIX FAIL {label}: expected 1 found {n}')
    return text.replace(old,new,1)

for path, expected in PINS.items():
    actual=blob_sha(path)
    if actual != expected:
        raise SystemExit(f'F-SI07_NUMBIT_FIX FAIL preimage {path}: {actual} != {expected}')

head=Path('src/legacy/b1_10_port/headcalc.f90')
s=head.read_text()
s=one(s,
      '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror\n',
      '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit\n',
      'HeadCalc loop carrier declaration')
s=one(s,
      '   do st%numbit = 1, MaxIt1\n',
      '   do solver_numbit = 1, MaxIt1\n      st%numbit = solver_numbit\n',
      'HeadCalc loop carrier')
head.write_text(s)

mat=Path('tools/fsi/fsi07_materialize_state_binding.py')
m=mat.read_text()
needle='''    s = one(s,\n        "   type(a23bu_solver_history_t), target :: local_history\\n   type(a23bu_solver_history_t), pointer :: hist\\n!  local\\n",\n'''
if needle not in m:
    raise SystemExit('F-SI07_NUMBIT_FIX FAIL materializer insertion anchor')
insert='''    s = one(s,\n        "   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror\\n",\n        "   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit\\n",\n        "solver numbit carrier declaration")\n'''
m=m.replace(needle, insert+needle,1)
needle2='''    for name in fields:\n        body = re.sub(rf"(?<![%A-Za-z0-9_]){name}(?![A-Za-z0-9_])", f"st%{name}", body, flags=re.IGNORECASE)\n\n'''
if needle2 not in m:
    raise SystemExit('F-SI07_NUMBIT_FIX FAIL materializer loop anchor')
insert2='''    for name in fields:\n        body = re.sub(rf"(?<![%A-Za-z0-9_]){name}(?![A-Za-z0-9_])", f"st%{name}", body, flags=re.IGNORECASE)\n    body = one(body,\n        "   do st%numbit = 1, MaxIt1\\n",\n        "   do solver_numbit = 1, MaxIt1\\n      st%numbit = solver_numbit\\n",\n        "solver numbit carrier")\n\n'''
m=m.replace(needle2,insert2,1)
mat.write_text(m)

print('F-SI07_NUMBIT_FIX PASS')
print('solver_equation_change=false')
print('numerical_policy_change=false')
