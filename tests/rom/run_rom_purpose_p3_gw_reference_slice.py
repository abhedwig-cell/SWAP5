#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
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

def run(cmd):
    subprocess.run(cmd,check=True)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--route",required=True,choices=tuple(ROUTES))
    ap.add_argument("--opt",required=True,type=int,choices=(0,2))
    ap.add_argument("--history",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()

    nodes,dz,factor=ROUTES[a.route]
    a.output_dir.mkdir(parents=True,exist_ok=True)
    target=a.canonical_root/"tests/rom/test_p3gw_slice.f90"
    manifest=a.output_dir/"manifest.json"

    run([
        sys.executable,"tests/rom/materialize_rom_purpose_p1_gw_reference_slice.py",
        "--base-materializer","tests/rom/materialize_rom_purpose_p3_gw_reference.py",
        "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py",
        "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
        "--source","tests/rom/rom_purpose_p1_gw_source.f90",
        "--material",a.material,"--temporal-factor",str(factor),
        "--history-index",str(a.history),
        "--output",str(target),"--manifest",str(manifest)
    ])

    stub=f"p3gwfix_{a.material}_{a.route}_o{a.opt}_h{a.history}_stubs.f90"
    run([
        sys.executable,str(a.canonical_root/"tests/rom/materialize_f_rom0_headcalc_stubs.py"),
        "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
        "--output",str(a.canonical_root/stub),
        "--nodes",str(nodes),"--dz-cm",str(dz)
    ])
    build=pathlib.Path(f"/tmp/p3gwfix_{a.material}_{a.route}_o{a.opt}_h{a.history}")
    run([
        sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
        "--root",str(a.canonical_root),"--stub",stub,
        "--target","tests/rom/test_p3gw_slice.f90",
        "--external-source","src/legacy/b1_10_port/headcalc.f90",
        "--build",str(build),"--opt",str(a.opt)
    ])

    hh=f"{a.history:02d}"
    log=a.output_dir/f"gw_{a.material}_{a.route}_o{a.opt}_h{hh}.txt"
    with log.open("w") as fh:
        cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT)
    if cp.returncode!=0:
        raise SystemExit(cp.returncode)

    text=log.read_text(errors="replace")
    if text.count("LAREGW1_STATE|")!=1024*factor:
        raise SystemExit("incomplete GW state trace")
    if text.count("LAREGW1_PROFILE|")!=1024*16:
        raise SystemExit("incomplete GW profile trace")
    if "LAREGW1_ROMPURP_P3_GW_REFERENCE_GENERATED=TRUE" not in text:
        raise SystemExit("P3 GW completion marker missing")
    if "LAREGW1_EXECUTION_COMPLETE=PASS" not in text:
        raise SystemExit("GW execution completion missing")

    meta={
        "schema":"swap5.rom-purpose.p3.gw-reference-slice-execution.v1",
        "material":a.material,"route":a.route,"optimization":a.opt,
        "history_index":a.history,"history_label":f"G{a.history+5:02d}",
        "nodes":nodes,"dz_cm":dz,"temporal_factor":factor,
        "scientific_partition":"ONE_INDEPENDENT_HISTORY_ONLY",
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
