#!/usr/bin/env python3
"""Contract tests for F-MACRO-TRACER01-A."""
from pathlib import Path
import importlib.util
import math
import sys

HERE = Path(__file__).resolve().parent
PATH = HERE / 'macropore_tracer01_matrix_reference.py'
spec = importlib.util.spec_from_file_location('tracer01', PATH)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

def close(a,b,tol=1e-12):
    return abs(a-b) <= tol * max(1.0,abs(a),abs(b))

s = m.TracerState((0.3,0.2),generation=4)
r = m.evaluate_trial(s,(1.0,2.0),(1.0,2.0),())
assert r.valid and r.candidate.mass == s.mass and r.candidate.generation == 5

s = m.TracerState((0.4,0.0))
r = m.evaluate_trial(s,(1.0,1.0),(0.75,1.25),(m.WaterTransfer(0.25,0,1,label='down'),))
assert r.valid and close(sum(r.candidate.mass),0.4)
assert close(r.candidate.mass[0],0.3) and close(r.candidate.mass[1],0.1)

s = m.TracerState((0.0,))
r = m.evaluate_trial(s,(1.0,),(1.2,),(m.WaterTransfer(0.2,None,0,external_concentration=3.0),))
assert r.valid and close(r.external_input_mass,0.6) and close(r.candidate.mass[0],0.6)

s = m.TracerState((0.5,))
r = m.evaluate_trial(s,(1.0,),(0.8,),(m.WaterTransfer(0.2,0,None),))
assert r.valid and close(r.external_output_mass,0.1) and close(r.candidate.mass[0],0.4)

s = m.TracerState((0.5,))
r = m.evaluate_trial(s,(1.0,),(0.7,),(m.WaterTransfer(0.2,0,None),))
assert not r.valid and r.candidate is None and 'hydrology owner' in r.reason and s.mass == (0.5,)

s = m.TracerState((0.5,))
r = m.evaluate_trial(s,(1.0,),(0.0,),(m.WaterTransfer(1.1,0,None),))
assert not r.valid and 'exceeds donor storage' in r.reason

bad = m.TracerState((math.nan,))
r = m.evaluate_trial(bad,(1.0,),(1.0,),())
assert not r.valid

s = m.TracerState((0.4,0.0))
ev = (m.WaterTransfer(0.25,0,1),)
r1 = m.evaluate_trial(s,(1.0,1.0),(0.75,1.25),ev)
r2 = m.evaluate_trial(s,(1.0,1.0),(0.75,1.25),ev)
assert r1 == r2

s = m.TracerState((0.4,0.0),generation=9)
before = s
bad = m.evaluate_trial(s,(1.0,1.0),(1.0,1.0),(m.WaterTransfer(0.25,0,1),))
assert not bad.valid and s == before

good = m.evaluate_trial(s,(1.0,1.0),(0.75,1.25),(m.WaterTransfer(0.25,0,1),))
new = m.commit_trial(s,good)
assert new == good.candidate and new.generation == 10
assert s.generation == 9 and s.mass == (0.4,0.0)

print('PASS F-MACRO-TRACER01-A reference-kernel contract')
