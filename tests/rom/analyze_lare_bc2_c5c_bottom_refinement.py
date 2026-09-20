#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("Z01","Z02","Z03","Z04")
DT=2.5e-5
LEDGER_GATE=1.0e-10

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c5b=load("c5b_for_c5c",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
c5a=c5b.c5a
bc=c5b.bc

PARTITIONS={
  "B10":[float(x) for x in range(0,161,10)],
  "B5":[float(x) for x in range(0,151,10)]+[155.0,160.0],
  "B2P5":[float(x) for x in range(0,151,10)]+[152.5,155.0,157.5,160.0],
}
BOTTOM_DZ={"B10":10.0,"B5":5.0,"B2P5":2.5}
for name,bounds in PARTITIONS.items():
    bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))

def load_ref(path,nn,dz):
    raw=c5a.load_reference_n(path,nn)
    out={}
    for h in HISTS:
        steps=raw[h]["steps"]
        out[h]={
          "q":[float(row["bottom_interval_flux_cm_per_day"]) for row in steps],
          "cum":np.cumsum([float(row["bottom_exchange_cm"]) for row in steps]).tolist(),
          "nodes":[row["nodes"] for row in steps],
          "node_count":nn,
          "dz_cm":dz,
        }
    return out

def run_member(member):
    bounds=PARTITIONS[member]
    histories={}
    max_ledger=0.0; max_corrector=0
    for h in HISTS:
        sol=bc.solve(bc.Case(member,h,"CURRENT_LAYER_FACE"),DT)
        if float(sol["max_abs_water_ledger_cm"])>LEDGER_GATE:
            raise RuntimeError(f"{member}: water ledger gate")
        histories[h]=c5a.candidate_arrays(sol,bounds)
        max_ledger=max(max_ledger,float(sol["max_abs_water_ledger_cm"]))
        max_corrector=max(max_corrector,int(sol["max_corrector_iterations"]))
    return {
      "member":member,
      "dimension":len(bounds)-1,
      "boundaries_cm":bounds,
      "bottom_cell_thickness_cm":BOTTOM_DZ[member],
      "dt_day":DT,
      "histories":histories,
      "max_abs_water_ledger_cm":max_ledger,
      "max_corrector_iterations":max_corrector,
    }

def richardson_spacing(h1,h2,h3,b1,b2,b3):
    out={
      "h_cm":[h1,h2,h3],
      "signed_bias_cm_per_day":[b1,b2,b3],
      "abs_delta_10_to_5":abs(b1-b2),
      "abs_delta_5_to_2p5":abs(b2-b3),
    }
    d12=abs(b1-b2);d23=abs(b2-b3)
    if d12>0.0 and d23>0.0:
        p=math.log(d12/d23,2.0)
        out["estimated_order"]=p
        denom=2.0**p-1.0
        out["extrapolated_h0_signed_mean_cm_per_day"]=None if abs(denom)<1e-15 else b3+(b3-b2)/denom
    else:
        out["estimated_order"]=None
        out["extrapolated_h0_signed_mean_cm_per_day"]=b3
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r32",required=True,type=pathlib.Path)
    ap.add_argument("--r64",required=True,type=pathlib.Path)
    ap.add_argument("--c5b-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5b-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5br=json.loads(a.c5b_result.read_text())
    c5bc=json.loads(a.c5b_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5C_R32_R64_RESPONSE"
    assert c5bc["status"]=="CLOSED_TIME_AND_UPPER_STATE_PLATEAU_PRESCRIBED_HEAD_BOUNDARY_RESPONSE_LOCALIZED"
    assert c5bc["authority"]["result_sha256"]=="f6710fcf081320ea4aa654a8bf0c3f02a42b251d2cdc8cadfd7096a66bce6668"
    assert c5br["formal_C5A_decision_retained"]=="C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED"

    r16=load_ref(a.r16,16,10.0)
    r32=load_ref(a.r32,32,5.0)
    r64=load_ref(a.r64,64,2.5)

    refdiag={
      "R16_vs_R64":c5b.signed_diagnostics(r16,r64),
      "R32_vs_R64":c5b.signed_diagnostics(r32,r64),
      "R16_vs_R32_distance":c5b.qdistance(r16,r32),
      "R32_vs_R64_distance":c5b.qdistance(r32,r64),
      "R16_vs_R64_distance":c5b.qdistance(r16,r64),
    }

    runs={m:run_member(m) for m in ("B10","B5","B2P5")}
    for m,row in runs.items():
        row["vs_R64"]=c5b.signed_diagnostics(row["histories"],r64)
        row["vs_R16"]=c5b.signed_diagnostics(row["histories"],r16)

    # Reproduce C5B B10/R16-current-face fine-dt identity against the old R16 Reference.
    frozen=c5br["runs"]["R16_CURRENT_DT25"]["signed_flux"]
    got=runs["B10"]["vs_R16"]
    baseline_identity={
      "pooled_signed_mean":abs(got["pooled_signed_mean_cm_per_day"]-frozen["pooled_signed_mean_cm_per_day"])<=1e-15,
      "pooled_rmse":abs(got["pooled_rmse_cm_per_day"]-frozen["pooled_rmse_cm_per_day"])<=1e-15,
      "cancellation_ratio":abs(got["cancellation_ratio"]-frozen["cancellation_ratio"])<=1e-12,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5C B10 does not reproduce C5B fine-dt baseline")

    b10=runs["B10"]["vs_R64"]["pooled_signed_mean_cm_per_day"]
    b5=runs["B5"]["vs_R64"]["pooled_signed_mean_cm_per_day"]
    b25=runs["B2P5"]["vs_R64"]["pooled_signed_mean_cm_per_day"]
    spatial=richardson_spacing(10.0,5.0,2.5,b10,b5,b25)

    residual=runs["B2P5"]["vs_R64"]["pooled_rmse_cm_per_day"]
    effects={
      "B10_vs_B5":c5b.qdistance(runs["B10"]["histories"],runs["B5"]["histories"]),
      "B5_vs_B2P5":c5b.qdistance(runs["B5"]["histories"],runs["B2P5"]["histories"]),
      "B10_vs_B2P5":c5b.qdistance(runs["B10"]["histories"],runs["B2P5"]["histories"]),
      "R16ref_vs_R32ref":c5b.qdistance(r16,r32),
      "R32ref_vs_R64ref":c5b.qdistance(r32,r64),
      "R16ref_vs_R64ref":c5b.qdistance(r16,r64),
    }
    ratios={k:(v["rmse_cm_per_day"]/residual if residual else None) for k,v in effects.items()}

    out={
      "schema":"swap5.lare.bc2.c5c.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5C",
      "role":"BOTTOM_ADJACENT_SPATIAL_REFINEMENT_AND_REFERENCE_GRID_AUDIT",
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "C5B_conclusion_retained":"CURRENT_LAYER_FACE retained; bottom-adjacent spatial thickness unresolved",
      "baseline_identity_to_C5B":baseline_identity,
      "reference_refinement":refdiag,
      "lare_bottom_refinement":{
        m:{
          "dimension":row["dimension"],
          "boundaries_cm":row["boundaries_cm"],
          "bottom_cell_thickness_cm":row["bottom_cell_thickness_cm"],
          "dt_day":row["dt_day"],
          "max_abs_water_ledger_cm":row["max_abs_water_ledger_cm"],
          "max_corrector_iterations":row["max_corrector_iterations"],
          "vs_R64":row["vs_R64"],
          "vs_R16":row["vs_R16"],
        } for m,row in runs.items()
      },
      "bottom_spacing_signed_bias_convergence_vs_R64":spatial,
      "effect_sizes":effects,
      "effect_ratios_to_B2P5_R64_residual":ratios,
      "interpretation_questions":{
        "reference_grid_effect":"Compare R16->R32 and R32->R64 Richards shifts before attributing old C5A residual solely to LARE.",
        "bottom_cell_effect":"Compare B10->B5->B2P5 convergence against R64 while every other C5A choice remains fixed.",
        "closure_floor_test":"If bottom-cell refinement plateaus while R64 Reference is spatially stable, a closure-algebra floor becomes the next hypothesis."
      },
      "scientific_firewall":{
        "C5A_formal_decision_changed":False,
        "C5B_current_face_closure_changed":False,
        "new_closure_fit":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "reference_R16_vs_R64_rmse":refdiag["R16_vs_R64_distance"]["rmse_cm_per_day"],
      "reference_R32_vs_R64_rmse":refdiag["R32_vs_R64_distance"]["rmse_cm_per_day"],
      "bottom_spacing_convergence":spatial,
      "B10_R64":runs["B10"]["vs_R64"]["pooled_rmse_cm_per_day"],
      "B5_R64":runs["B5"]["vs_R64"]["pooled_rmse_cm_per_day"],
      "B2P5_R64":runs["B2P5"]["vs_R64"]["pooled_rmse_cm_per_day"],
      "effect_ratios":ratios
    },sort_keys=True))

if __name__=="__main__":
    main()
