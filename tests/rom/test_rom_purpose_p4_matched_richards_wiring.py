#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import pathlib
import sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

matched=load("p4_matched_wiring_under_test",HERE/"analyze_rom_purpose_p4_matched_richards.py")
runner=load("p4_candidate_runner_helper_authority",HERE/"run_rom_purpose_p4_candidate.py")

PARTS={
 "S8":[0.0,10.0,20.0,30.0,40.0,50.0,60.0,80.0,160.0],
 "S12":[0.0,5.0,10.0,20.0,30.0,40.0,50.0,60.0,70.0,80.0,100.0,120.0,160.0],
 "S16":[0.0,5.0,10.0,15.0,20.0,25.0,30.0,35.0,40.0,50.0,60.0,70.0,80.0,100.0,120.0,140.0,160.0],
}
for name,bounds in PARTS.items():
    dz=np.diff(np.asarray(bounds,float))
    theta=np.linspace(0.11,0.37,len(dz))
    storage=theta*dz
    for lo,hi in ((0.0,20.0),(0.0,40.0),(0.0,80.0)):
        a=matched.integrated_storage(storage,bounds,lo,hi)
        b=runner.integrated_storage(storage,bounds,lo,hi)
        assert a==b,(name,lo,hi,a,b)
    a=matched.map_piecewise_to_10cm(storage,bounds)
    b=runner.map_piecewise_to_10cm(storage,bounds)
    assert a==b,(name,a,b)

src=(HERE/"analyze_rom_purpose_p4_matched_richards.py").read_text()
assert "p4.p3.base.integrated_storage" not in src
assert "p4.p3.base.map_piecewise_to_10cm" not in src
print("ROM_PURPOSE_P4_MATCHED_RICHARDS_WIRING=PASS")
