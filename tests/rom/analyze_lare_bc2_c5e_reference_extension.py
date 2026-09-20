#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys

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

c5d=load("c5d_for_c5e",HERE/"analyze_lare_bc2_c5d_reference_extension.py")
c5b=c5d.c5b
fields=c5d.fields

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
            q.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"])/OBS_DT)
        out[h]={"q":q}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r64",required=True,type=pathlib.Path)
    ap.add_argument("--r128",required=True,type=pathlib.Path)
    ap.add_argument("--r256",required=True,type=pathlib.Path)
    ap.add_argument("--r512",required=True,type=pathlib.Path)
    ap.add_argument("--r1024",type=pathlib.Path)
    ap.add_argument("--c5d-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5d-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5dr=json.loads(a.c5d_result.read_text())
    c5dc=json.loads(a.c5d_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5E_R512_RESPONSE"
    assert c5dc["status"]=="CLOSED_REFERENCE_REFINEMENT_WEAKLY_PROGRESSING_THROUGH_R256_NOT_ASYMPTOTIC"
    assert c5dc["authority"]["result_sha256"]=="34082ec971a2461a43dae87faa885579b60a37241fff337ccc2c948b21345a50"

    refs={
      "R64":parse_reference(a.r64),
      "R128":parse_reference(a.r128),
      "R256":parse_reference(a.r256),
      "R512":parse_reference(a.r512),
    }
    r1024_available=a.r1024 is not None and a.r1024.exists()
    if r1024_available:
        refs["R1024"]=parse_reference(a.r1024)

    pairs=[("R64","R128"),("R128","R256"),("R256","R512")]
    if r1024_available:
        pairs.append(("R512","R1024"))
    distances={f"{x}_vs_{y}":c5b.qdistance(refs[x],refs[y]) for x,y in pairs}
    signed={f"{x}_vs_{y}":c5b.signed_diagnostics(refs[x],refs[y]) for x,y in pairs}

    d64_128=distances["R64_vs_R128"]["rmse_cm_per_day"]
    d128_256=distances["R128_vs_R256"]["rmse_cm_per_day"]
    d256_512=distances["R256_vs_R512"]["rmse_cm_per_day"]

    baseline_identity={
      "R64_R128_RMSE":abs(d64_128-float(c5dr["convergence"]["R64_R128_RMSE_cm_per_day"]))<=1e-15,
      "R128_R256_RMSE":abs(d128_256-float(c5dr["convergence"]["R128_R256_RMSE_cm_per_day"]))<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5E parser does not reproduce C5D adjacent-grid evidence")

    conv={
      "R64_R128_RMSE_cm_per_day":d64_128,
      "R128_R256_RMSE_cm_per_day":d128_256,
      "R256_R512_RMSE_cm_per_day":d256_512,
      "ratio_R256_R512_over_R128_R256":d256_512/d128_256,
      "estimated_order_from_R128_R256_R512":order(d128_256,d256_512),
      "progressing_at_R512":d256_512<d128_256,
    }
    if r1024_available:
        d512_1024=distances["R512_vs_R1024"]["rmse_cm_per_day"]
        conv.update({
          "R512_R1024_RMSE_cm_per_day":d512_1024,
          "ratio_R512_R1024_over_R256_R512":d512_1024/d256_512,
          "estimated_order_from_R256_R512_R1024":order(d256_512,d512_1024),
          "progressing_at_R1024":d512_1024<d256_512,
          "two_new_consecutive_progressing_steps":(d256_512<d128_256 and d512_1024<d256_512),
        })
    else:
        conv.update({
          "R512_R1024_RMSE_cm_per_day":None,
          "ratio_R512_R1024_over_R256_R512":None,
          "estimated_order_from_R256_R512_R1024":None,
          "progressing_at_R1024":None,
          "two_new_consecutive_progressing_steps":None,
        })

    prior_order=float(c5dr["convergence"]["estimated_order_from_R64_R128_R256"])
    new_order=conv["estimated_order_from_R128_R256_R512"]
    if r1024_available:
        final_order=conv["estimated_order_from_R256_R512_R1024"]
    else:
        final_order=None
    conv["prior_observed_order_R64_R128_R256"]=prior_order
    conv["order_change_to_R128_R256_R512"]=None if new_order is None else new_order-prior_order
    conv["order_change_to_R256_R512_R1024"]=None if new_order is None or final_order is None else final_order-new_order

    if r1024_available and conv["two_new_consecutive_progressing_steps"]:
        status="REFERENCE_REFINEMENT_PROGRESSING_THROUGH_R1024"
    elif conv["progressing_at_R512"]:
        status="REFERENCE_REFINEMENT_PROGRESSING_AT_R512_R1024_UNAVAILABLE_OR_NONPROGRESSING"
    else:
        status="REFERENCE_REFINEMENT_NOT_PROGRESSING_AT_R512"

    out={
      "schema":"swap5.lare.bc2.c5e.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5E",
      "role":"REFERENCE_ONLY_HIGH_RESOLUTION_SPATIAL_EXTENSION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5D":baseline_identity,
      "R1024_available":r1024_available,
      "adjacent_grid_distances":distances,
      "adjacent_grid_signed_diagnostics":signed,
      "convergence":conv,
      "interpretation_boundaries":[
        "C5E changes only Richards vertical Reference resolution.",
        "No LARE representation or closure is executed or modified.",
        "Monotone adjacent-grid decrease is not sufficient for a continuum claim.",
        "Observed order is descriptive because temporal and nonlinear tolerances are held fixed rather than jointly refined.",
        "C5A and all prior comparator-relative decisions remain unchanged."
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
    print(json.dumps({"status":status,"R1024_available":r1024_available,"convergence":conv},sort_keys=True))

if __name__=="__main__":
    main()
