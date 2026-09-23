#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys
from typing import Any

import numpy as np

HISTS=("X01","X02","X03","X04")
CHECKPOINTS=(64,128,256,512,1024)
FLOOR_MAP={
    "storage":"storage_rms",
    "cumulative_bottom":"cumulative_bottom_rms",
    "qavg":"qavg_rms",
    "qend":"qend_rms",
    "mapped_theta":"mapped_theta_rms",
}
PRIMARY=("cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms",
         "qavg_sign_mismatch","qend_sign_mismatch")


def load(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


def copy_route(route:dict[str,Any])->dict[str,Any]:
    return {
        "series":{
            h:{
                k:np.asarray(route["series"][h][k],dtype=float).copy().tolist()
                for k in ("S","C","QAVG","QEND","theta")
            } for h in HISTS
        }
    }


def derive_terminal_darcy(c4v,route:dict[str,Any])->None:
    for h in HISTS:
        q=[]
        for theta16 in route["series"][h]["theta"]:
            t=np.asarray(theta16,dtype=float)
            if t.shape!=(16,) or not np.all(np.isfinite(t)):
                raise RuntimeError(f"{h} invalid mapped theta for QEND")
            q.append(float(c4v.qbottom_zero_head(
                np.asarray([float(t[-1])],dtype=float),
                np.asarray([10.0],dtype=float)
            )))
        route["series"][h]["QEND"]=q


def slice_route(route:dict[str,Any],cp:int)->dict[str,Any]:
    return {
        "series":{
            h:{k:np.asarray(route["series"][h][k],dtype=float)[:cp].tolist()
               for k in ("S","C","QAVG","QEND","theta")}
            for h in HISTS
        }
    }


def stat(diff:np.ndarray)->dict[str,float|int]:
    d=np.asarray(diff,dtype=float).reshape(-1)
    if not d.size or not np.all(np.isfinite(d)):
        raise RuntimeError("invalid metric vector")
    return {
        "count":int(d.size),
        "rms":float(np.sqrt(np.mean(d*d))),
        "max_abs":float(np.max(np.abs(d))),
        "mean_abs":float(np.mean(np.abs(d))),
        "mean_signed":float(np.mean(d)),
    }


def zone_storage(route:dict[str,Any],h:str,cp:int)->tuple[np.ndarray,np.ndarray]:
    t=np.asarray(route["series"][h]["theta"],dtype=float)[:cp]
    if t.shape!=(cp,16):
        raise RuntimeError(f"{h} theta shape {t.shape}")
    return np.sum(t[:,:8]*10.0,axis=1),np.sum(t[:,8:]*10.0,axis=1)


def sign_mismatch(a:dict[str,Any],b:dict[str,Any],key:str,cp:int)->int:
    n=0
    for h in HISTS:
        x=np.asarray(a["series"][h][key],dtype=float)[:cp]
        y=np.asarray(b["series"][h][key],dtype=float)[:cp]
        n+=int(np.count_nonzero(np.sign(x)!=np.sign(y)))
    return n


def metrics(ci,a:dict[str,Any],b:dict[str,Any],cp:int)->dict[str,Any]:
    base=ci.pooled_stats(slice_route(a,cp),slice_route(b,cp))
    upper=[];lower=[]
    for h in HISTS:
        au,al=zone_storage(a,h,cp);bu,bl=zone_storage(b,h,cp)
        upper.append(au-bu);lower.append(al-bl)
    final_c=[]
    for h in HISTS:
        final_c.append(abs(float(a["series"][h]["C"][cp-1])-float(b["series"][h]["C"][cp-1])))
    return {
        "storage":{**base["storage"],"mean_abs":None},
        "cumulative_bottom":{**base["cumulative_bottom"],"mean_abs":None},
        "qavg":{**base["qavg"],"mean_abs":None},
        "qend":{**base["qend"],"mean_abs":None},
        "mapped_theta":{**base["mapped_theta"],"mean_abs":None},
        "upper_0_80_storage":stat(np.concatenate(upper)),
        "lower_80_160_storage":stat(np.concatenate(lower)),
        "qavg_sign_mismatch":sign_mismatch(a,b,"QAVG",cp),
        "qend_sign_mismatch":sign_mismatch(a,b,"QEND",cp),
        "max_abs_final_cumulative_bottom_error_cm":max(final_c),
    }


def primary_vector(m:dict[str,Any])->dict[str,float|int]:
    return {
        "cumulative_bottom_rms":float(m["cumulative_bottom"]["rms"]),
        "qavg_rms":float(m["qavg"]["rms"]),
        "qend_rms":float(m["qend"]["rms"]),
        "mapped_theta_rms":float(m["mapped_theta"]["rms"]),
        "qavg_sign_mismatch":int(m["qavg_sign_mismatch"]),
        "qend_sign_mismatch":int(m["qend_sign_mismatch"]),
    }


def no_worse(a:dict[str,float|int],b:dict[str,float|int],tol:float)->dict[str,Any]:
    comp={};strict=False
    for k in a:
        if "sign_mismatch" in k:
            rel="A_BETTER" if int(a[k])<int(b[k]) else ("B_BETTER" if int(a[k])>int(b[k]) else "EQUAL")
        else:
            av=float(a[k]);bv=float(b[k])
            rel="A_BETTER" if av<bv-tol else ("B_BETTER" if av>bv+tol else "EQUAL")
        comp[k]=rel
        strict=strict or rel=="A_BETTER"
    nw=all(v in ("A_BETTER","EQUAL") for v in comp.values())
    return {"component_relation":comp,"componentwise_no_worse":nw,
            "strictly_better_any":strict,"supported":nw and strict}


def main()->int:
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
    if pre["phase"]!="PREREGISTERED_BEFORE_SEMANTIC_REPAIR_REBASE_RESPONSE":
        raise SystemExit("wrong B1HCMR preregistration")
    if a.material not in pre["scope"]["materials"]:
        raise SystemExit("material outside frozen panel")

    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    cip=json.loads(a.b1hci_prereg.read_text())
    if b1h["material"]!=a.material:
        raise SystemExit("material identity mismatch")
    frozen=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]
    observed=[float(x) for x in b1h["scaled_lambdas"]]
    if len(frozen)!=len(observed) or max(abs(x-y) for x,y in zip(frozen,observed))>1e-15:
        raise SystemExit("scaled-lambda drift")

    ci=load("b1hcmr_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    hcl=load("b1hcmr_hcl",pathlib.Path("tests/rom/analyze_layer_rom_b1hcl_richardson.py"))
    c4v=ci.load("b1hcmr_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],observed)

    fine=hcl.parse_reference(a.fine_reference,4)
    ultra=hcl.parse_reference(a.ultra_reference,8)
    rstar=hcl.linear_route(ultra,fine,2.0,-1.0)
    # B1HCF contract: QEND is an endpoint Darcy diagnostic derived from state.
    derive_terminal_darcy(c4v,ultra)
    derive_terminal_darcy(c4v,rstar)

    reps={x["id"]:x for x in bp["representations"]}
    expected=list(pre["scope"]["representations"])
    if any(x not in reps for x in expected):
        raise SystemExit("representation authority drift")
    specs={x["id"]:x for x in cip["independent_oracles"]}
    if set(specs)!={"DOP853_STRICT","RADAU_STRICT"}:
        raise SystemExit("oracle authority drift")
    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    tol=float(pre["placement_gate"]["tolerance_continuous"])

    evaluation={}
    all_oracles=True
    for rid in expected:
        dop=ci.run_oracle(c4v,reps[rid],specs["DOP853_STRICT"],1e-10)
        rad=ci.run_oracle(c4v,reps[rid],specs["RADAU_STRICT"],1e-10)
        dr=ci.pooled_stats(dop,rad)
        mr=metrics(ci,dop,rstar,1024)
        mu=metrics(ci,dop,ultra,1024)
        gates={}
        for obs,floor_key in FLOOR_MAP.items():
            pair=float(dr[obs]["rms"])
            signal=float(mr[obs]["rms"])
            bound=max(floors[floor_key],0.01*signal)
            gates[floor_key]={"DOP853_Radau_rms":pair,"DOP853_to_Rstar_rms":signal,
                              "bound":bound,"pass":pair<=bound}
        resolved=all(x["pass"] for x in gates.values())
        all_oracles=all_oracles and resolved
        checkpoints={}
        for cp in CHECKPOINTS:
            checkpoints[str(cp)]={
                "Rstar":metrics(ci,dop,rstar,cp),
                "ultra":metrics(ci,dop,ultra,cp),
            }
        evaluation[rid]={
            "dimension":int(reps[rid]["dimension"]),
            "boundaries_cm":[float(x) for x in reps[rid]["boundaries_cm"]],
            "oracle_resolved":resolved,
            "oracle_gate":gates,
            "day1":{"Rstar":mr,"ultra":mu},
            "checkpoints":checkpoints,
            "solver_effort":{
                "DOP853_nfev":int(dop["nfev"]),
                "Radau_nfev":int(rad["nfev"]),
                "Radau_njev":int(rad["njev"]),
                "Radau_nlu":int(rad["nlu"]),
            },
            "max_water_ledger_cm":{
                "DOP853":float(dop["max_abs_water_ledger_cm"]),
                "Radau":float(rad["max_abs_water_ledger_cm"]),
            },
        }

    placement={}
    for label,target,control in (("dimension4","L4","U4"),("dimension8","R8","U8")):
        rrel=no_worse(primary_vector(evaluation[target]["day1"]["Rstar"]),
                      primary_vector(evaluation[control]["day1"]["Rstar"]),tol)
        urel=no_worse(primary_vector(evaluation[target]["day1"]["ultra"]),
                      primary_vector(evaluation[control]["day1"]["ultra"]),tol)
        placement[label]={
            "target":target,"control":control,
            "Rstar":rrel,"ultra":urel,
            "stable_supported":(
                rrel["supported"] and urel["supported"]
                and evaluation[target]["oracle_resolved"]
                and evaluation[control]["oracle_resolved"]
            )
        }

    transitions={}
    for lo,hi in (("L4","L6"),("L6","R8")):
        rr=no_worse(primary_vector(evaluation[hi]["day1"]["Rstar"]),
                    primary_vector(evaluation[lo]["day1"]["Rstar"]),tol)
        ur=no_worse(primary_vector(evaluation[hi]["day1"]["ultra"]),
                    primary_vector(evaluation[lo]["day1"]["ultra"]),tol)
        transitions[f"{lo}_to_{hi}"]={
            "Rstar":rr,"ultra":ur,
            "stable_componentwise_no_worse":rr["componentwise_no_worse"] and ur["componentwise_no_worse"],
            "stable_strict_improvement":rr["strictly_better_any"] and ur["strictly_better_any"],
        }

    eq=evaluation["R16_OP"]
    temporal_control={}
    for obs,floor_key in FLOOR_MAP.items():
        rs=float(eq["day1"]["Rstar"][obs]["rms"])
        ul=float(eq["day1"]["ultra"][obs]["rms"])
        temporal_control[floor_key]={
            "DOP853_to_Rstar_rms":rs,
            "DOP853_to_ultra_rms":ul,
            "Rstar_over_ultra":rs/max(ul,floors[floor_key]),
        }

    decision=(pre["decisions"]["complete"] if all_oracles else pre["decisions"]["oracle_unresolved"])
    result={
        "schema":"swap5.layer-rom.phase-b1hcmr.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCMR",
        "material":a.material,"decision":decision,
        "representations":evaluation,
        "placement":placement,
        "targeted_dimension_transitions":transitions,
        "equal_grid_temporal_control":temporal_control,
        "integrity":{
            "pass":True,
            "all_candidate_oracles_resolved":all_oracles,
            "corrected_QEND_from_endpoint_state":True,
            "hydrological_model_changed":False,
            "new_reference_generated":False,
        },
        "interpretation_firewalls":[
            "QEND is derived from endpoint state with the frozen zero-head Darcy operator for both R_star and ultrafine Reference.",
            "R_star is the prospectively qualified p=1 Reference temporal-limit estimate; ultrafine Reference is retained as a sensitivity basis.",
            "Placement/dimension support requires stable componentwise direction under both Reference bases.",
            "Remaining reduced-member error combines representation and coarse closure/localization effects; CoRichards decomposition is held for B1HCN."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,"decision":decision,
        "placement":placement,
        "targeted_dimension_transitions":transitions,
        "equal_grid_temporal_control":temporal_control,
        "day1_Rstar":{rid:{
            "storage":evaluation[rid]["day1"]["Rstar"]["storage"]["rms"],
            "cumulative":evaluation[rid]["day1"]["Rstar"]["cumulative_bottom"]["rms"],
            "qavg":evaluation[rid]["day1"]["Rstar"]["qavg"]["rms"],
            "qend":evaluation[rid]["day1"]["Rstar"]["qend"]["rms"],
            "theta":evaluation[rid]["day1"]["Rstar"]["mapped_theta"]["rms"],
            "upper":evaluation[rid]["day1"]["Rstar"]["upper_0_80_storage"]["rms"],
            "lower":evaluation[rid]["day1"]["Rstar"]["lower_80_160_storage"]["rms"],
            "qavg_sign":evaluation[rid]["day1"]["Rstar"]["qavg_sign_mismatch"],
            "qend_sign":evaluation[rid]["day1"]["Rstar"]["qend_sign_mismatch"],
        } for rid in expected}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
