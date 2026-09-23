#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

TERMINAL={
    "SURF_P":{"member":"S8","boundaries_cm":[0.0,10.0,20.0,30.0,40.0,50.0,60.0,80.0,160.0]},
    "GW_LB":{"member":"G8","boundaries_cm":[0.0,80.0,100.0,120.0,130.0,140.0,150.0,155.0,160.0]},
}

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--surface-materializer",type=pathlib.Path)
    ap.add_argument("--gw-materializer",type=pathlib.Path)
    ap.add_argument("--c5a-materializer",type=pathlib.Path)
    ap.add_argument("--c4z-materializer",type=pathlib.Path)
    ap.add_argument("--coarse-output-adapter",required=True,type=pathlib.Path)
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    ladder=json.loads(a.representation_ladder.read_text())
    terminal=TERMINAL[a.purpose]
    family=ladder[a.purpose]["family"]
    frozen=family[terminal["member"]]["boundaries_cm"]
    if [float(x) for x in frozen]!=terminal["boundaries_cm"]:
        raise SystemExit("terminal partition differs from frozen P3 representation ladder")

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"base.f90"
        bm=td/"base.json"
        if a.purpose=="SURF_P":
            if a.surface_materializer is None:
                raise SystemExit("--surface-materializer required")
            subprocess.run([
                sys.executable,str(a.surface_materializer),
                "--source",str(a.source),"--material",a.material,
                "--temporal-factor",str(a.temporal_factor),
                "--output",str(base),"--manifest",str(bm)
            ],check=True)
            text=base.read_text()
            text=replace_one(
                text,
                "call require(mod(numnod,16)==0,'LAREDYN0R ROMPURP_P3_SURFACE geometry divisible by 16')",
                "call require(mod(numnod,16)==0,'LAREDYN0R ROMPURP_P1_SURFACE geometry divisible by 16')",
                "surface coarse-output adapter guard-label bridge"
            )
            base.write_text(text)
            purpose_arg="surface"
        else:
            if None in (a.gw_materializer,a.c5a_materializer,a.c4z_materializer):
                raise SystemExit("GW materializer dependencies required")
            subprocess.run([
                sys.executable,str(a.gw_materializer),
                "--c5a-materializer",str(a.c5a_materializer),
                "--c4z-materializer",str(a.c4z_materializer),
                "--source",str(a.source),"--material",a.material,
                "--temporal-factor",str(a.temporal_factor),
                "--output",str(base),"--manifest",str(bm)
            ],check=True)
            text=base.read_text()
            text=replace_one(
                text,
                "call require(any(numnod==[512,1024,2048]),'LAREGW1 ROMPURP_P3_GW geometry is R512/R1024/R2048')",
                "call require(numnod==8,'LAREGW1 ROMPURP_P3_SAME_PARTITION geometry is exact terminal eight-cell partition')",
                "terminal eight-cell GW geometry guard"
            )
            base.write_text(text)
            purpose_arg="gw"

        base_manifest=json.loads(bm.read_text())
        if base_manifest.get("response_based") is not False:
            raise SystemExit("base materializer must be response-independent")

        cm=td/"coarse.json"
        subprocess.run([
            sys.executable,str(a.coarse_output_adapter),
            "--source",str(base),"--purpose",purpose_arg,
            "--output",str(a.output),"--manifest",str(cm)
        ],check=True)
        coarse_manifest=json.loads(cm.read_text())
        if coarse_manifest.get("response_based") is not False:
            raise SystemExit("coarse output adapter must be response-independent")

    bounds=terminal["boundaries_cm"]
    out={
        "schema":"swap5.rom-purpose.p3.same-partition-richards-materialization.v1",
        "purpose":a.purpose,
        "material":a.material,
        "member":terminal["member"],
        "boundaries_cm":bounds,
        "layer_thickness_cm":[bounds[i+1]-bounds[i] for i in range(len(bounds)-1)],
        "temporal_factor":a.temporal_factor,
        "transaction_dt_day":0.0008/a.temporal_factor,
        "source_sha256":sha256(a.source),
        "output_sha256":sha256(a.output),
        "coarse_output_adapter_sha256":sha256(a.coarse_output_adapter),
        "representation_ladder_sha256":sha256(a.representation_ladder),
        "solver":"conventional Reference-Richards",
        "nodes":8,
        "forcing_changed":False,
        "solver_or_physics_changed":False,
        "numerical_policy_changed":False,
        "output_serialization_changed_only":True,
        "response_based":False
    }
    a.manifest.parent.mkdir(parents=True,exist_ok=True)
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
