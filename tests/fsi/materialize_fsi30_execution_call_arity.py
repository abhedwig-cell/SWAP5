#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path('tests/fsi/test_fsi30_dynamic_headcalc_execution.f90')
EXPECTED_BLOB = '2c65b236a0a9dddd1cb173a21aa3a11cabb4306b'
actual = subprocess.check_output(['git','hash-object',str(PATH)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f'F-SI30 execution driver source lock failed: expected {EXPECTED_BLOB}, got {actual}')
text = PATH.read_text()
old10 = '       0.0_real64, 0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, &'
new10 = '       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, &'
if text.count(old10) != 3:
    raise SystemExit(f'expected three pondmax=10 arity anchors, found {text.count(old10)}')
text = text.replace(old10,new10)
old01 = '       0.0_real64, 0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, &'
new01 = '       0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, &'
if text.count(old01) != 1:
    raise SystemExit(f'expected one runoff arity anchor, found {text.count(old01)}')
text = text.replace(old01,new01)
PATH.write_text(text)
print('FSI30_EXECUTION_CALL_ARITY_REPAIRED=YES')
print('FSI30_EXECUTION_DRIVER_OUTPUT_BLOB=' + subprocess.check_output(['git','hash-object',str(PATH)], text=True).strip())
