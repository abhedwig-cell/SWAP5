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
            k,v=item.split("=",1)
            out[k]=v
    return out


def parse_reference(path:pathlib.Path,substeps:int)->dict[str,Any]:
    if substeps not in (1,2,4):
        raise ValueError(substeps)
    expected_steps=OBS_STEPS*substeps
    initial={}
    states=defaultdict(dict)
    nodes=defaultdict(lambda:defaultdict(dict))
    max_abs_mass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_INITIAL|"):
            d=fields(line.split("|",1)[1])
            initial[d["HISTORY"]]=float(d["TOTAL_STORAGE"])
        elif line.startswith("F_ROMV2_D13_REF_STATE|"):
            d=fields(line.split("|",1)[1])
            h=d["HISTORY"]; step=int(d["STEP"])
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
            raise RuntimeError(f"{h} node step count mismatch")
        cum=0.0
        S=[];C=[];QAVG=[];QEND=[];theta=[]
        block_exchange=0.0
        for step in range(1,expected_steps+1):
            row=states[h][step]
            expected_t=step*(OBS_DT/substeps)
            if abs(row["time"]-expected_t)>5e-13:
                raise RuntimeError(f"{h} time drift step {step}: {row['time']} vs {expected_t}")
            block_exchange+=row["bex"]
            cum+=row["bex"]
            if step % substeps:
                continue
            nd=nodes[h][step]
            if set(nd)!=set(range(1,17)):
                raise RuntimeError(f"{h} incomplete nodes at {step}")
            S.append(row["storage"])
            C.append(cum)
            QAVG.append(block_exchange/OBS_DT)
            QEND.append(row["qend"])
            theta.append([nd[i] for i in range(1,17)])
            max_common_ledger=max(max_common_ledger,abs(row["storage"]-initial[h]+cum))
            block_exchange=0.0
        if len(S)!=OBS_STEPS:
            raise RuntimeError(f"{h} common observation count {len(S)}")
        series[h]={"S":S,"C":C,"QAVG":QAVG,"QEND":QEND,"theta":theta}
    return {
        "series":series,
        "max_abs_interval_mass_cm":max_abs_mass,
        "max_abs_common_time_water_ledger_cm":max_common_ledger,
        "substeps_per_observation":substeps,
    }


def sign_mismatch(a:dict[str,Any],b:dict[str,Any],key:str)->int:
    n=0
    for h in HISTS:
        x=np.asarray(a["series"][h][key],dtype=float)
        y=np.asarray(b["series"][h][key],dtype=float)
        n+=int(np.count_nonzero(np.sign(x)!=np.sign(y)))
    return n


def apparent_order(e1:float,e2:float,floor:float)->float|None:
    if e1<=floor or e2<=floor or e1<=0.0 or e2<=0.0:
        return None
    return float(math.log(e1/e2,2.0))


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--coarse-reference",required=True,type=pathlib.Path)
    ap.add_argument("--mid-reference",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hci-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_NEW_REFERENCE_TEMPORAL_RESPONSE":
        raise SystemExit("wrong B1HCK preregistration phase")
    if a.material not in pre["scope"]["materials"]:
        raise SystemExit("material outside frozen panel")

    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    ci_pre=json.loads(a.b1hci_prereg.read_text())
    if b1h["material"]!=a.material:
        raise SystemExit("material result mismatch")
    frozen=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]
    observed=[float(x) for x in b1h["scaled_lambdas"]]
    if len(frozen)!=len(observed) or max(abs(x-y) for x,y in zip(frozen,observed))>1e-15:
        raise SystemExit("scaled-lambda drift")

    ref={
        "REF_DT_1E3":parse_reference(a.coarse_reference,1),
        "REF_DT_5E4":parse_reference(a.mid_reference,2),
        "REF_DT_2P5E4":parse_reference(a.fine_reference,4),
    }
    hard=float(pre["reference_temporal_ladder"]["hard_mass_gate_cm"])
    if any(float(x["max_abs_interval_mass_cm"])>hard for x in ref.values()):
        raise SystemExit("Reference interval mass gate drift")

    ci=load_module("b1hck_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    c4v=ci.load("b1hck_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],observed)
    reps={x["id"]:x for x in bp["representations"]}
    spec=next(x for x in ci_pre["independent_oracles"] if x["id"]=="DOP853_STRICT")
    dop=ci.run_oracle(c4v,reps["R16_OP"],spec,1e-10)

    cm=ci.pooled_stats(ref["REF_DT_1E3"],ref["REF_DT_5E4"])
    mf=ci.pooled_stats(ref["REF_DT_5E4"],ref["REF_DT_2P5E4"])
    cf=ci.pooled_stats(ref["REF_DT_1E3"],ref["REF_DT_2P5E4"])
    cand={
        rid:ci.pooled_stats(dop,route)
        for rid,route in ref.items()
    }

    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    components={}
    for comp,obs in COMPONENTS.items():
        floor=floors[comp]
        ecm=float(cm[obs]["rms"]); emf=float(mf[obs]["rms"])
        ecf=float(cf[obs]["rms"])
        c0=float(cand["REF_DT_1E3"][obs]["rms"])
        c1=float(cand["REF_DT_5E4"][obs]["rms"])
        c2=float(cand["REF_DT_2P5E4"][obs]["rms"])
        if ecm<=floor and emf<=floor:
            classification="SATURATED"
        elif emf<=ecm+floor:
            classification="CONVERGING"
        else:
            classification="NONCONVERGENT"
        bound=max(floor,0.10*c2)
        temporal_bounded=emf<=bound
        components[comp]={
            "observable":obs,
            "absolute_floor":floor,
            "reference_coarse_mid_rms":ecm,
            "reference_mid_fine_rms":emf,
            "reference_coarse_fine_rms":ecf,
            "reference_self_classification":classification,
            "apparent_order":apparent_order(ecm,emf,floor),
            "DOP853_to_reference_rms":{
                "REF_DT_1E3":c0,
                "REF_DT_5E4":c1,
                "REF_DT_2P5E4":c2,
            },
            "finest_temporal_bound":bound,
            "finest_temporal_bounded":temporal_bounded,
            "mid_fine_over_candidate_fine":(emf/max(c2,floor)),
            "candidate_residual_coarse_to_fine_change":c2-c0,
        }

    self_ok=all(x["reference_self_classification"]!="NONCONVERGENT" for x in components.values())
    bound_ok=all(x["finest_temporal_bounded"] for x in components.values())
    if not self_ok:
        decision=pre["material_gate"]["label_unresolved"]
    elif bound_ok:
        decision=pre["material_gate"]["label_bounded"]
    else:
        decision=pre["material_gate"]["label_not_bounded"]

    result={
        "schema":"swap5.layer-rom.phase-b1hck.material-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCK",
        "decision":decision,
        "material":a.material,
        "components":components,
        "reference_pairwise":{
            "coarse_mid":cm,
            "mid_fine":mf,
            "coarse_fine":cf,
            "qavg_sign_mismatch":{
                "coarse_mid":sign_mismatch(ref["REF_DT_1E3"],ref["REF_DT_5E4"],"QAVG"),
                "mid_fine":sign_mismatch(ref["REF_DT_5E4"],ref["REF_DT_2P5E4"],"QAVG"),
            },
            "qend_sign_mismatch":{
                "coarse_mid":sign_mismatch(ref["REF_DT_1E3"],ref["REF_DT_5E4"],"QEND"),
                "mid_fine":sign_mismatch(ref["REF_DT_5E4"],ref["REF_DT_2P5E4"],"QEND"),
            },
        },
        "candidate_DOP853_to_reference":cand,
        "integrity":{
            "pass":True,
            "reference_max_abs_interval_mass_cm":{
                k:float(v["max_abs_interval_mass_cm"]) for k,v in ref.items()
            },
            "reference_max_abs_common_time_water_ledger_cm":{
                k:float(v["max_abs_common_time_water_ledger_cm"]) for k,v in ref.items()
            },
            "DOP853_max_abs_water_ledger_cm":float(dop["max_abs_water_ledger_cm"]),
            "common_observations":OBS_STEPS,
            "hydrological_model_changed":False,
        },
        "interpretation_firewalls":[
            "Reference self-differences compare the same Richards implementation and physics at three outer time intervals.",
            "DOP853 integrates the already-qualified unchanged equal-grid Layer-ROM ODE and is used only to scale the remaining Reference temporal uncertainty.",
            "The 0.10 bound is a preregistered numerical mechanism criterion inherited from B1HCI, not an application tolerance.",
            "No state, partition, closure, physical parameter or solver tolerance is fitted to these results."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "decision":decision,
        "components":components,
        "reference_interval_mass":{
            k:v["max_abs_interval_mass_cm"] for k,v in ref.items()
        },
        "DOP853_nfev":dop["nfev"],
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
