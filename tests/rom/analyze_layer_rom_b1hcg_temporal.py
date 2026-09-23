#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys
from typing import Any

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
DT_LADDER=(1.0e-4,5.0e-5,2.5e-5)
PRIMARY_CP="1024"


def load(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


def continuous_keys(pre):
    return [k for k in pre["full_response_vector"] if not k.endswith("_sign_errors")]


def compare_control(a:dict[str,Any],b:dict[str,Any],keys:list[str],tol:float):
    max_abs=0.0
    sign_ok=True
    for k in keys:
        if k.endswith("_sign_errors"):
            sign_ok=sign_ok and int(a[k])==int(b[k])
        else:
            max_abs=max(max_abs,abs(float(a[k])-float(b[k])))
    return max_abs,sign_ok


def nonincrease(vals:list[float],tol:float)->bool:
    return all(float(b) <= float(a)+tol for a,b in zip(vals,vals[1:]))


def relation(a:float|int,b:float|int,key:str,tol:float)->str:
    if key.endswith("_sign_errors"):
        if int(a)<int(b): return "A_STRICTLY_BETTER"
        if int(b)<int(a): return "B_STRICTLY_BETTER"
        return "NUMERICALLY_EQUAL"
    x=float(a);y=float(b)
    if x<y-tol:return "A_STRICTLY_BETTER"
    if y<x-tol:return "B_STRICTLY_BETTER"
    return "NUMERICALLY_EQUAL"


def vector_relation(a:dict[str,Any],b:dict[str,Any],keys:list[str],tol:float):
    rel={k:relation(a[k],b[k],k,tol) for k in keys}
    ano=all(v in ("A_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    bno=all(v in ("B_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    if ano and any(v=="A_STRICTLY_BETTER" for v in rel.values()):
        label="A_COMPONENTWISE_NO_WORSE"
    elif bno and any(v=="B_STRICTLY_BETTER" for v in rel.values()):
        label="B_COMPONENTWISE_NO_WORSE"
    elif all(v=="NUMERICALLY_EQUAL" for v in rel.values()):
        label="NUMERICALLY_EQUIVALENT"
    else:
        label="TRADEOFF"
    return {"vector_relation":label,"component_relation":rel}


def apparent_order(e1:float,e2:float,e3:float)->float|None:
    d1=e1-e2;d2=e2-e3
    if d1<=0.0 or d2<=0.0 or d2==0.0:
        return None
    ratio=d1/d2
    if ratio<=0.0:
        return None
    return float(np.log(ratio)/np.log(2.0))


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcf-result",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_TEMPORAL_REFINEMENT_RESULTS":
        raise SystemExit("wrong B1HCG preregistration phase")
    op=pre["pre_execution_operationalization"]
    if not op["before_first_B1HCG_execution"] or int(op["primary_temporal_horizon_step"])!=1024:
        raise SystemExit("B1HCG primary horizon not frozen")

    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    cf=json.loads(a.b1hcf_result.read_text())
    if b1h["material"]!=a.material or cf["material"]!=a.material:
        raise SystemExit("material identity mismatch")

    b1hcf=load("layer_rom_b1hcg_b1hcf",HERE/"analyze_layer_rom_b1hcf_material.py")
    c4v=b1hcf.load("layer_rom_b1hcg_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    b1hcf.patch_material(c4v,b1h["material_parameters"],b1h["scaled_lambdas"])
    r16=c4v.parse_ref(a.reference)
    reps={x["id"]:x for x in bp["representations"]}

    results={}
    max_control_delta=0.0
    control_sign_ok=True
    all_keys=list(pre["full_response_vector"])
    tol=float(pre["hard_controls"]["relation_tolerance"])

    for dt in DT_LADDER:
        substeps=int(round(float(pre["temporal_ladder"]["observation_dt_day"])/dt))
        if abs(substeps*dt-float(pre["temporal_ladder"]["observation_dt_day"]))>1e-15:
            raise SystemExit("nonintegral temporal ladder")
        c4v.DT=dt
        c4v.SUBSTEPS=substeps
        label=f"{dt:.8f}"
        results[label]={}
        for rid in ("R8","R16_OP"):
            route=b1hcf.run_lare_corrected(c4v,reps[rid],r16)
            if route["max_abs_water_ledger_cm"]>float(pre["hard_controls"]["water_ledger_cm"]):
                raise SystemExit(f"water ledger gate {a.material} {rid} {dt}")
            results[label][rid]={
                "dt_day":dt,
                "substeps_per_observation":substeps,
                "max_abs_water_ledger_cm":route["max_abs_water_ledger_cm"],
                "max_corrector_iterations":route["max_corrector_iterations"],
                "summaries":route["summaries"],
            }

    coarse=results[f"{DT_LADDER[0]:.8f}"]
    for rid in ("R8","R16_OP"):
        for cp in ("64","128","256","512","1024"):
            d,sg=compare_control(coarse[rid]["summaries"][cp],cf["LayerROM"][rid][cp],all_keys,tol)
            max_control_delta=max(max_control_delta,d)
            control_sign_ok=control_sign_ok and sg
    if max_control_delta>float(pre["hard_controls"]["dt_1e4_reproduces_B1HCF_continuous_components_max_abs"]):
        raise SystemExit(f"B1HCF reproduction drift {max_control_delta}")
    if not control_sign_ok:
        raise SystemExit("B1HCF sign-count reproduction drift")

    temporal={}
    for rid in ("R8","R16_OP"):
        temporal[rid]={"day1":{},"all_checkpoints":{},"apparent_order_day1":{}}
        for key in all_keys:
            vals=[results[f"{dt:.8f}"][rid]["summaries"][PRIMARY_CP][key] for dt in DT_LADDER]
            if key.endswith("_sign_errors"):
                ok=all(int(b)<=int(a) for a,b in zip(vals,vals[1:]))
                order=None
            else:
                ok=nonincrease([float(x) for x in vals],tol)
                order=apparent_order(float(vals[0]),float(vals[1]),float(vals[2]))
            temporal[rid]["day1"][key]={
                "values":{f"{dt:.8f}":vals[i] for i,dt in enumerate(DT_LADDER)},
                "nonincreasing":ok
            }
            temporal[rid]["apparent_order_day1"][key]=order

            all_ok=True
            for cp in ("64","128","256","512","1024"):
                vv=[results[f"{dt:.8f}"][rid]["summaries"][cp][key] for dt in DT_LADDER]
                if key.endswith("_sign_errors"):
                    cpok=all(int(b)<=int(a) for a,b in zip(vv,vv[1:]))
                else:
                    cpok=nonincrease([float(x) for x in vv],tol)
                all_ok=all_ok and cpok
            temporal[rid]["all_checkpoints"][key]=all_ok

    core=list(pre["causal_core"])
    r16_core_nonincrease=all(temporal["R16_OP"]["day1"][k]["nonincreasing"] for k in core)
    strict_any=any(
        float(temporal["R16_OP"]["day1"][k]["values"][f"{DT_LADDER[0]:.8f}"])-
        float(temporal["R16_OP"]["day1"][k]["values"][f"{DT_LADDER[2]:.8f}"])>tol
        for k in core
    )
    material_signature=bool(r16_core_nonincrease and strict_any)

    finest=results[f"{DT_LADDER[-1]:.8f}"]
    r8_vs_r16={
        "GW":vector_relation(finest["R8"]["summaries"][PRIMARY_CP],finest["R16_OP"]["summaries"][PRIMARY_CP],
                             list(pre["corrected_observables"]["retained"][:3])+[
                                 "qavg_rmse_cm_per_day","qavg_sign_errors","abs_mean_signed_qavg_error_cm_per_day",
                                 "qend_rmse_cm_per_day","qend_sign_errors","abs_mean_signed_qend_error_cm_per_day"
                             ],tol),
        "PROFILE":vector_relation(finest["R8"]["summaries"][PRIMARY_CP],finest["R16_OP"]["summaries"][PRIMARY_CP],
                                  ["upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse"],tol)
    }

    result={
        "schema":"swap5.layer-rom.phase-b1hcg.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCG",
        "decision":"B1HCG_MATERIAL_TEMPORAL_LADDER_CHARACTERIZED",
        "material":a.material,
        "integrity":{
            "pass":True,
            "max_dt_1e4_reproduction_delta":max_control_delta,
            "sign_count_reproduction_exact":control_sign_ok
        },
        "temporal_ladder":results,
        "temporal_monotonicity":temporal,
        "R16_OP_material_temporal_signature":material_signature,
        "R16_OP_causal_core_nonincreasing":r16_core_nonincrease,
        "R16_OP_strict_core_improvement_present":strict_any,
        "finest_dt_R8_vs_R16_OP":r8_vs_r16,
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "R16_OP_material_temporal_signature":material_signature,
        "R16_OP_day1":{k:temporal["R16_OP"]["day1"][k] for k in core},
        "R8_day1":{k:temporal["R8"]["day1"][k] for k in core},
        "finest_dt_R8_vs_R16_OP":r8_vs_r16,
        "max_control_delta":max_control_delta
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
