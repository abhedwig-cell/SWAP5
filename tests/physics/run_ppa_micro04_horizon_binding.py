#!/usr/bin/env python3
"""Check the B1.11 horizon representative table selection at O0 and O2."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
SOURCES=[
    "src/solver/mod_soil_water_solver_contract.f90",
    "src/solver/mod_b110_default_mvg_provider.f90",
    "src/process/mod_root_micro_matric_flux_table.f90",
    "src/runtime/mod_fmr_micro_mvg_table_binding.f90",
    "tests/physics/test_ppa_micro04_horizon_binding.f90",
]
outputs={}
with tempfile.TemporaryDirectory(prefix="ppa-micro04-") as tmp:
    for opt in ("O0","O2"):
        build=pathlib.Path(tmp)/opt
        build.mkdir()
        exe=build/"test"
        subprocess.run(["gfortran", "-"+opt,"-std=f2008","-ffree-line-length-none",
                        "-fcheck=all","-ffpe-trap=invalid,zero,overflow",
                        "-J"+str(build),"-I"+str(build),
                        *(str(ROOT/p) for p in SOURCES),"-o",str(exe)],cwd=build,check=True)
        outputs[opt]=subprocess.check_output([str(exe)],text=True,cwd=build)
        print(outputs[opt],end="",flush=True)
assert outputs["O0"]==outputs["O2"]
result=os.environ.get("MICRO04_RESULT")
if result:
    paths=[*SOURCES,"tests/physics/run_ppa_micro04_horizon_binding.py"]
    pathlib.Path(result).write_text(json.dumps({
        "work_unit":"PPA-MICRO04", "status":"STANDALONE_O0_O2_MAP_PASS",
        "source_sha256":{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
        "outputs":outputs,
        "claim_ceiling":"Horizon first-node table selection only; no B1.11 MvG equivalence or heterogeneous production admission"
    },indent=2)+"\n")
print("MICRO04_O0_O2_HORIZON_SELECTION=PASS")
