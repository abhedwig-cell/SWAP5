#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("b1hcf",HERE/"analyze_layer_rom_b1hcf_material.py")
b1hcf=importlib.util.module_from_spec(spec)
sys.modules["b1hcf"]=b1hcf
spec.loader.exec_module(b1hcf)

DT_LADDER=(1.0e-4,5.0e-5,2.5e-5)
CHECKPOINTS=(64,128,256,512,1024)
RID=("R8","R16_OP")


def run_dt(c4v,member,r16,dt:float):
    bounds=[float(x) for x in member["boundaries_cm"]]
    dim=int(member["dimension"])
    substeps=int(round(b1hcf.OBS_DT/dt))
    if abs(substeps*dt-b1hcf.OBS_DT)>1e-14:
        raise RuntimeError(f"observation interval not divisible by dt {dt}")
    series=b1hcf.empty_series()
    maxledger=0.0
    maxiter=0
    for hist,lam in c4v.HISTS.items():
        dz,y=c4v.initial_state(lam,bounds)
        initial=float(np.sum(y[:dim]))
        prev_cum=0.0
        if abs(initial-float(r16["initial"][hist]["TOTAL_STORAGE"]))>1e-12:
            raise RuntimeError(f"initial storage identity mismatch {hist}")
        refcum=c4v.ref_arrays(r16,hist)
        for step in range(1,1025):
            for _ in range(substeps):
                y,it=c4v.heun_step(y,dt,dz)
                maxiter=max(maxiter,it)
            theta=y[:dim]/dz
            c4v.bc1.psi_k(theta)
            total=float(np.sum(y[:dim]))
            cum=float(y[dim+1])
            qavg=(cum-prev_cum)/b1hcf.OBS_DT
            prev_cum=cum
            qend=float(c4v.qbottom_zero_head(theta,dz))
            ledger=total-initial+cum
            maxledger=max(maxledger,abs(ledger))
            if abs(ledger)>c4v.LEDGER_GATE:
                raise RuntimeError(f"water ledger {ledger}")
            mapped=c4v.map_piecewise_to_10cm(theta,bounds)
            upper=c4v.integrated_storage(theta,bounds,0.0,80.0)
            lower=c4v.integrated_storage(theta,bounds,80.0,160.0)
            b1hcf.append(
                series,hist,total,cum,qavg,qend,mapped,upper,lower,
                r16,c4v,step,refcum
            )
    return {
        "dt_day":dt,
        "substeps_per_observation":substeps,
        "summaries":{str(cp):b1hcf.checkpoint(series,cp) for cp in CHECKPOINTS},
        "max_abs_water_ledger_cm":maxledger,
        "max_corrector_iterations":maxiter,
    }


def diff_metric(a,b,key):
    if key.endswith("_sign_errors"):
        return 0.0 if int(a)==int(b) else float(abs(int(a)-int(b)))
    return abs(float(a)-float(b))


def temporal_relation(vals,key,tol):
    if key.endswith("_sign_errors"):
        nonincrease=all(int(b)<=int(a) for a,b in zip(vals,vals[1:]))
        strict=int(vals[-1])<int(vals[0])
    else:
        nonincrease=all(float(b)<=float(a)+tol for a,b in zip(vals,vals[1:]))
        strict=float(vals[-1])<float(vals[0])-tol
    return {
        "values":vals,
        "nonincreasing":bool(nonincrease),
        "strict_coarse_to_finest_reduction":bool(strict),
    }


def vector_relation(a,b,keys):
    return b1hcf.vector_relation(a,b,tuple(keys))


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcf-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_TEMPORAL_REFINEMENT_RESULTS":
        raise SystemExit("wrong B1HCG preregistration phase")
    op=pre["pre_execution_operationalization"]
    if not op["before_first_B1HCG_execution"] or int(op["decision_checkpoint_step"])!=1024:
        raise SystemExit("B1HCG operationalization not frozen")
    if [float(x) for x in pre["temporal_ladder"]["dt_day"]]!=list(DT_LADDER):
        raise SystemExit("B1HCG dt ladder drift")

    b1h=json.loads(a.b1h_result.read_text())
    cf=json.loads(a.b1hcf_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    if b1h["material"]!=a.material or cf["material"]!=a.material:
        raise SystemExit("material identity mismatch")

    c4v=b1hcf.load("layer_rom_b1hcg_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    b1hcf.patch_material(c4v,b1h["material_parameters"],b1h["scaled_lambdas"])
    r16=c4v.parse_ref(a.reference)
    reps={x["id"]:x for x in bp["representations"]}
    if not all(x in reps for x in RID):
        raise SystemExit("missing frozen representation")

    runs={rid:{str(dt):run_dt(c4v,reps[rid],r16,dt) for dt in DT_LADDER} for rid in RID}

    response=list(pre["full_response_vector"])
    causal=list(pre["causal_core"])
    baseline_tol=float(pre["hard_controls"]["dt_1e4_reproduces_B1HCF_continuous_components_max_abs"])
    relation_tol=float(pre["hard_controls"]["relation_tolerance"])

    max_baseline=0.0
    sign_baseline_exact=True
    for rid in RID:
        base=runs[rid][str(DT_LADDER[0])]["summaries"]
        old=cf["LayerROM"][rid]
        for cp in CHECKPOINTS:
            for key in response:
                d=diff_metric(base[str(cp)][key],old[str(cp)][key],key)
                if key.endswith("_sign_errors"):
                    sign_baseline_exact=sign_baseline_exact and d==0.0
                else:
                    max_baseline=max(max_baseline,d)
    if max_baseline>baseline_tol or not sign_baseline_exact:
        raise SystemExit(f"B1HCF baseline reproduction failed max={max_baseline} sign={sign_baseline_exact}")

    temporal={}
    for rid in RID:
        temporal[rid]={}
        for cp in CHECKPOINTS:
            temporal[rid][str(cp)]={}
            for key in response:
                vals=[runs[rid][str(dt)]["summaries"][str(cp)][key] for dt in DT_LADDER]
                temporal[rid][str(cp)][key]=temporal_relation(vals,key,relation_tol)

    decision_cp=str(int(op["decision_checkpoint_step"]))
    r16_core=temporal["R16_OP"][decision_cp]
    all_nonincrease=all(r16_core[k]["nonincreasing"] for k in causal)
    any_strict=any(r16_core[k]["strict_coarse_to_finest_reduction"] for k in causal)
    signature=all_nonincrease and any_strict

    comparisons={}
    for dt in DT_LADDER:
        s=str(dt)
        comparisons[s]={
            "GW":vector_relation(
                runs["R8"][s]["summaries"][decision_cp],
                runs["R16_OP"][s]["summaries"][decision_cp],
                b1hcf.GW
            ),
            "PROFILE":vector_relation(
                runs["R8"][s]["summaries"][decision_cp],
                runs["R16_OP"][s]["summaries"][decision_cp],
                b1hcf.PROFILE
            )
        }

    result={
        "schema":"swap5.layer-rom.phase-b1hcg.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCG",
        "material":a.material,
        "decision":"B1HCG_MATERIAL_TEMPORAL_SIGNATURE_PRESENT" if signature else "B1HCG_MATERIAL_TEMPORAL_SIGNATURE_MIXED_OR_ABSENT",
        "integrity":{
            "pass":True,
            "max_B1HCF_baseline_continuous_abs_difference":max_baseline,
            "B1HCF_baseline_sign_counts_exact":sign_baseline_exact,
            "max_water_ledger_cm":max(
                runs[rid][str(dt)]["max_abs_water_ledger_cm"]
                for rid in RID for dt in DT_LADDER
            )
        },
        "dt_day":list(DT_LADDER),
        "summaries":{rid:{str(dt):runs[rid][str(dt)]["summaries"] for dt in DT_LADDER} for rid in RID},
        "temporal_relations":temporal,
        "R16_OP_decision_signature":{
            "checkpoint_step":int(decision_cp),
            "causal_core":causal,
            "all_causal_core_nonincreasing":all_nonincrease,
            "at_least_one_causal_core_strict_coarse_to_finest_reduction":any_strict,
            "signature_present":signature,
        },
        "R8_vs_R16_OP_at_decision_checkpoint":comparisons,
        "interpretation_firewalls":[
            "Only the already-frozen Layer-ROM research timestep is varied.",
            "Reference trajectories, state dimension, partitions, closure formulas and initial states are unchanged.",
            "QAVG and QEND use the corrected B1HCF commensurate definitions.",
            "Monotone temporal reduction indicates temporal contribution, not complete causal attribution.",
            "No application tolerance, runtime conclusion or production decision is made."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "decision":result["decision"],
        "integrity":result["integrity"],
        "R16_OP_signature":result["R16_OP_decision_signature"],
        "R16_OP_day1":{k:temporal["R16_OP"]["1024"][k] for k in causal},
        "R8_day1":{k:temporal["R8"]["1024"][k] for k in causal},
        "R8_vs_R16_OP":comparisons
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
