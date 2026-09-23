#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

TERMINAL={
    "SURF_P":{"member":"S8","thickness":"10,10,10,10,10,10,20,80","state_prefix":"LAREDYN0R_STATE|","node_prefix":"ROMPURP_P1_COARSE_NODE|PURPOSE=surface|","marker":"LAREDYN0R_ROMPURP_P3_SURFACE_REFERENCE_GENERATED=TRUE"},
    "GW_LB":{"member":"G8","thickness":"80,20,20,10,10,10,5,5","state_prefix":"LAREGW1_STATE|","node_prefix":"ROMPURP_P1_COARSE_NODE|PURPOSE=gw|","marker":"LAREGW1_ROMPURP_P3_GW_REFERENCE_GENERATED=TRUE"},
}

def run(cmd,**kwargs):
    return subprocess.run(cmd,check=True,**kwargs)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--state-count-result",required=True,type=pathlib.Path)
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()

    a.output_dir.mkdir(parents=True,exist_ok=True)
    state=json.loads(a.state_count_result.read_text())
    trigger=next((x for x in state["same_partition_richards_triggers"]
                  if x["purpose"]==a.purpose and x["material"]==a.material),None)
    status_path=a.output_dir/f"execution_{a.purpose}_{a.material}_T{a.factor}.json"
    if trigger is None:
        status={
            "schema":"swap5.rom-purpose.p3.same-partition-route-execution.v1",
            "purpose":a.purpose,"material":a.material,"temporal_factor":a.factor,
            "triggered":False,"return_code_o0":-1,"return_code_o2":-1,
            "scientific_trace_identity":False,"trace_complete":False,
            "scientific_change":False,"reason":"NOT_TRIGGERED_BY_STATE_COUNT_RESULT"
        }
        status_path.write_text(json.dumps(status,indent=2,sort_keys=True)+"\n")
        return 0

    terminal=TERMINAL[a.purpose]
    if trigger["member"]!=terminal["member"]:
        raise SystemExit("trigger is not terminal aligned representation")

    generated=a.canonical_root/"tests/rom/test_p3same.f90"
    manifest=a.output_dir/"materialization.json"
    cmd=[
        sys.executable,"tests/rom/materialize_rom_purpose_p3_same_partition_richards.py",
        "--purpose",a.purpose,"--material",a.material,"--temporal-factor",str(a.factor),
        "--representation-ladder",str(a.representation_ladder),
        "--coarse-output-adapter","tests/rom/materialize_rom_purpose_p1_coarse_output.py",
        "--output",str(generated),"--manifest",str(manifest)
    ]
    if a.purpose=="SURF_P":
        source=("tests/rom/rom_purpose_p1_surface_b01_source.f90"
                if a.material=="B01" else "tests/rom/rom_purpose_p1_surface_b14_source.f90")
        cmd += ["--source",source,
                "--surface-materializer","tests/rom/materialize_rom_purpose_p3_surface_reference.py"]
    else:
        cmd += ["--source","tests/rom/rom_purpose_p1_gw_source.f90",
                "--gw-materializer","tests/rom/materialize_rom_purpose_p3_gw_reference.py",
                "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
                "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py"]
    run(cmd)

    rcs={}
    logs={}
    for opt in (0,2):
        stub=f"p3same_{a.purpose}_{a.material}_T{a.factor}_o{opt}_stubs.f90"
        run([
            sys.executable,"tests/rom/rom_purpose_p1_variable_grid_stubs.py",
            "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
            "--output",str(a.canonical_root/stub),
            "--layer-thickness-cm",terminal["thickness"]
        ])
        build=pathlib.Path(f"/tmp/p3same_{a.purpose}_{a.material}_T{a.factor}_o{opt}")
        run([
            sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
            "--root",str(a.canonical_root),"--stub",stub,
            "--target","tests/rom/test_p3same.f90",
            "--external-source","src/legacy/b1_10_port/headcalc.f90",
            "--build",str(build),"--opt",str(opt)
        ])
        log=a.output_dir/f"richards_{a.purpose}_{a.material}_T{a.factor}_o{opt}.txt"
        with log.open("w") as fh:
            cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT)
        rcs[opt]=cp.returncode
        logs[opt]=log

    identity=rcs[0]==0 and rcs[2]==0 and logs[0].read_bytes()==logs[2].read_bytes()
    complete=False
    if rcs[0]==0 and rcs[2]==0:
        text=logs[0].read_text(errors="replace")
        complete=(
            terminal["marker"] in text and
            "EXECUTION_COMPLETE=PASS" in text and
            text.count(terminal["state_prefix"])==4*1024*a.factor and
            text.count(terminal["node_prefix"])==4*1024*8
        )

    status={
        "schema":"swap5.rom-purpose.p3.same-partition-route-execution.v1",
        "purpose":a.purpose,"material":a.material,"temporal_factor":a.factor,
        "triggered":True,
        "return_code_o0":int(rcs[0]),"return_code_o2":int(rcs[2]),
        "scientific_trace_identity":bool(identity),
        "trace_complete":bool(complete),
        "scientific_change":False
    }
    status_path.write_text(json.dumps(status,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
