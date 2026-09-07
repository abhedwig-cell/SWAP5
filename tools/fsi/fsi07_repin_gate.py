#!/usr/bin/env python3
from pathlib import Path

GATE = Path('tests/fsi/run_fsi07_gate.sh')
s = GATE.read_text()
old = "[[ \"$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)\" == \"1701d9e9410db206dfe28e42a6ad87d02bc2f432\" ]] || { echo 'F-SI07_PIN FAIL HeadCalc' >&2; exit 1; }"
new = "[[ \"$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)\" == \"4d1a723bb4948cc611cf15df47366c968be90ebf\" ]] || { echo 'F-SI07_PIN FAIL HeadCalc' >&2; exit 1; }"
if s.count(old) != 1:
    raise SystemExit(f'F-SI07_REPIN FAIL old HeadCalc pin count={s.count(old)}')
s = s.replace(old, new, 1)
needle = "grep -Fq 'state => state_binding' \"$HEADCALC\"\n"
insert = needle + "grep -Fq 'do solver_numbit = 1, MaxIt1' \"$HEADCALC\"\n! grep -Fq 'do state%numbit = 1, MaxIt1' \"$HEADCALC\"\n"
if s.count(needle) != 1:
    raise SystemExit('F-SI07_REPIN FAIL structural insertion point')
s = s.replace(needle, insert, 1)
GATE.write_text(s)
print('F-SI07_REPIN_GATE MATERIALIZED')
