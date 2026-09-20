#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("Z01","Z02","Z03","Z04")
OBS_DT=0.0008
STEPS=1024

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c5b=load("c5b_for_c5d",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
fields=c5b.bc.fields

def parse_reference(path:pathlib.Path):
    states={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                states[(h,int(r["STEP"]))]=r
    out={}
    for h in HISTS:
        q=[]
        for step in range(1,STEPS+1):
            key=(h,step)
            if key not in states:
                raise RuntimeError(f"incomplete state-only Reference {key}")
            r=states[key]
            q.append(float(r["BOTTOM_OUTWARD_EXCHANGE"])/OBS_DT)
        out[h]={"q":q}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r32",required=True,type=pathlib.Path)
    ap.add_argument("--r64",required=True,type=pathlib.Path)
    ap.add_argument("--r128",required=True,type=pathlib.Path)
    ap.add_argument("--r256",type=pathlib.Path)
    ap.add_argument("--c5c-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5c-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5cr=json.loads(a.c5c_result.read_text())
    c5cc=json.loads(a.c5c_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5D_R128_RESPONSE"
    assert c5cc["status"]=="CLOSED_BOTTOM_CELL_REFINEMENT_EFFECT_PRESENT_REFERENCE_GRID_NOT_ASYMPTOTIC"
    assert c5cc["authority"]["result_sha256"]=="2fe5b04dc70f31a580da5e632a26b094cb0b274cc5a45722155a948a39f5d326"

    refs={
      "R16":parse_reference(a.r16),
      "R32":parse_reference(a.r32),
      "R64":parse_reference(a.r64),
      "R128":parse_reference(a.r128),
    }
    r256_available=a.r256 is not None and a.r256.exists()
    if r256_available:
        refs["R256"]=parse_reference(a.r256)

    pairs=[("R16","R32"),("R32","R64"),("R64","R128")]
    if r256_available:
        pairs.append(("R128","R256"))
    distances={f"{x}_vs_{y}":c5b.qdistance(refs[x],refs[y]) for x,y in pairs}
    signed={f"{x}_vs_{y}":c5b.signed_diagnostics(refs[x],refs[y]) for x,y in pairs}

    d16_32=distances["R16_vs_R32"]["rmse_cm_per_day"]
    d32_64=distances["R32_vs_R64"]["rmse_cm_per_day"]
    d64_128=distances["R64_vs_R128"]["rmse_cm_per_day"]

    c5c_d16_32=float(c5cr["effect_sizes"]["R16ref_vs_R32ref"]["rmse_cm_per_day"])
    c5c_d32_64=float(c5cr["effect_sizes"]["R32ref_vs_R64ref"]["rmse_cm_per_day"])
    baseline_identity={
      "R16_R32_RMSE":abs(d16_32-c5c_d16_32)<=1e-15,
      "R32_R64_RMSE":abs(d32_64-c5c_d32_64)<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5D parser does not reproduce C5C adjacent-grid evidence")

    convergence={
      "R16_R32_RMSE_cm_per_day":d16_32,
      "R32_R64_RMSE_cm_per_day":d32_64,
      "R64_R128_RMSE_cm_per_day":d64_128,
      "ratio_R32_R64_over_R16_R32":d32_64/d16_32,
      "ratio_R64_R128_over_R32_R64":d64_128/d32_64,
      "estimated_order_from_R32_R64_R128":order(d32_64,d64_128),
      "progressing_at_R128":d64_128<d32_64,
    }
    if r256_available:
        d128_256=distances["R128_vs_R256"]["rmse_cm_per_day"]
        convergence.update({
          "R128_R256_RMSE_cm_per_day":d128_256,
          "ratio_R128_R256_over_R64_R128":d128_256/d64_128,
          "estimated_order_from_R64_R128_R256":order(d64_128,d128_256),
          "progressing_at_R256":d128_256<d64_128,
          "two_consecutive_progressing_steps":(d64_128<d32_64 and d128_256<d64_128),
        })
    else:
        convergence.update({
          "R128_R256_RMSE_cm_per_day":None,
          "progressing_at_R256":None,
          "two_consecutive_progressing_steps":None,
        })

    if r256_available and convergence["two_consecutive_progressing_steps"]:
        status="REFERENCE_REFINEMENT_PROGRESSING_THROUGH_R256"
    elif convergence["progressing_at_R128"]:
        status="REFERENCE_REFINEMENT_PROGRESSING_AT_R128_R256_UNAVAILABLE_OR_NONPROGRESSING"
    else:
        status="REFERENCE_REFINEMENT_NOT_PROGRESSING_AT_R128"

    out={
      "schema":"swap5.lare.bc2.c5d.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5D",
      "role":"REFERENCE_ONLY_SPATIAL_EXTENSION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5C":baseline_identity,
      "R256_available":r256_available,
      "adjacent_grid_distances":distances,
      "adjacent_grid_signed_diagnostics":signed,
      "convergence":convergence,
      "interpretation_boundaries":[
        "C5D changes only Richards vertical Reference resolution.",
        "No LARE representation or closure is executed or modified in C5D.",
        "A decreasing adjacent-grid RMSE indicates spatial-refinement progress but is not by itself a continuum proof.",
        "C5A acceptance and all prior comparator-relative decisions remain unchanged."
      ],
      "scientific_firewall":{
        "new_lare_run":False,
        "new_closure_fit":False,
        "C5A_formal_decision_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "R256_available":r256_available,
      "convergence":convergence
    },sort_keys=True))

if __name__=="__main__":
    main()
