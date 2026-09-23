#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import re
import sys

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
OBS_DT=0.0008
NOBS=1024
MASS_GATE=1.0e-12
FACTORS=(8,16,32)
SURF_H=("S05","S06","S07","S08")
GW_H=("G01","G02","G03","G04")
BOUNDS={
    "SURF_P":[0.0,20.0,40.0,80.0,160.0],
    "GW_LB":[0.0,80.0,120.0,140.0,160.0],
}

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

cand=load_module("rom_purpose_p2_h4_candidate_metrics",HERE/"analyze_rom_purpose_p2_candidates.py")

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def parse_mass(line:str)->float|None:
    for pat in (r"LAREDYN0R_MAX_ABS_MASS=([^\s]+)",r"LAREGW1_MAX_ABS_MASS=([^\s]+)"):
        m=re.search(pat,line)
        if m:
            return abs(float(m.group(1)))
    return None

def parse_coarse(path:pathlib.Path,purpose:str,factor:int)->dict:
    histories=SURF_H if purpose=="SURF_P" else GW_H
    state_prefix="LAREDYN0R_STATE|" if purpose=="SURF_P" else "LAREGW1_STATE|"
    hkey="CASE" if purpose=="SURF_P" else "HISTORY"
    node_purpose="surface" if purpose=="SURF_P" else "gw"
    states={h:{} for h in histories}
    nodes={h:{} for h in histories}
    maxmass=0.0

    for line in path.read_text(errors="strict").splitlines():
        if line.startswith(state_prefix):
            r=fields(line); h=r.get(hkey)
            if h in states:
                step=int(r["STEP"])
                states[h][step]=r
                if "MASS" in r:
                    maxmass=max(maxmass,abs(float(r["MASS"])))
        elif line.startswith("ROMPURP_P1_COARSE_NODE|"):
            r=fields(line)
            if r.get("PURPOSE")!=node_purpose:
                continue
            h=r.get(hkey)
            if h in nodes:
                obs=int(r["OBS_STEP"])
                nodes[h].setdefault(obs,{})[int(r["NODE"])]=float(r["THETA"])
        else:
            x=parse_mass(line)
            if x is not None:
                maxmass=max(maxmass,x)

    bounds=BOUNDS[purpose]
    dz=np.diff(np.asarray(bounds,float))
    out={}
    for h in histories:
        expected=NOBS*factor
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: state coverage {h} {len(states[h])}/{expected}")
        if sorted(nodes[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{path}: observation coverage {h} {len(nodes[h])}/{NOBS}")

        theta=[]
        storage=[]
        total=[]
        cum=[]
        q=[]
        cx=0.0
        for obs in range(1,NOBS+1):
            row=nodes[h][obs]
            if sorted(row)!=[1,2,3,4]:
                raise RuntimeError(f"{path}: native-node coverage {h} obs={obs}: {sorted(row)}")
            th=np.asarray([row[i] for i in range(1,5)],float)
            st=th*dz
            theta.append(th); storage.append(st)
            final_state=states[h][obs*factor]
            total.append(float(final_state["TOTAL_STORAGE"]))
            if purpose=="GW_LB":
                rows=[states[h][s] for s in range((obs-1)*factor+1,obs*factor+1)]
                ex=sum(float(r["BOTTOM_OUTWARD_EXCHANGE"]) for r in rows)
                cx+=ex
                cum.append(cx); q.append(ex/OBS_DT)

        storage=np.asarray(storage,float)
        if purpose=="SURF_P":
            out[h]={
                "total_storage_cm":list(map(float,total)),
                "surface_0_20_storage_cm":[cand.integrated_storage(row,bounds,0.0,20.0) for row in storage],
                "root_zone_0_40_storage_cm":[cand.integrated_storage(row,bounds,0.0,40.0) for row in storage],
                "upper_0_80_storage_cm":[cand.integrated_storage(row,bounds,0.0,80.0) for row in storage],
                "theta_10cm":[cand.map_piecewise_to_10cm(row,bounds) for row in storage],
            }
        else:
            out[h]={
                "total_storage_cm":list(map(float,total)),
                "cumulative_bottom_downward_cm":list(map(float,cum)),
                "interval_average_bottom_downward_flux_cm_per_day":list(map(float,q)),
            }
    return {"histories":out,"max_abs_mass_cm":maxmass}

def surface_reference_from_candidate(histories:dict)->dict:
    out={}
    for h in SURF_H:
        x=histories[h]
        out[h]={
            "surface":np.asarray(x["surface_0_20_storage_cm"],float),
            "root":np.asarray(x["root_zone_0_40_storage_cm"],float),
            "upper":np.asarray(x["upper_0_80_storage_cm"],float),
            "theta":np.asarray(x["theta_10cm"],float),
            "total":np.asarray(x["total_storage_cm"],float),
        }
    return {"histories":out}

def gw_reference_from_candidate(histories:dict)->dict:
    out={}
    for h in GW_H:
        x=histories[h]
        out[h]={
            "cum":np.asarray(x["cumulative_bottom_downward_cm"],float),
            "q":np.asarray(x["interval_average_bottom_downward_flux_cm_per_day"],float),
            "total":np.asarray(x["total_storage_cm"],float),
        }
    return {"histories":out}

def pair_metrics(left:dict,right:dict,purpose:str)->dict:
    if purpose=="SURF_P":
        return cand.surface_metrics(left,surface_reference_from_candidate(right))
    return cand.gw_metrics(left,gw_reference_from_candidate(right))

def finite_vector(x:dict)->bool:
    return all(math.isfinite(float(v)) and float(v)>=0.0 for v in x.values())

def numerical_qualification(routes:dict,purpose:str)->dict:
    coarse=pair_metrics(routes[8]["histories"],routes[16]["histories"],purpose)
    fine=pair_metrics(routes[16]["histories"],routes[32]["histories"],purpose)
    if set(coarse)!=set(fine):
        raise RuntimeError("H4 temporal metric key drift")
    finite=finite_vector(coarse) and finite_vector(fine)
    nonincreasing=finite and all(float(fine[k])<=float(coarse[k]) for k in coarse)
    mass={f"T{k}":float(routes[k]["max_abs_mass_cm"]) for k in FACTORS}
    mass_pass=all(v<=MASS_GATE for v in mass.values())
    return {
        "qualified":bool(finite and nonincreasing and mass_pass),
        "T8_vs_T16":coarse,
        "T16_vs_T32":fine,
        "componentwise_nonincreasing":bool(nonincreasing),
        "finite_complete_vector":bool(finite),
        "max_abs_transaction_mass_cm":mass,
        "mass_gate_cm":MASS_GATE,
        "mass_gate_pass":bool(mass_pass),
        "exact_fine_pair_metrics":[k for k in fine if float(fine[k])==0.0],
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--contract",required=True,type=pathlib.Path)
    ap.add_argument("--metric-contract",required=True,type=pathlib.Path)
    ap.add_argument("--placement-result",required=True,type=pathlib.Path)
    ap.add_argument("--route-root",required=True,type=pathlib.Path)
    ap.add_argument("--surface-reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--gw-reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    contract=json.loads(a.contract.read_text())
    metric=json.loads(a.metric_contract.read_text())
    placement=json.loads(a.placement_result.read_text())
    assert contract["status"]=="BOUND_OPERATIONAL_EXTENSION_OF_PRE_RESPONSE_H4_CONTRACT"
    tol=float(metric["placement_decision"]["componentwise_equality_tolerance"])
    assert tol==float(contract["comparison"]["componentwise_equality_tolerance"])==1.0e-12
    assert placement["hypotheses"]["H4_same_partition_corichards_diagnostic_required"] is True

    cases={}
    decisions={}
    all_closure=True
    any_unavailable=False
    any_unresolved=False

    for trigger in contract["trigger_cases"]:
        purpose=trigger["purpose"]; material=trigger["material"]; partition=trigger["partition"]
        pr=placement["placement"][purpose][material]
        assert pr["aligned_partition"]==partition
        assert pr["same_partition_corichards_diagnostic_required"] is True
        assert pr["aligned_crosses_R512_T32_comparator"] is False

        routes={}
        for factor in FACTORS:
            p=a.route_root/f"corichards_{purpose}_{material}_T{factor}_o0.txt"
            routes[factor]=parse_coarse(p,purpose,factor)
        nq=numerical_qualification(routes,purpose)

        metrics_t32=None
        comparator_relation=None
        crosses=False
        if nq["qualified"]:
            if purpose=="SURF_P":
                target=cand.p2ref.parse_surface(
                    a.surface_reference_root/f"surface_{material}_R2048_T32_o0.txt","R2048_T32")
                metrics_t32=cand.surface_metrics(routes[32]["histories"],target)
            else:
                target=cand.p1ref.parse_gw(
                    a.gw_reference_root/f"gw_{material}_R2048_T32_o0.txt","R2048_T32")
                metrics_t32=cand.gw_metrics(routes[32]["histories"],target)
            comparator=placement["numerical_comparator"]["metrics"][purpose][material]
            crosses,comparator_relation=cand.crosses(metrics_t32,comparator,tol)

        if not nq["qualified"]:
            decision="CORICHARDS_DIAGNOSTIC_UNAVAILABLE"
            any_unavailable=True; all_closure=False
        elif crosses:
            decision="CLOSURE_DEFICIT_SUPPORTED"
        else:
            decision="FOUR_STATE_INFORMATION_OR_RESOLUTION_UNRESOLVED"
            any_unresolved=True; all_closure=False

        key=f"{purpose}/{material}"
        decisions[key]=decision
        cases[key]={
            "purpose":purpose,"material":material,"partition":partition,
            "layer_rom_crosses_R512_T32_comparator":False,
            "corichards_numerical_qualification":nq,
            "corichards_T32_metrics_against_R2048_T32":metrics_t32,
            "corichards_vs_R512_T32_comparator":comparator_relation,
            "corichards_crosses_R512_T32_comparator":bool(crosses),
            "decision":decision,
        }

    if all_closure:
        overall="P2_H4_CLOSURE_DEFICIT_SUPPORTED_ALL_TRIGGER_CASES"
    elif any_unavailable:
        overall="P2_H4_DIAGNOSTIC_PARTLY_OR_FULLY_UNAVAILABLE"
    elif any_unresolved:
        overall="P2_H4_FOUR_STATE_INFORMATION_OR_RESOLUTION_UNRESOLVED"
    else:
        overall="P2_H4_MIXED"

    out={
        "schema":"swap5.rom-purpose.p2.h4-result.v1",
        "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P2-H4",
        "status":overall,
        "cases":cases,
        "decisions":decisions,
        "all_trigger_cases_support_closure_deficit":bool(all_closure),
        "metric_contract":str(a.metric_contract),
        "componentwise_equality_tolerance":tol,
        "application_authority_status":"REFERENCE_OR_APPLICATION_ENVELOPE_NOT_YET_AUTHORITATIVE",
        "interpretation":{
            "placement_evidence_retained":True,
            "new_closure_family_authorized":False,
            "state_count_increase_inferred":False,
            "application_acceptance_adjudicated":False,
            "performance_claim_authorized":False,
            "production_rom_authorized":False,
        },
        "scientific_firewall":{
            "representation_retuned":False,
            "partition_retuned":False,
            "closure_tuned":False,
            "weighted_score_used":False,
            "materials_aggregated_for_case_decision":False,
            "P1_failure_overridden":False,
        }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":overall,"decisions":decisions},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
