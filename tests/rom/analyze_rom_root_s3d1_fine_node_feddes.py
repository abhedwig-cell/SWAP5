#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re

GUARD=2.9103830456733704e-11
MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")
SEGMENTS=(1,2,3,4)
STEPS=32768
OBS_FACTOR=32
OBS=1024
LAYERS=8

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def f(x:str)->float:
    return float(x.replace("D","E").replace("d","e"))

def rms(values:list[float])->float:
    return math.sqrt(math.fsum(x*x for x in values)/len(values)) if values else 0.0

def case_logs(root:pathlib.Path,material:str,history:str)->list[pathlib.Path]:
    out=[]
    for seg in SEGMENTS:
        hits=list(root.glob(f"**/{material}_R2048_T32_o0_{history}_seg{seg}.txt"))
        if len(hits)!=1:
            raise SystemExit(f"{material} {history} seg{seg}: expected one log, found {len(hits)}")
        out.append(hits[0])
    return out

def parse_case(paths:list[pathlib.Path],material:str,history:str)->dict:
    tx={}
    layers={}
    root_obs={}
    for path in paths:
        for line in path.read_text(errors="replace").splitlines():
            if line.startswith("ROM_ROOT_S3D1_TX|"):
                r=fields(line)
                if r.get("CASE")!=history:
                    continue
                step=int(r["STEP"])
                if step in tx:
                    raise SystemExit(f"{material} {history}: duplicate TX step {step}")
                tx[step]={
                    "fexact":f(r["FEXACT"]),"froot":f(r["FROOT"]),"fr16":f(r["FR16"]),
                    "A":f(r["A"]),"B":f(r["B"]),"total":f(r["TOTAL"]),
                    "h3cross":int(r["H3CROSS"]),"h4cross":int(r["H4CROSS"]),
                    "cross_root":f(r["CROSS_ROOT"]),"cross_l1":f(r["CROSS_L1"]),
                    "noncross_l1":f(r["NONCROSS_L1"]),
                }
            elif line.startswith("ROM_ROOT_S3D1_LAYER|"):
                r=fields(line)
                if r.get("CASE")!=history:
                    continue
                obs=int(r["OBS_STEP"]); layer=int(r["LAYER"])
                key=(obs,layer)
                if key in layers:
                    raise SystemExit(f"{material} {history}: duplicate layer record {key}")
                layers[key]={
                    "deltaf":f(r["DELTAF"]),"theta_bar":f(r["THETA_BAR"]),
                    "h_storage":f(r["H_STORAGE"]),"h_root":f(r["H_ROOT"]),
                    "hmin":f(r["HMIN"]),"hmax":f(r["HMAX"]),"h3":f(r["H3"]),"h4":f(r["H4"]),
                    "fexact":f(r["FEXACT"]),"froot":f(r["FROOT"]),"fr16":f(r["FR16"]),
                    "A":f(r["A"]),"B":f(r["B"]),
                    "h3cross":r["H3CROSS"].strip().upper().startswith("T"),
                    "h4cross":r["H4CROSS"].strip().upper().startswith("T"),
                }
            elif line.startswith("LAREDYN0R_ROOT|"):
                r=fields(line)
                if r.get("CASE")!=history:
                    continue
                obs=int(r["OBS_STEP"])
                if obs in root_obs:
                    raise SystemExit(f"{material} {history}: duplicate root obs {obs}")
                root_obs[obs]=f(r["ACTUAL_FRACTION"])

    if sorted(tx)!=list(range(1,STEPS+1)):
        raise SystemExit(f"{material} {history}: incomplete TX coverage {len(tx)}")
    if sorted(root_obs)!=list(range(1,OBS+1)):
        raise SystemExit(f"{material} {history}: incomplete root observation coverage {len(root_obs)}")
    expected_layers={(o,l) for o in range(1,OBS+1) for l in range(1,LAYERS+1)}
    if set(layers)!=expected_layers:
        raise SystemExit(f"{material} {history}: incomplete layer coverage {len(layers)}")

    total=[tx[s]["total"] for s in range(1,STEPS+1)]
    avec=[tx[s]["A"] for s in range(1,STEPS+1)]
    bvec=[tx[s]["B"] for s in range(1,STEPS+1)]
    identity=[total[i]-(avec[i]+bvec[i]) for i in range(STEPS)]
    exact_process=[]
    obs_total=[]
    obs_a=[]
    obs_b=[]
    for obs in range(1,OBS+1):
        lo=(obs-1)*OBS_FACTOR+1
        hi=obs*OBS_FACTOR
        exact=math.fsum(tx[s]["fexact"] for s in range(lo,hi+1))/OBS_FACTOR
        projected=math.fsum(tx[s]["fr16"] for s in range(lo,hi+1))/OBS_FACTOR
        aa=math.fsum(tx[s]["A"] for s in range(lo,hi+1))/OBS_FACTOR
        bb=math.fsum(tx[s]["B"] for s in range(lo,hi+1))/OBS_FACTOR
        exact_process.append(exact-root_obs[obs])
        obs_total.append(projected-exact)
        obs_a.append(aa)
        obs_b.append(bb)

    cross_l1=math.fsum(tx[s]["cross_l1"] for s in tx)
    noncross_l1=math.fsum(tx[s]["noncross_l1"] for s in tx)
    denom=cross_l1+noncross_l1
    crossing_steps=sum(1 for s in tx if tx[s]["h3cross"]>0 or tx[s]["h4cross"]>0)
    h3_steps=sum(1 for s in tx if tx[s]["h3cross"]>0)
    h4_steps=sum(1 for s in tx if tx[s]["h4cross"]>0)

    layer_a_cross=[]
    layer_a_noncross=[]
    layer_b_cross=[]
    layer_b_noncross=[]
    for row in layers.values():
        if row["h3cross"] or row["h4cross"]:
            layer_a_cross.append(row["A"]); layer_b_cross.append(row["B"])
        else:
            layer_a_noncross.append(row["A"]); layer_b_noncross.append(row["B"])

    return {
        "transaction_count":STEPS,
        "observation_count":OBS,
        "layer_observation_count":OBS*LAYERS,
        "integrity":{
            "max_abs_A_plus_B_identity_error":max(abs(x) for x in identity),
            "max_abs_exact_process_observation_fraction_error":max(abs(x) for x in exact_process),
            "identity_within_guard":max(abs(x) for x in identity)<=GUARD,
            "exact_process_observation_identity_within_guard":max(abs(x) for x in exact_process)<=GUARD,
        },
        "static_functional_error":{
            "transaction_rmse_fraction":rms(total),
            "transaction_max_abs_fraction":max(abs(x) for x in total),
            "observation_mean_rmse_fraction":rms(obs_total),
            "observation_mean_max_abs_fraction":max(abs(x) for x in obs_total),
            "numerically_distinguishable":max(abs(x) for x in total)>GUARD,
            "signed_transaction_mean":math.fsum(total)/STEPS,
        },
        "A_threshold_nonlinearity":{
            "transaction_rmse_fraction":rms(avec),
            "transaction_max_abs_fraction":max(abs(x) for x in avec),
            "observation_mean_rmse_fraction":rms(obs_a),
            "observation_mean_max_abs_fraction":max(abs(x) for x in obs_a),
            "numerically_distinguishable":max(abs(x) for x in avec)>GUARD,
            "signed_transaction_mean":math.fsum(avec)/STEPS,
            "layer_observation_crossing_rmse":rms(layer_a_cross),
            "layer_observation_noncrossing_rmse":rms(layer_a_noncross),
            "layer_observation_noncrossing_max_abs":max([abs(x) for x in layer_a_noncross] or [0.0]),
        },
        "B_representative_head_distribution":{
            "transaction_rmse_fraction":rms(bvec),
            "transaction_max_abs_fraction":max(abs(x) for x in bvec),
            "observation_mean_rmse_fraction":rms(obs_b),
            "observation_mean_max_abs_fraction":max(abs(x) for x in obs_b),
            "numerically_distinguishable":max(abs(x) for x in bvec)>GUARD,
            "signed_transaction_mean":math.fsum(bvec)/STEPS,
            "layer_observation_crossing_rmse":rms(layer_b_cross),
            "layer_observation_noncrossing_rmse":rms(layer_b_noncross),
            "layer_observation_noncrossing_max_abs":max([abs(x) for x in layer_b_noncross] or [0.0]),
        },
        "threshold_crossing":{
            "transactions_with_any_crossing":crossing_steps,
            "fraction_transactions_with_any_crossing":crossing_steps/STEPS,
            "transactions_with_h3_crossing":h3_steps,
            "transactions_with_h4_crossing":h4_steps,
            "absolute_layerwise_total_error_crossing":cross_l1,
            "absolute_layerwise_total_error_noncrossing":noncross_l1,
            "crossing_share_of_absolute_layerwise_error":cross_l1/denom if denom>0 else 0.0,
            "max_crossing_root_fraction":max(tx[s]["cross_root"] for s in tx),
        },
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--logs-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--stage3-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    s3=json.loads(a.stage3_result.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_S3D1_FINE_NODE_DIAGNOSTIC_RESPONSE":
        raise SystemExit("invalid S3-D1 preregistration state")
    if not s3["state_sufficiency_interpretation"]["minimal_existing_state_feedback_sufficient"] is False:
        raise SystemExit("Stage 3 falsification authority missing")
    cases={}
    for material in MATERIALS:
        for history in HISTORIES:
            cases[f"{material}_{history}"]=parse_case(case_logs(a.logs_dir,material,history),material,history)

    integrity=all(v["integrity"]["identity_within_guard"] and v["integrity"]["exact_process_observation_identity_within_guard"] for v in cases.values())
    static_cases=[k for k,v in cases.items() if v["static_functional_error"]["numerically_distinguishable"]]
    a_cases=[k for k,v in cases.items() if v["A_threshold_nonlinearity"]["numerically_distinguishable"]]
    b_cases=[k for k,v in cases.items() if v["B_representative_head_distribution"]["numerically_distinguishable"]]
    if a_cases and b_cases:
        decision="A_AND_B_STATIC_MISSING_INFORMATION_SUPPORTED"
    elif a_cases:
        decision="A_THRESHOLD_CROSSING_STATIC_MISSING_INFORMATION_SUPPORTED"
    elif b_cases:
        decision="B_ROOT_WEIGHTED_HEAD_STATIC_MISSING_INFORMATION_SUPPORTED"
    else:
        decision="STATIC_A_B_NOT_NUMERICALLY_DISTINGUISHABLE"

    out={
        "schema":"swap5.rom_root.s3d1.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3-D1",
        "date":"2026-09-23",
        "status":"S3D1_FINE_NODE_STATIC_FEDDES_DECOMPOSITION_COMPLETE",
        "decision":decision,
        "numerical_guard":GUARD,
        "integrity_pass":integrity,
        "cases":cases,
        "summary":{
            "case_count":len(cases),
            "static_functional_error_distinguishable_cases":static_cases,
            "A_distinguishable_cases":a_cases,
            "B_distinguishable_cases":b_cases,
            "all_cases_static_functional_error_distinguishable":len(static_cases)==8,
            "all_cases_A_distinguishable":len(a_cases)==8,
            "all_cases_B_distinguishable":len(b_cases)==8,
        },
        "interpretation":{
            "D_hydraulic_propagation_present_in_diagnostic":False,
            "E_memory_adjudicated":False,
            "new_state_selected":False,
            "application_acceptance":False,
            "note":"A and B are exact algebraic components on the same qualified Reference state. No response-derived dominance threshold is used."
        },
        "scientific_firewall":{
            "reduced_candidate_response_generated":False,
            "new_partition_selected":False,
            "new_hydraulic_closure_selected":False,
            "new_root_specific_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False,
    }
    if not integrity:
        out["status"]="S3D1_INTEGRITY_FAILED"
        out["decision"]="STOP_NO_SCIENTIFIC_INTERPRETATION"
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":out["status"],"decision":out["decision"],
        "static_cases":len(static_cases),"A_cases":len(a_cases),"B_cases":len(b_cases),
        "integrity":integrity
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
