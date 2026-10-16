#!/usr/bin/env python3
"""Fresh admitted daily-density receiving drivers against the joint source tree.

Retain every native assertion, flag, fixture, restart and optimization check in
those two owners. Other already admitted root cases remain immutable evidence.
"""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'tests/root-growth/run_swrd2_cycle.py'
s=p.read_text()
anchor="    oxygen_oracle(ROOT,fixture/'oxygen_oracle.f90');co2_oracle(ROOT,fixture/'co2_oracle.f90')"
assert s.count(anchor)==2
# Insert into the replacement controller, after density and density_supply exist.
needle='    inputs[\'tests/root-growth/density_cycle_driver.py\']=sha(ROOT/\'tests/root-growth/density_cycle_driver.py\')\\n"+anchor)'
assert s.count(needle)==1
s=s.replace(needle,'    inputs[\'tests/root-growth/density_cycle_driver.py\']=sha(ROOT/\'tests/root-growth/density_cycle_driver.py\')\\n    drivers={k:drivers[k] for k in (\'density\',\'density_supply\')}\\n"+anchor)')
sys.argv.append('--density')
exec(compile(s,str(p),'exec'),{'__file__':str(p),'__name__':'__main__'})
