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
SURF_H=("S09","S10","S11","S12")
GW_H=("G06","G07","G08","G09")
TERMINAL={
    "SURF_P":{"member":"S8","bounds":[0.0,10.0,20.0,30.0,40.0,50.0,60.0,80.0,160.0]},
    "GW_LB":{"member":"G8","bounds":[0.0,80.0,100.0,120.0,130.0,140.0,150.0,155.0,160.0]},
}

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

p3=load_module("rom_purpose_p3_same_partition_candidate_analysis",HERE/"analyze_rom_purpose_p3_candidates.py")

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

    bounds=TERMINAL[purpose]["bounds"]
    dz=np.diff(np.asarray(bounds,float))
    out={}
    for h in histories:
        expected=NOBS*factor
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: state coverage {h} {len(states[h])}/{expected}")
        if sorted(nodes[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{path}: observation coverage {h} {len(nodes[h])}/{NOBS}")

        storage=[]
        total=[]
        cum=[]
        q=[]
        cx=0.0
        for obs in range(1,NOBS+1):
            row=nodes[h][obs]
            if sorted(row)!=list(range(1,9)):
                raise RuntimeError(f"{path}: native-node coverage {h} obs={obs}: {sorted(row)}")
            th=np.asarray([row[i] for i in range(1,9)],float)
            st=th*dz
            storage.append(st)
            final_state=states[h][obs*factor]
            total.append(float(final_state["TOTAL_STORAGE"]))
            if purpose=="GW_LB":
                rows=[states[h][s] for s in range((obs-1)*factor+1,obs*factor+1)]
                ex=sum(float(r["BOTTOM_OUTWARD_EXCHANGE"]) for r in rows)
                cx+=ex
                cum.append(cx)
                q.append(ex/OBS_DT)

        storage=np.asarray(storage,float)
        if purpose=="SURF_P":
            out[h]={
                "total_storage_cm":list(map(float,total)),
                "surface_0_20_storage_cm":[p3.base.integrated_storage(row,bounds,0.0,20.0) for row in storage],
                "root_zone_0_40_storage_cm":[p3.base.integrated_storage(row,bounds,0.0,40.0) for row in storage],
                "upper_0_80_storage_cm":[p3.base.integrated_storage(row,bounds,0.0,80.0) for row in storage],
                "theta_10cm":[p3.base.map_piecewise_to_10cm(row,bounds) for row in storage],
            }
        else:
            out[h]={
                "total_storage_cm":list(map(float,total)),
                "cumulative_bottom_downward_cm":list(map(float,cum)),
                "interval_average_bottom_downward_flux_cm_per_day":list(map(float,q)),
            }
    return {"histories":out,"max_abs_mass_cm":maxmass}

def metrics_between(left:dict,right:dict,purpose:str)->dict:
    cand={"status":"QUALIFIED","histories":left}
    if purpose=="SURF_P":
        ref={"histories":{}}
        for h in SURF_H:
            x=right[h]
            ref["histories"][h]={
                "surface":np.asarray(x["surface_0_20_storage_cm"],float),
                "root":np.asarray(x["root_zone_0_40_storage_cm"],float),
                "upper":np.asarray(x["upper_0_80_storage_cm"],float),
                "theta":np.asarray(x["theta_10cm"],float),
                "total":np.asarray(x["total_storage_cm"],float),
            }
    else:
        ref={"histories":{}}
        for h in GW_H:
            x=right[h]
            ref["histories"][h]={
                "cum":np.asarray(x["cumulative_bottom_downward_cm"],float),
                "q":np.asarray(x["interval_average_bottom_downward_flux_cm_per_day"],float),
                "total":np.asarray(x["total_storage_cm"],float),
            }
    ans=p3.candidate_metrics(purpose,cand,ref)
    if ans is None:
        raise RuntimeError("qualified same-partition metrics unexpectedly unavailable")
    return ans

def finite_vector(x:dict)->bool:
    return all(math.isfinite(float(v)) and float(v)>=0.0 for v in x.values())

def numerical_qualification(routes:dict,statuses:dict,purpose:str)->dict:
    execution_pass=all(
        int(statuses[k]["return_code_o0"])==0 and
        int(statuses[k]["return_code_o2"])==0 and
        bool(statuses[k]["scientific_trace_identity"])
        for k in FACTORS
    )
    if not execution_pass:
        return {
            "qualified":False,
            "reason":"EXECUTION_OUTSIDE_FROZEN_QUALIFIED_DOMAIN",
            "execution_status":{f"T{k}":statuses[k] for k in FACTORS},
            "T8_vs_T16":None,
            "T16_vs_T32":None,
            "componentwise_nonincreasing":False,
            "finite_complete_vector":False,
            "max_abs_transaction_mass_cm":None,
            "mass_gate_cm":MASS_GATE,
            "mass_gate_pass":False
        }

    coarse=metrics_between(routes[8]["histories"],routes[16]["histories"],purpose)
    fine=metrics_between(routes[16]["histories"],routes[32]["histories"],purpose)
    if set(coarse)!=set(fine):
        raise RuntimeError("P3 same-partition temporal metric key drift")
    finite=finite_vector(coarse) and finite_vector(fine)
    nonincreasing=finite and all(float(fine[k])<=float(coarse[k])+1e-12 for k in coarse)
    mass={f"T{k}":float(routes[k]["max_abs_mass_cm"]) for k in FACTORS}
    mass_pass=all(v<=MASS_GATE for v in mass.values())
    return {
        "qualified":bool(finite and nonincreasing and mass_pass),
        "reason":("QUALIFIED" if finite and nonincreasing and mass_pass
                  else "TEMPORAL_VECTOR_OR_MASS_QUALIFICATION_FAILED"),
        "execution_status":{f"T{k}":statuses[k] for k in FACTORS},
        "T8_vs_T16":coarse,
        "T16_vs_T32":fine,
        "componentwise_nonincreasing":bool(nonincreasing),
        "finite_complete_vector":bool(finite),
        "max_abs_transaction_mass_cm":mass,
        "mass_gate_cm":MASS_GATE,
        "mass_gate_pass":bool(mass_pass)
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--state-count-result",required=True,type=pathlib.Path)
    ap.add_argument("--metric-contract",required=True,type=pathlib.Path)
    ap.add_argument("--route-root",required=True,type=pathlib.Path)
    ap.add_argument("--reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    state=json.loads(a.state_count_result.read_text())
    metric=json.loads(a.metric_contract.read_text())
    tol=float(pre["representation_sufficiency"]["equality_tolerance"])
    assert tol==1.0e-12
    assert float(metric["placement_decision"]["componentwise_equality_tolerance"])==tol
    assert pre["same_partition_richards_diagnostic"]["new_closure_family_authorized"] is False

    triggers=state["same_partition_richards_triggers"]
    trigger_keys={(x["purpose"],x["material"]):x for x in triggers}
    refs,comparators=p3.reference_bundle(a.reference_root)

    cases={}
    decisions={}
    any_closure=False
    any_unavailable=False
    any_unresolved=False

    for purpose,material in sorted(trigger_keys):
        trigger=trigger_keys[(purpose,material)]
        terminal=TERMINAL[purpose]
        assert trigger["member"]==terminal["member"]
        assert [float(x) for x in trigger["boundaries_cm"]]==terminal["bounds"]
        terminal_case=state["cases"][purpose][material][terminal["member"]]
        assert terminal_case["status"]=="QUALIFIED"
        assert terminal_case["representation_sufficiency"]=="BELOW_NUMERICAL_COMPARATOR"

        statuses={}
        routes={}
        for factor in FACTORS:
            sp=a.route_root/f"execution_{purpose}_{material}_T{factor}.json"
            statuses[factor]=json.loads(sp.read_text())
            assert statuses[factor]["triggered"] is True
            if (int(statuses[factor]["return_code_o0"])==0 and
                int(statuses[factor]["return_code_o2"])==0 and
                bool(statuses[factor]["scientific_trace_identity"])):
                rp=a.route_root/f"richards_{purpose}_{material}_T{factor}_o0.txt"
                routes[factor]=parse_coarse(rp,purpose,factor)

        nq=numerical_qualification(routes,statuses,purpose)
        metrics_t32=None
        relation=None
        crosses=False
        if nq["qualified"]:
            cand={"status":"QUALIFIED","histories":routes[32]["histories"]}
            metrics_t32=p3.candidate_metrics(purpose,cand,refs[purpose][material])
            if metrics_t32 is None:
                raise RuntimeError("qualified terminal Richards metric vector missing")
            crosses,relation=p3.base.crosses(metrics_t32,comparators[purpose][material],tol)

        if not nq["qualified"]:
            decision="SAME_PARTITION_RICHARDS_DIAGNOSTIC_UNAVAILABLE"
            any_unavailable=True
        elif crosses:
            decision="CLOSURE_DEFICIT_SUPPORTED"
            any_closure=True
        else:
            decision="REPRESENTATION_OR_RESOLUTION_UNRESOLVED"
            any_unresolved=True

        key=f"{purpose}/{material}"
        decisions[key]=decision
        cases[key]={
            "purpose":purpose,
            "material":material,
            "member":terminal["member"],
            "boundaries_cm":terminal["bounds"],
            "layer_rom_representation_sufficiency":"BELOW_NUMERICAL_COMPARATOR",
            "same_partition_richards_numerical_qualification":nq,
            "same_partition_richards_T32_metrics_against_R2048_T32":metrics_t32,
            "same_partition_richards_vs_R512_T32_comparator":relation,
            "same_partition_richards_crosses_R512_T32_comparator":bool(crosses),
            "decision":decision
        }

    if not triggers:
        overall="P3_NO_SAME_PARTITION_DIAGNOSTIC_TRIGGERED"
    elif any_closure:
        overall="P3_CLOSURE_DEFICIT_SUPPORTED_FOR_ONE_OR_MORE_TERMINAL_CASES"
    elif any_unavailable:
        overall="P3_SAME_PARTITION_DIAGNOSTIC_PARTLY_OR_FULLY_UNAVAILABLE"
    elif any_unresolved:
        overall="P3_REPRESENTATION_OR_RESOLUTION_REMAINS_UNRESOLVED"
    else:
        overall="P3_SAME_PARTITION_MIXED"

    out={
        "schema":"swap5.rom-purpose.p3.same-partition-richards-result.v1",
        "workstream":"ROM-PURPOSE",
        "work_unit":"ROM-PURPOSE-P3-SAME-PARTITION-RICHARDS",
        "status":overall,
        "trigger_count":len(triggers),
        "cases":cases,
        "decisions":decisions,
        "closure_deficit_supported_for_any_case":bool(any_closure),
        "new_closure_family_authorized":False,
        "componentwise_equality_tolerance":tol,
        "scientific_firewall":{
            "only_preregistered_terminal_triggers_analyzed":True,
            "representation_retuned":False,
            "partition_retuned":False,
            "closure_tuned":False,
            "weighted_score_used":False,
            "application_acceptance_adjudicated":False,
            "performance_claim_authorized":False,
            "production_rom_authorized":False
        }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":overall,"decisions":decisions},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
