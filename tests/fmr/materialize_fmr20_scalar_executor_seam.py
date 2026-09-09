#!/usr/bin/env python3
from pathlib import Path
import subprocess

SRC = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
EXPECTED = '7a60f8b8d18672098fed1c6890a95aac738ed21d'

def blob(path):
    return subprocess.check_output(['git','hash-object',str(path)], text=True).strip()

def once(text, old, new, label):
    n=text.count(old)
    if n != 1:
        raise SystemExit(f'FMR20_SCALAR_MATERIALIZE_FAIL {label}: expected 1 occurrence, found {n}')
    return text.replace(old,new,1)

actual=blob(SRC)
if actual != EXPECTED:
    raise SystemExit(f'FMR20_SCALAR_MATERIALIZE_FAIL preimage {actual} != {EXPECTED}')
print('FMR20_SCALAR_G01_PREIMAGE_LOCK=PASS')

s=SRC.read_text(encoding='utf-8')
s=once(s,
'  public :: fmr_run_serialized_physical_multiswap\n',
'  public :: fmr_run_serialized_physical_multiswap\n  public :: fmr_execute_serialized_physical_column\n',
'public scalar seam')
s=once(s,
'        call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &\n',
'        call fmr_execute_serialized_physical_column(backend, transaction_control, columns(idx), templates, parameter_registry, &\n',
'serialized caller uses public scalar seam')
s=once(s,
'  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n',
'  subroutine fmr_execute_serialized_physical_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n',
'rename scalar seam declaration')
s=once(s,
'    integer :: state_index, parameter_index, forcing_index, commit_status\n',
'    integer :: state_index, parameter_index, forcing_index, commit_status, simultaneous_physical_calls\n',
'concurrency snapshot local')
s=once(s,
'    active_physical_calls = active_physical_calls + 1\n    call backend%run_trial(column, templates(find_template_index(column%template_id, templates)), &\n',
'    !$omp atomic capture\n    active_physical_calls = active_physical_calls + 1\n    simultaneous_physical_calls = active_physical_calls\n    !$omp end atomic\n    call backend%run_trial(column, templates(find_template_index(column%template_id, templates)), &\n',
'atomic diagnostic increment')
s=once(s,
'        runtime%max_simultaneous_real_physical_solves, active_physical_calls)\n',
'        runtime%max_simultaneous_real_physical_solves, simultaneous_physical_calls)\n',
'use captured simultaneous count')
s=once(s,
'    active_physical_calls = active_physical_calls - 1\n',
'    !$omp atomic update\n    active_physical_calls = active_physical_calls - 1\n    !$omp end atomic\n',
'atomic diagnostic decrement')
s=once(s,
'  end subroutine execute_column\n',
'  end subroutine fmr_execute_serialized_physical_column\n',
'rename scalar seam end')

if 'subroutine execute_column' in s or 'call execute_column(' in s:
    raise SystemExit('FMR20_SCALAR_MATERIALIZE_FAIL old private seam remains')
if s.count('fmr_execute_serialized_physical_column') != 4:
    raise SystemExit(f'FMR20_SCALAR_MATERIALIZE_FAIL unexpected scalar seam count {s.count("fmr_execute_serialized_physical_column")}')
SRC.write_text(s,encoding='utf-8')
print('FMR20_SCALAR_G02_PUBLIC_SCALAR_EXECUTOR=PASS')
print('FMR20_SCALAR_G03_ATOMIC_DIAGNOSTIC_COUNTER=PASS')
print(f'FMR20_SCALAR_POSTIMAGE {blob(SRC)}')
