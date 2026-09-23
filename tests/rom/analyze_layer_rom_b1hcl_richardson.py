#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys
from collections import defaultdict
from typing import Any

import numpy as np

HISTS=("X01","X02","X03","X04")
OBS_DT=0.001
OBS_STEPS=1024
COMPONENTS={
    "storage_rms":"storage",
    "cumulative_bottom_rms":"cumulative_bottom",
    "qavg_rms":"qavg",
    "qend_rms":"qend",
    "mapped_theta_rms":"mapped_theta",
}
SERIES_KEYS={"storage":"S","cumulative_bottom":"C","qavg":"QAVG","qend":"QEND","mapped_theta":"theta"}

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def parse_reference(path:pathlib.Path,substeps:int)->dict[str,Any]:
    if substeps not in (2,4,8):
        raise ValueError(substeps)
    expected_steps=OBS_STEPS*substeps
    initial={}
    states=defaultdict(dict)
    nodes=defaultdict(lambda:defaultdict(dict))
    max_abs_mass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_INITIAL|"):
            d=fields(line.split("|",1)[1]); initial[d["HISTORY"]]=float(d["TOTAL_STORAGE"])
        elif line.startswith("F_ROMV2_D13_REF_STATE|"):
            d=fields(line.split("|",1)[1]); h=d["HISTORY"]; step=int(d["STEP"])
            states[h][step]={
                "storage":float(d["TOTAL_STORAGE"]),
                "bex":float(d["BOTTOM_OUTWARD_EXCHANGE"]),
                "qend":float(d["BOTTOM_FLUX"]),
                "mass":float(d["MASS"]),
                "time":float(d["T"]),
            }
            max_abs_mass=max(max_abs_mass,abs(float(d["MASS"])))
        elif line.startswith("F_ROMV2_D13_REF_NODE|"):
            d=fields(line.split("|",1)[1])
            nodes[d["HISTORY"]][int(d["STEP"])][int(d["NODE"])]=float(d["THETA"])
    if set(initial)!=set(HISTS) or set(states)!=set(HISTS) or set(nodes)!=set(HISTS):
        raise RuntimeError(f"history structure mismatch in {path}")
    series={}
    max_common_ledger=0.0
    for h in HISTS:
        if set(states[h])!=set(range(1,expected_steps+1)):
            raise RuntimeError(f"{h} state count mismatch {len(states[h])} != {expected_steps}")
        if set(nodes[h])!=set(range(1,expected_steps+1)):
            raise RuntimeError(f"{h} node count mismatch")
        cum=0.0; block=0.0
        S=[];C=[];QAVG=[];QEND=[];theta=[]
        for step in range(1,expected_steps+1):
            row=states[h][step]
            expected_t=step*(OBS_DT/substeps)
            if abs(row["time"]-expected_t)>5e-13:
                raise RuntimeError(f"{h} time drift step {step}")
            block+=row["bex"]; cum+=row["bex"]
            if step%substeps:
                continue
            nd=nodes[h][step]
            if set(nd)!=set(range(1,17)):
                raise RuntimeError(f"{h} incomplete nodes at {step}")
            S.append(row["storage"]); C.append(cum); QAVG.append(block/OBS_DT); QEND.append(row["qend"])
            theta.append([nd[i] for i in range(1,17)])
            max_common_ledger=max(max_common_ledger,abs(row["storage"]-initial[h]+cum))
            block=0.0
        series[h]={"S":S,"C":C,"QAVG":QAVG,"QEND":QEND,"theta":theta}
    return {"series":series,"max_abs_interval_mass_cm":max_abs_mass,
            "max_abs_common_time_water_ledger_cm":max_common_ledger,
            "substeps_per_observation":substeps}

def linear_route(a:dict[str,Any],b:dict[str,Any],wa:float,wb:float)->dict[str,Any]:
    series={}
    for h in HISTS:
        series[h]={}
        for key in ("S","C","QAVG","QEND","theta"):
            x=np.asarray(a["series"][h][key],dtype=float)
            y=np.asarray(b["series"][h][key],dtype=float)
            if x.shape!=y.shape:
                raise RuntimeError(f"shape mismatch {h} {key}")
            series[h][key]=(wa*x+wb*y).tolist()
    return {"series":series}

def sign_mismatch(a:dict[str,Any],b:dict[str,Any],key:str)->int:
    n=0
    for h in HISTS:
        x=np.asarray(a["series"][h][key],dtype=float)
        y=np.asarray(b["series"][h][key],dtype=float)
        n+=int(np.count_nonzero(np.sign(x)!=np.sign(y)))
    return n

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--mid-reference",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--ultra-reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hci-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FOURTH_REFERENCE_LEVEL_RESPONSE":
        raise SystemExit("wrong B1HCL preregistration phase")
    if a.material not in pre["scope"]["materials"]:
        raise SystemExit("material outside frozen B1HCL panel")
    if float(pre["hypothesis"]["frozen_order"])!=1.0:
        raise SystemExit("B1HCL order drift")

    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    ci_pre=json.loads(a.b1hci_prereg.read_text())
    if b1h["material"]!=a.material:
        raise SystemExit("material result mismatch")
    frozen=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]
    observed=[float(x) for x in b1h["scaled_lambdas"]]
    if len(frozen)!=len(observed) or max(abs(x-y) for x,y in zip(frozen,observed))>1e-15:
        raise SystemExit("scaled-lambda drift")

    mid=parse_reference(a.mid_reference,2)
    fine=parse_reference(a.fine_reference,4)
    ultra=parse_reference(a.ultra_reference,8)
    hard=float(pre["new_holdout_level"]["hard_mass_gate_cm"])
    if max(mid["max_abs_interval_mass_cm"],fine["max_abs_interval_mass_cm"],ultra["max_abs_interval_mass_cm"])>hard:
        raise SystemExit("Reference mass gate drift")

    ci=load_module("b1hcl_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    c4v=ci.load("b1hcl_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],observed)
    reps={x["id"]:x for x in bp["representations"]}
    spec=next(x for x in ci_pre["independent_oracles"] if x["id"]=="DOP853_STRICT")
    dop=ci.run_oracle(c4v,reps["R16_OP"],spec,1e-10)

    mf=ci.pooled_stats(mid,fine)
    fu=ci.pooled_stats(fine,ultra)
    cand_fine=ci.pooled_stats(dop,fine)
    cand_ultra=ci.pooled_stats(dop,ultra)

    predicted_ultra=linear_route(fine,mid,1.5,-0.5)
    richardson_limit=linear_route(ultra,fine,2.0,-1.0)
    pred_error=ci.pooled_stats(predicted_ultra,ultra)
    limit_error=ci.pooled_stats(dop,richardson_limit)

    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    components={}
    for comp,obs in COMPONENTS.items():
        floor=floors[comp]
        emf=float(mf[obs]["rms"]); efu=float(fu[obs]["rms"])
        cf=float(cand_fine[obs]["rms"]); cu=float(cand_ultra[obs]["rms"])
        pe=float(pred_error[obs]["rms"]); le=float(limit_error[obs]["rms"])
        ref_ok=efu<=emf+floor
        cand_ok=cu<=cf+floor
        pred_bound=max(floor,0.10*efu)
        limit_bound=max(floor,0.10*cu)
        pred_ok=pe<=pred_bound
        limit_ok=le<=limit_bound
        order=None if emf<=floor or efu<=floor else float(math.log(emf/efu,2.0))
        components[comp]={
            "observable":obs,
            "floor":floor,
            "reference_mid_fine_rms":emf,
            "reference_fine_ultra_rms":efu,
            "fine_ultra_over_mid_fine":efu/max(emf,floor),
            "observed_order_mid_fine_to_fine_ultra":order,
            "DOP853_to_fine_rms":cf,
            "DOP853_to_ultra_rms":cu,
            "holdout_prediction_to_ultra_rms":pe,
            "holdout_prediction_bound":pred_bound,
            "DOP853_to_first_order_Richardson_limit_rms":le,
            "richardson_limit_bound":limit_bound,
            "continued_reference_convergence":ref_ok,
            "continued_candidate_convergence":cand_ok,
            "holdout_prediction_pass":pred_ok,
            "richardson_limit_pass":limit_ok,
            "all_gates_pass":ref_ok and cand_ok and pred_ok and limit_ok,
        }

    supported=all(x["all_gates_pass"] for x in components.values())
    decision=("B1HCL_MATERIAL_FIRST_ORDER_LIMIT_SUPPORTED"
              if supported else "B1HCL_MATERIAL_FIRST_ORDER_LIMIT_NOT_SUPPORTED")
    result={
        "schema":"swap5.layer-rom.phase-b1hcl.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCL",
        "material":a.material,"decision":decision,
        "components":components,
        "reference_sign_differences":{
            "QAVG_fine_ultra":sign_mismatch(fine,ultra,"QAVG"),
            "QEND_fine_ultra":sign_mismatch(fine,ultra,"QEND"),
        },
        "integrity":{
            "pass":True,
            "reference_max_abs_interval_mass_cm":{
                "REF_DT_5E4":float(mid["max_abs_interval_mass_cm"]),
                "REF_DT_2P5E4":float(fine["max_abs_interval_mass_cm"]),
                "REF_DT_1P25E4":float(ultra["max_abs_interval_mass_cm"]),
            },
            "reference_max_abs_common_time_water_ledger_cm":{
                "REF_DT_5E4":float(mid["max_abs_common_time_water_ledger_cm"]),
                "REF_DT_2P5E4":float(fine["max_abs_common_time_water_ledger_cm"]),
                "REF_DT_1P25E4":float(ultra["max_abs_common_time_water_ledger_cm"]),
            },
            "DOP853_max_abs_water_ledger_cm":float(dop["max_abs_water_ledger_cm"]),
            "common_observations":OBS_STEPS,
            "hydrological_model_changed":False
        },
        "evidence_classification":pre["evidence_classification"],
        "interpretation_firewalls":[
            "The first-order coefficient and holdout formulas were frozen before REF_DT_1P25E4 was generated.",
            "The holdout tests temporal-limit behavior only; it is not application acceptance.",
            "No closure, state, partition, physical parameter or solver tolerance is fitted or changed."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"material":a.material,"decision":decision,"components":components,
                      "DOP853_nfev":dop["nfev"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
