from __future__ import annotations

import ctypes
import os
import shutil
import sys
import tempfile
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
RIBASIM_ROOT=Path(os.environ["RM13_RIBASIM_ROOT"]).resolve()
sys.path.insert(0,str(RIBASIM_ROOT/"python"/"ribasim_api"))
from ribasim_api import RibasimApi

MODEL=Path(os.environ["RM13_RIBASIM_MODEL"]).resolve()
LIB=Path(os.environ["RM13_LIBRIBASIM"]).resolve()
WINDOW_S=8.64
TOL=1e-12

def require(x:bool,msg:str)->None:
    if not x:
        raise AssertionError(msg)

def preload_runtime()->Path:
    candidates=sorted(LIB.parent.parent.rglob("libjulia.so.1.12"))
    require(len(candidates)==1,f"expected one libjulia.so.1.12, got {candidates}")
    ctypes.CDLL(str(candidates[0]),mode=ctypes.RTLD_GLOBAL)
    return candidates[0]

def api_copy(tag:str,root:Path)->RibasimApi:
    d=root/tag
    d.mkdir()
    for entry in LIB.parent.iterdir():
        dst=d/entry.name
        if entry.resolve()==LIB.resolve():
            shutil.copy2(entry,dst)
        else:
            dst.symlink_to(entry)
    return RibasimApi(d/LIB.name,d)

def snap(api:RibasimApi):
    return (
        float(api.get_current_time()),
        float(np.asarray(api.get_value_ptr("basin.level"),dtype=float)[0]),
        float(np.asarray(api.get_value_ptr("user_demand.cumulative_inflow"),dtype=float)[0]),
    )

runtime=preload_runtime()
print(f"RM13_RIBASIM_SMOKE_RUNTIME={runtime}")

with tempfile.TemporaryDirectory(prefix="rm13-ribasim-smoke-") as tmp:
    root=Path(tmp)
    accepted=api_copy("accepted",root)
    a=api_copy("a",root)
    b=api_copy("b",root)

    accepted.initialize(str(MODEL))
    origin=snap(accepted)

    a.initialize(str(MODEL))
    a.update_until(WINDOW_S)
    sa=snap(a)
    a.finalize()
    require(snap(accepted)==origin,"candidate A mutated accepted witness")

    b.initialize(str(MODEL))
    b.update_until(WINDOW_S)
    sb=snap(b)
    require(abs(sa[0]-sb[0])<=TOL,"time replay")
    require(abs(sa[1]-sb[1])<=TOL,"level replay")
    require(abs(sa[2]-sb[2])<=TOL,"supply replay")
    require(snap(accepted)==origin,"candidate B mutated accepted witness")
    b.finalize()
    accepted.finalize()

print(f"RM13_RIBASIM_SMOKE_ORIGIN={origin}")
print(f"RM13_RIBASIM_SMOKE_CANDIDATE={sa}")
print("RM13_RIBASIM_RELEASE_LOADER=PASS")
print("RM13_RIBASIM_THREE_INSTANCE_ISOLATION=PASS")
