#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys

ROUTES={
    "R512_T32":(512,0.3125,32),
    "R1024_T32":(1024,0.15625,32),
    "R2048_T32":(2048,0.078125,32),
    "R2048_T16":(2048,0.078125,16),
    "R2048_T8":(2048,0.078125,8),
}

def run(cmd, env=None):
    subprocess.run(cmd,check=True,env=env)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--route",required=True,choices=tuple(ROUTES))
    ap.add_argument("--opt",required=True,type=int,choices=(0,2))
    ap.add_argument("--history",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--segment",required=True,type=int,choices=(1,2))
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    ap.add_argument("--checkpoint-in",type=pathlib.Path)
    a=ap.parse_args()

    nodes,dz,factor=ROUTES[a.route]
    total=1024*factor
    half=512*factor
    start,end=(1,half) if a.segment==1 else (half+1,total)
    if a.segment==2 and a.checkpoint_in is None:
        raise SystemExit("--checkpoint-in required for segment 2")

    a.output_dir.mkdir(parents=True,exist_ok=True)
    target=a.canonical_root/"tests/rom/test_p3gw_segment.f90"
    manifest=a.output_dir/"manifest.json"

    run([
        sys.executable,"tests/rom/materialize_rom_purpose_p1_gw_reference_segment.py",
        "--slice-materializer","tests/rom/materialize_rom_purpose_p1_gw_reference_slice.py",
        "--base-materializer","tests/rom/materialize_rom_purpose_p3_gw_reference.py",
        "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py",
        "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
        "--source","tests/rom/rom_purpose_p1_gw_source.f90",
        "--material",a.material,
        "--temporal-factor",str(factor),
        "--history-index",str(a.history),
        "--segment-start",str(start),
        "--segment-end",str(end),
        "--output",str(target),
        "--manifest",str(manifest),
    ])

    stub=f"p3gwseg_{a.material}_{a.route}_o{a.opt}_h{a.history}_s{a.segment}_stubs.f90"
    run([
        sys.executable,str(a.canonical_root/"tests/rom/materialize_f_rom0_headcalc_stubs.py"),
        "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
        "--output",str(a.canonical_root/stub),
        "--nodes",str(nodes),"--dz-cm",str(dz)
    ])
    build=pathlib.Path(f"/tmp/p3gwseg_{a.material}_{a.route}_o{a.opt}_h{a.history}_s{a.segment}")
    run([
        sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
        "--root",str(a.canonical_root),
        "--stub",stub,
        "--target","tests/rom/test_p3gw_segment.f90",
        "--external-source","src/legacy/b1_10_port/headcalc.f90",
        "--build",str(build),
        "--opt",str(a.opt)
    ])

    checkpoint_out=a.output_dir/"checkpoint.bin"
    env=os.environ.copy()
    env["ROMPURP_P1_CHECKPOINT_OUT"]=str(checkpoint_out)
    if a.segment==2:
        env["ROMPURP_P1_CHECKPOINT_IN"]=str(a.checkpoint_in)

    log=a.output_dir/f"segment{a.segment}.txt"
    with log.open("w") as fh:
        cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT,env=env)
    if cp.returncode!=0:
        raise SystemExit(cp.returncode)

    text=log.read_text(errors="replace")
    expected_states=end-start+1
    expected_profiles=512*16
    if text.count("LAREGW1_STATE|")!=expected_states:
        raise SystemExit(f"incomplete segment state trace: {text.count('LAREGW1_STATE|')} != {expected_states}")
    if text.count("LAREGW1_PROFILE|")!=expected_profiles:
        raise SystemExit(f"incomplete segment profile trace: {text.count('LAREGW1_PROFILE|')} != {expected_profiles}")
    if "LAREGW1_ROMPURP_P3_GW_REFERENCE_GENERATED=TRUE" not in text:
        raise SystemExit("P3 GW marker missing")
    if "LAREGW1_ROMPURP_P1_SEGMENTED_GW_REFERENCE_GENERATED=TRUE" not in text:
        raise SystemExit("segmented GW marker missing")
    if not checkpoint_out.exists() or checkpoint_out.stat().st_size==0:
        raise SystemExit("checkpoint missing")

    meta={
        "schema":"swap5.rom-purpose.p3.gw-reference-half-segment-execution.v1",
        "material":a.material,"route":a.route,"optimization":a.opt,
        "history_index":a.history,"segment":a.segment,
        "segment_start":start,"segment_end":end,
        "temporal_factor":factor,"nodes":nodes,"dz_cm":dz,
        "checkpoint_continuation":a.segment==2,
        "history_state_continuity_changed":False,
        "solver_or_physics_changed":False,
        "forcing_changed":False,
        "numerical_policy_changed":False,
        "response_based_repair":False
    }
    (a.output_dir/"execution.json").write_text(json.dumps(meta,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
