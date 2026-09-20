#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("Z01","Z02","Z03","Z04")
CURRENT="CURRENT_LAYER_FACE"
BOUNDARY="BOUNDARY_FACE"
DT_BASE=1.0e-4
DT_MID=5.0e-5
DT_FINE=2.5e-5
STATE_MEMBERS=("R5","R8","R16")
LEDGER_GATE=1.0e-10

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c5a=load("c5a_for_c5b",HERE/"analyze_lare_bc2_c5a_b14_dynamic_head.py")
bc=c5a.bc

def phase_blocks(history):
    if history in ("Z01","Z02"):
        return ((1,256,"PHASE1"),(257,576,"PHASE2"),(577,1024,"HOLD"))
    if history in ("Z03","Z04"):
        return ((1,320,"PHASE1"),(321,576,"PHASE2"),(577,1024,"HOLD"))
    raise ValueError(history)

def run_member(member,closure,dt):
    bounds=c5a.PARTITIONS[member]
    histories={}
    max_ledger=0.0
    max_corrector=0
    for h in HISTS:
        sol=bc.solve(bc.Case(member,h,closure),dt)
        if float(sol["max_abs_water_ledger_cm"])>LEDGER_GATE:
            raise RuntimeError(f"{member} {closure} dt={dt}: water ledger gate")
        histories[h]=c5a.candidate_arrays(sol,bounds)
        max_ledger=max(max_ledger,float(sol["max_abs_water_ledger_cm"]))
        max_corrector=max(max_corrector,int(sol["max_corrector_iterations"]))
    return {
      "member":member,"closure":closure,"dt_day":dt,
      "histories":histories,
      "max_abs_water_ledger_cm":max_ledger,
      "max_corrector_iterations":max_corrector,
    }

def signed_diagnostics(candidate,reference):
    pooled=[]
    by_history={}
    phase_rows={}
    for h in HISTS:
        cq=np.asarray(candidate[h]["q"],dtype=float)
        rq=np.asarray(reference[h]["q"],dtype=float)
        e=cq-rq
        pooled.extend(e.tolist())
        phases={}
        for lo,hi,label in phase_blocks(h):
            x=e[lo-1:hi]
            phases[label]={
              "step_start":lo,"step_end":hi,
              "signed_mean_cm_per_day":float(np.mean(x)),
              "abs_signed_mean_cm_per_day":abs(float(np.mean(x))),
              "rmse_cm_per_day":float(np.sqrt(np.mean(x*x))),
              "max_abs_cm_per_day":float(np.max(np.abs(x))),
            }
        phase_rows[h]=phases
        by_history[h]={
          "signed_mean_cm_per_day":float(np.mean(e)),
          "abs_signed_mean_cm_per_day":abs(float(np.mean(e))),
          "rmse_cm_per_day":float(np.sqrt(np.mean(e*e))),
          "max_abs_cm_per_day":float(np.max(np.abs(e))),
        }
    p=np.asarray(pooled,dtype=float)
    mean_abs_hist=float(np.mean([x["abs_signed_mean_cm_per_day"] for x in by_history.values()]))
    pooled_mean=float(np.mean(p))
    return {
      "pooled_signed_mean_cm_per_day":pooled_mean,
      "pooled_abs_signed_mean_cm_per_day":abs(pooled_mean),
      "mean_abs_history_signed_mean_cm_per_day":mean_abs_hist,
      "cancellation_ratio":abs(pooled_mean)/mean_abs_hist if mean_abs_hist else None,
      "pooled_rmse_cm_per_day":float(np.sqrt(np.mean(p*p))),
      "pooled_max_abs_cm_per_day":float(np.max(np.abs(p))),
      "by_history":by_history,
      "by_phase":phase_rows,
    }

def qdistance(a,b):
    d=[]
    for h in HISTS:
        d.extend((np.asarray(a[h]["q"],dtype=float)-np.asarray(b[h]["q"],dtype=float)).tolist())
    x=np.asarray(d,dtype=float)
    return {
      "rmse_cm_per_day":float(np.sqrt(np.mean(x*x))),
      "signed_mean_cm_per_day":float(np.mean(x)),
      "max_abs_cm_per_day":float(np.max(np.abs(x))),
    }

def richardson_bias(b1,b2,b3):
    d12=abs(b1-b2); d23=abs(b2-b3)
    out={"b_dt_1e_4":b1,"b_dt_5e_5":b2,"b_dt_2p5e_5":b3,
         "abs_delta_1e_4_to_5e_5":d12,"abs_delta_5e_5_to_2p5e_5":d23}
    if d12>0.0 and d23>0.0:
        p=math.log(d12/d23,2.0)
        out["estimated_order"]=p
        denom=2.0**p-1.0
        out["extrapolated_dt0_signed_mean_cm_per_day"]=None if abs(denom)<1e-15 else b3+(b3-b2)/denom
    else:
        out["estimated_order"]=None
        out["extrapolated_dt0_signed_mean_cm_per_day"]=b3
    return out

def classify_ratio(value):
    if value < 0.1:return "SMALL_LT_0P1_RESIDUAL"
    if value > 1.0:return "LARGE_GT_RESIDUAL"
    return "COMPARABLE_0P1_TO_1_RESIDUAL"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5ar=json.loads(a.c5a_result.read_text())
    c5ac=json.loads(a.c5a_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_ZERO_FIT_AFTER_C5A_WITHOUT_ACCEPTANCE_RETUNING"
    assert c5ar["decision"]=="C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED"
    assert c5ac["decision"]=="C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED"
    assert c5ac["authority"]["result_sha256"]=="50ac095f50f47370c6d201a18c11522f765f608ea1970eca50df0ced65a560dc"
    assert p["scientific_firewall"]["C5A_formal_decision_changed"] is False

    r16raw=c5a.load_reference_n(a.r16,16)
    r2raw=c5a.load_reference_n(a.r2,2)
    r16={h:c5a.reference_arrays(r16raw,h,[10.0]*16) for h in HISTS}
    r2={h:c5a.reference_arrays(r2raw,h,[80.0,80.0]) for h in HISTS}

    r2diag=signed_diagnostics(r2,r16)

    runs={}
    def add(key,member,closure,dt):
        row=run_member(member,closure,dt)
        row["signed_flux"]=signed_diagnostics(row["histories"],r16)
        runs[key]=row

    # Baseline identity and timestep convergence at maximum state resolution.
    add("R16_CURRENT_DT100", "R16", CURRENT, DT_BASE)
    add("R16_CURRENT_DT50",  "R16", CURRENT, DT_MID)
    add("R16_CURRENT_DT25",  "R16", CURRENT, DT_FINE)

    # State-resolution plateau at the finest diagnostic timestep.
    add("R5_CURRENT_DT25", "R5", CURRENT, DT_FINE)
    add("R8_CURRENT_DT25", "R8", CURRENT, DT_FINE)

    # Pre-existing BC1 alternative closure as a mechanism-only counterfactual.
    add("R16_BOUNDARY_DT25","R16",BOUNDARY,DT_FINE)

    baseline_metrics=c5a.compare_routes(runs["R16_CURRENT_DT100"]["histories"],r16)
    frozen_r16=next(m["metrics"] for m in c5ar["members"] if m["id"]=="R16")
    baseline_identity={}
    for key in c5a.PROFILE_KEYS:
        av=baseline_metrics[key]; bv=frozen_r16[key]
        if isinstance(av,int):
            baseline_identity[key]=(av==bv)
        else:
            baseline_identity[key]=(abs(float(av)-float(bv))<=1e-15)
    if not all(baseline_identity.values()):
        raise RuntimeError("C5B baseline does not reproduce frozen C5A R16")

    b100=runs["R16_CURRENT_DT100"]["signed_flux"]["pooled_signed_mean_cm_per_day"]
    b50=runs["R16_CURRENT_DT50"]["signed_flux"]["pooled_signed_mean_cm_per_day"]
    b25=runs["R16_CURRENT_DT25"]["signed_flux"]["pooled_signed_mean_cm_per_day"]
    rich=richardson_bias(b100,b50,b25)

    integration=qdistance(runs["R16_CURRENT_DT100"]["histories"],runs["R16_CURRENT_DT25"]["histories"])
    state_R8=qdistance(runs["R8_CURRENT_DT25"]["histories"],runs["R16_CURRENT_DT25"]["histories"])
    state_R5=qdistance(runs["R5_CURRENT_DT25"]["histories"],runs["R16_CURRENT_DT25"]["histories"])
    closure=qdistance(runs["R16_BOUNDARY_DT25"]["histories"],runs["R16_CURRENT_DT25"]["histories"])
    residual=runs["R16_CURRENT_DT25"]["signed_flux"]["pooled_rmse_cm_per_day"]

    ratios={
      "integration_shift_over_current_residual":integration["rmse_cm_per_day"]/residual if residual else None,
      "state_R8_to_R16_shift_over_current_residual":state_R8["rmse_cm_per_day"]/residual if residual else None,
      "state_R5_to_R16_shift_over_current_residual":state_R5["rmse_cm_per_day"]/residual if residual else None,
      "closure_shift_over_current_residual":closure["rmse_cm_per_day"]/residual if residual else None,
    }
    labels={k:classify_ratio(v) for k,v in ratios.items() if v is not None}

    current25=runs["R16_CURRENT_DT25"]["signed_flux"]
    boundary25=runs["R16_BOUNDARY_DT25"]["signed_flux"]

    out={
      "schema":"swap5.lare.bc2.c5b.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5B",
      "role":"ZERO_FIT_MECHANISTIC_RECONCILIATION_OF_C5A_SINGLE_COMPONENT_BLOCKER",
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5A_R16":baseline_identity,
      "R2_signed_flux_decomposition":r2diag,
      "runs":{k:{
        "member":v["member"],"closure":v["closure"],"dt_day":v["dt_day"],
        "max_abs_water_ledger_cm":v["max_abs_water_ledger_cm"],
        "max_corrector_iterations":v["max_corrector_iterations"],
        "signed_flux":v["signed_flux"]
      } for k,v in runs.items()},
      "effect_sizes":{
        "integration_R16_DT100_vs_DT25":integration,
        "state_R8_vs_R16_DT25":state_R8,
        "state_R5_vs_R16_DT25":state_R5,
        "closure_BOUNDARY_vs_CURRENT_R16_DT25":closure,
        "current_R16_DT25_reference_residual_rmse_cm_per_day":residual,
        "ratios_to_current_reference_residual":ratios,
        "ratio_labels":labels,
      },
      "timestep_signed_bias_convergence":rich,
      "counterfactual_closure":{
        "current_R16_DT25_pooled_signed_mean_cm_per_day":current25["pooled_signed_mean_cm_per_day"],
        "boundary_R16_DT25_pooled_signed_mean_cm_per_day":boundary25["pooled_signed_mean_cm_per_day"],
        "current_R16_DT25_pooled_rmse_cm_per_day":current25["pooled_rmse_cm_per_day"],
        "boundary_R16_DT25_pooled_rmse_cm_per_day":boundary25["pooled_rmse_cm_per_day"],
        "interpretation":"Sensitivity only. BOUNDARY_FACE is a pre-existing BC1 counterfactual and is not admitted or substituted into C5A."
      },
      "diagnostic_rules":{
        "SMALL_LT_0P1_RESIDUAL":"effect-size RMSE is below one tenth of the current-face R16 DT25 Reference residual",
        "COMPARABLE_0P1_TO_1_RESIDUAL":"effect-size RMSE is between one tenth and one times that residual",
        "LARGE_GT_RESIDUAL":"effect-size RMSE exceeds the current-face R16 DT25 Reference residual",
        "these_are_mechanism_labels_not_acceptance_thresholds":True
      },
      "scientific_firewall":{
        "C5A_formal_decision_changed":False,
        "C5A_metric_vector_changed":False,
        "C5A_threshold_changed":False,
        "partition_retuning":False,
        "new_closure_fit":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "R2_cancellation_ratio":r2diag["cancellation_ratio"],
      "timestep_signed_bias_convergence":rich,
      "effect_ratios":ratios,
      "ratio_labels":labels,
      "current_dt25_bias":current25["pooled_signed_mean_cm_per_day"],
      "boundary_dt25_bias":boundary25["pooled_signed_mean_cm_per_day"]
    },sort_keys=True))

if __name__=="__main__":
    main()
