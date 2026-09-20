#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys
from typing import Any
import numpy as np

COMPONENTS={
    "storage_rms":"storage",
    "cumulative_bottom_rms":"cumulative_bottom",
    "qavg_rms":"qavg",
    "qend_rms":"qend",
    "mapped_theta_rms":"mapped_theta",
}
HISTS=("X01","X02","X03","X04")

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

def sign_mismatch(a:dict[str,Any],b:dict[str,Any],key:str)->int:
    total=0
    for h in HISTS:
        x=np.asarray(a["series"][h][key],dtype=float)
        y=np.asarray(b["series"][h][key],dtype=float)
        total+=int(np.count_nonzero(np.sign(x)!=np.sign(y)))
    return total

def final_cumulative_max_abs(a:dict[str,Any],b:dict[str,Any])->float:
    vals=[]
    for h in HISTS:
        x=float(a["series"][h]["C"][-1])
        y=float(b["series"][h]["C"][-1])
        vals.append(abs(x-y))
    return max(vals)

def primary_vector(row:dict[str,Any])->dict[str,float|int]:
    return {
        "cumulative_bottom_rms":float(row["fidelity"]["cumulative_bottom"]["rms"]),
        "qavg_rms":float(row["fidelity"]["qavg"]["rms"]),
        "qend_rms":float(row["fidelity"]["qend"]["rms"]),
        "mapped_theta_rms":float(row["fidelity"]["mapped_theta"]["rms"]),
        "qavg_sign_mismatch":int(row["sign_mismatch"]["QAVG"]),
        "qend_sign_mismatch":int(row["sign_mismatch"]["QEND"]),
    }

def no_worse(a:dict[str,float|int],b:dict[str,float|int],tol:float=1e-12)->tuple[bool,bool]:
    nw=True; strict=False
    for k in a:
        av=a[k]; bv=b[k]
        if "sign_mismatch" in k:
            if int(av)>int(bv): nw=False
            if int(av)<int(bv): strict=True
        else:
            if float(av)>float(bv)+tol: nw=False
            if float(av)<float(bv)-tol: strict=True
    return nw,strict

def main()->int:
    raise SystemExit("B1HCM_SUPERSEDED_BY_B1HCMR_QEND_SEMANTIC_REPAIR")
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hci-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--ultra-reference",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_CONTINUOUS_TIME_REDUCED_LADDER_RESPONSE":
        raise SystemExit("wrong B1HCM preregistration")
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

    ci=load_module("b1hcm_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    hcl=load_module("b1hcm_hcl",pathlib.Path("tests/rom/analyze_layer_rom_b1hcl_richardson.py"))
    c4v=ci.load("b1hcm_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],observed)

    fine=hcl.parse_reference(a.fine_reference,4)
    ultra=hcl.parse_reference(a.ultra_reference,8)
    rstar=hcl.linear_route(ultra,fine,2.0,-1.0)

    reps={x["id"]:x for x in bp["representations"]}
    expected=[x["id"] for x in pre["representations"]]
    if any(rid not in reps for rid in expected):
        raise SystemExit("representation authority drift")
    oracle_specs={x["id"]:x for x in ci_pre["independent_oracles"]}
    if set(oracle_specs)!={"DOP853_STRICT","RADAU_STRICT"}:
        raise SystemExit("oracle authority drift")

    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    evaluation={}
    all_oracles=True
    for rid in expected:
        dop=ci.run_oracle(c4v,reps[rid],oracle_specs["DOP853_STRICT"],1e-10)
        rad=ci.run_oracle(c4v,reps[rid],oracle_specs["RADAU_STRICT"],1e-10)
        dr=ci.pooled_stats(dop,rad)
        df=ci.pooled_stats(dop,rstar)
        rf=ci.pooled_stats(rad,rstar)
        gates={}
        for comp,obs in COMPONENTS.items():
            floor=floors[comp]
            pair=float(dr[obs]["rms"])
            signal=float(df[obs]["rms"])
            bound=max(floor,0.01*signal)
            gates[comp]={
                "DOP853_Radau_rms":pair,
                "DOP853_to_Rstar_rms":signal,
                "bound":bound,
                "pass":pair<=bound,
            }
        resolved=all(x["pass"] for x in gates.values())
        all_oracles=all_oracles and resolved
        evaluation[rid]={
            "dimension":int(reps[rid]["dimension"]),
            "boundaries_cm":reps[rid]["boundaries_cm"],
            "oracle_resolved":resolved,
            "oracle_gate":gates,
            "fidelity":{
                obs:{
                    "rms":float(df[obs]["rms"]),
                    "max_abs":float(df[obs]["max_abs"]),
                    "Radau_rms":float(rf[obs]["rms"]),
                } for obs in ("storage","cumulative_bottom","qavg","qend","mapped_theta")
            },
            "sign_mismatch":{
                "QAVG":sign_mismatch(dop,rstar,"QAVG"),
                "QEND":sign_mismatch(dop,rstar,"QEND"),
            },
            "max_abs_final_cumulative_bottom_error_cm":final_cumulative_max_abs(dop,rstar),
            "solver_effort":{
                "DOP853_nfev":int(dop["nfev"]),
                "RADAU_nfev":int(rad["nfev"]),
                "RADAU_njev":int(rad["njev"]),
                "RADAU_nlu":int(rad["nlu"]),
            },
            "max_water_ledger_cm":{
                "DOP853":float(dop["max_abs_water_ledger_cm"]),
                "RADAU":float(rad["max_abs_water_ledger_cm"]),
            },
        }

    placement={}
    for label,target,control in (("dimension4","L4","U4"),("dimension8","R8","U8")):
        tv=primary_vector(evaluation[target]); cv=primary_vector(evaluation[control])
        nw,strict=no_worse(tv,cv)
        placement[label]={
            "target":target,"control":control,
            "target_vector":tv,"control_vector":cv,
            "componentwise_no_worse":nw,"strictly_better_any":strict,
            "supported":nw and strict and evaluation[target]["oracle_resolved"] and evaluation[control]["oracle_resolved"],
        }

    ladder={}
    for a_id,b_id in (("L4","L6"),("L6","R8")):
        av=primary_vector(evaluation[a_id]); bv=primary_vector(evaluation[b_id])
        nw,strict=no_worse(bv,av)
        ladder[f"{a_id}_to_{b_id}"]={
            "higher_dimension_no_worse_all_primary":nw,
            "strictly_better_any_primary":strict,
            "lower":av,"higher":bv,
        }

    eq=evaluation["R16_OP"]
    equal_grid={
        "within_absolute_floor":{
            comp:float(eq["fidelity"][obs]["rms"])<=floors[comp]
            for comp,obs in COMPONENTS.items()
        },
        "QAVG_sign_mismatch_zero":eq["sign_mismatch"]["QAVG"]==0,
        "QEND_sign_mismatch_zero":eq["sign_mismatch"]["QEND"]==0,
    }
    equal_grid["all_identity_conditions"]=all(equal_grid["within_absolute_floor"].values()) and equal_grid["QAVG_sign_mismatch_zero"] and equal_grid["QEND_sign_mismatch_zero"]

    decision=(pre["decisions"]["complete"] if all_oracles else pre["decisions"]["oracle_unresolved"])
    result={
        "schema":"swap5.layer-rom.phase-b1hcm.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCM",
        "material":a.material,"decision":decision,
        "representations":evaluation,
        "placement":placement,
        "targeted_dimension_transitions":ladder,
        "equal_grid_control":equal_grid,
        "integrity":{
            "pass":True,
            "all_candidate_oracles_resolved":all_oracles,
            "hydrological_model_changed":False,
            "new_reference_generated":False,
        },
        "interpretation_firewalls":[
            "R_star is the B1HCL-qualified first-order Reference temporal-limit estimate.",
            "DOP853 and Radau integrate the unchanged frozen Layer-ROM ODE for each frozen representation.",
            "Residual reduced-member error includes representation and closure/localization effects and is not decomposed into those mechanisms here.",
            "No application acceptance, timing claim, partition retuning or closure change is made."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,"decision":decision,
        "placement":placement,"targeted_dimension_transitions":ladder,
        "equal_grid_control":equal_grid,
        "fidelity":{rid:{
            "storage":evaluation[rid]["fidelity"]["storage"]["rms"],
            "cumulative":evaluation[rid]["fidelity"]["cumulative_bottom"]["rms"],
            "qavg":evaluation[rid]["fidelity"]["qavg"]["rms"],
            "qend":evaluation[rid]["fidelity"]["qend"]["rms"],
            "theta":evaluation[rid]["fidelity"]["mapped_theta"]["rms"],
            "qavg_sign":evaluation[rid]["sign_mismatch"]["QAVG"],
            "qend_sign":evaluation[rid]["sign_mismatch"]["QEND"]
        } for rid in expected}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
