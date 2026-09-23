#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

GUARD=2.9103830456733704e-11
MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")
SEGMENTS=(1,2,3,4)
SUPPORT_NODES=(128,64,32,16,8,4,2,1)
SUPPORT_CM={128:10.0,64:5.0,32:2.5,16:1.25,8:0.625,4:0.3125,2:0.15625,1:0.078125}
EXPECTED_SEGMENT_COUNT=8192
EXPECTED_TOTAL_COUNT=32768

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def ff(x:str)->float:
    return float(x.replace("D","E").replace("d","e"))

def case_logs(root:pathlib.Path,material:str,history:str)->list[pathlib.Path]:
    out=[]
    for seg in SEGMENTS:
        hits=list(root.glob(f"**/{material}_R2048_T32_o0_{history}_seg{seg}.txt"))
        if len(hits)!=1:
            raise SystemExit(f"{material} {history} seg{seg}: expected one log, found {len(hits)}")
        out.append(hits[0])
    return out

def parse_case(paths:list[pathlib.Path],material:str,history:str)->dict:
    rows={n:[] for n in SUPPORT_NODES}
    for path in paths:
        for line in path.read_text(errors="replace").splitlines():
            if not line.startswith("ROM_ROOT_S3D2_SUMMARY|"):
                continue
            r=fields(line)
            if r.get("CASE")!=history:
                continue
            n=int(r["NODES_PER_LAYER"])
            if n not in rows:
                raise SystemExit(f"{material} {history}: unexpected support {n}")
            row={
                "segment_start":int(r["SEGMENT_START"]),
                "segment_end":int(r["SEGMENT_END"]),
                "count":int(r["COUNT"]),
                "sumsq_e":ff(r["SUMSQ_E"]),"sumsq_a":ff(r["SUMSQ_A"]),"sumsq_b":ff(r["SUMSQ_B"]),
                "sum_e":ff(r["SUM_E"]),"sum_a":ff(r["SUM_A"]),"sum_b":ff(r["SUM_B"]),
                "max_e":ff(r["MAXABS_E"]),"max_a":ff(r["MAXABS_A"]),"max_b":ff(r["MAXABS_B"]),
                "cross_tx":int(r["CROSS_TX"]),"cross_l1":ff(r["CROSS_L1"]),"noncross_l1":ff(r["NONCROSS_L1"]),
                "max_identity":ff(r["MAX_IDENTITY"]),
            }
            rows[n].append(row)

    out={}
    for n in SUPPORT_NODES:
        parts=sorted(rows[n],key=lambda x:x["segment_start"])
        if len(parts)!=4:
            raise SystemExit(f"{material} {history} support {n}: expected 4 summaries, got {len(parts)}")
        if [(x["segment_start"],x["segment_end"]) for x in parts] != [(1,8192),(8193,16384),(16385,24576),(24577,32768)]:
            raise SystemExit(f"{material} {history} support {n}: segment coverage mismatch")
        if any(x["count"]!=EXPECTED_SEGMENT_COUNT for x in parts):
            raise SystemExit(f"{material} {history} support {n}: segment count mismatch")
        count=sum(x["count"] for x in parts)
        sumsq_e=math.fsum(x["sumsq_e"] for x in parts)
        sumsq_a=math.fsum(x["sumsq_a"] for x in parts)
        sumsq_b=math.fsum(x["sumsq_b"] for x in parts)
        sum_e=math.fsum(x["sum_e"] for x in parts)
        sum_a=math.fsum(x["sum_a"] for x in parts)
        sum_b=math.fsum(x["sum_b"] for x in parts)
        cross_l1=math.fsum(x["cross_l1"] for x in parts)
        noncross_l1=math.fsum(x["noncross_l1"] for x in parts)
        denom=cross_l1+noncross_l1
        out[str(n)]={
            "support_cm":SUPPORT_CM[n],
            "root_zone_layers":1024//n,
            "total_column_layers":2048//n,
            "count":count,
            "E_rmse":math.sqrt(sumsq_e/count),
            "A_rmse":math.sqrt(sumsq_a/count),
            "B_rmse":math.sqrt(sumsq_b/count),
            "E_max_abs":max(x["max_e"] for x in parts),
            "A_max_abs":max(x["max_a"] for x in parts),
            "B_max_abs":max(x["max_b"] for x in parts),
            "E_signed_mean":sum_e/count,
            "A_signed_mean":sum_a/count,
            "B_signed_mean":sum_b/count,
            "crossing_transaction_fraction":sum(x["cross_tx"] for x in parts)/count,
            "crossing_share_absolute_layerwise_error":cross_l1/denom if denom>0 else 0.0,
            "max_identity_error":max(x["max_identity"] for x in parts),
            "E_within_guard":max(x["max_e"] for x in parts)<=GUARD,
            "A_within_guard":max(x["max_a"] for x in parts)<=GUARD,
            "B_within_guard":max(x["max_b"] for x in parts)<=GUARD,
        }
        if count!=EXPECTED_TOTAL_COUNT:
            raise SystemExit(f"{material} {history} support {n}: total count mismatch")
    return out

def frontier(case:dict,field:str):
    for n in SUPPORT_NODES:
        if case[str(n)][field]:
            return {"nodes_per_layer":n,"support_cm":SUPPORT_CM[n],"total_column_layers":2048//n}
    return None

def nonincreasing(case:dict,field:str)->bool:
    vals=[case[str(n)][field] for n in SUPPORT_NODES]
    return all(vals[i+1] <= vals[i] + GUARD for i in range(len(vals)-1))

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--logs-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--s3d1-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    d1=json.loads(a.s3d1_result.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_S3D2_SUPPORT_SWEEP_RESPONSE":
        raise SystemExit("invalid S3-D2 preregistration state")
    if d1["decision"]!="A_AND_B_STATIC_MISSING_INFORMATION_SUPPORTED":
        raise SystemExit("S3-D1 A/B authority missing")

    cases={}
    for material in MATERIALS:
        for history in HISTORIES:
            key=f"{material}_{history}"
            supports=parse_case(case_logs(a.logs_dir,material,history),material,history)
            cases[key]={
                "supports":supports,
                "frontier_total":frontier(supports,"E_within_guard"),
                "frontier_A":frontier(supports,"A_within_guard"),
                "frontier_B":frontier(supports,"B_within_guard"),
                "E_max_abs_nonincreasing_with_guard":nonincreasing(supports,"E_max_abs"),
                "A_max_abs_nonincreasing_with_guard":nonincreasing(supports,"A_max_abs"),
                "B_max_abs_nonincreasing_with_guard":nonincreasing(supports,"B_max_abs"),
            }

    def all_case_frontier(field:str):
        for n in SUPPORT_NODES:
            if all(c["supports"][str(n)][field] for c in cases.values()):
                return {"nodes_per_layer":n,"support_cm":SUPPORT_CM[n],"total_column_layers":2048//n}
        return None

    frontier_total=all_case_frontier("E_within_guard")
    frontier_a=all_case_frontier("A_within_guard")
    frontier_b=all_case_frontier("B_within_guard")
    integrity=max(c["supports"][str(n)]["max_identity_error"] for c in cases.values() for n in SUPPORT_NODES)
    integrity_pass=integrity<=GUARD
    if frontier_total and frontier_a and frontier_b:
        decision="DYADIC_HYDRAULIC_SUPPORT_COLLAPSES_A_AND_B_TO_NUMERICAL_GUARD"
    else:
        decision="DYADIC_HYDRAULIC_SUPPORT_SWEEP_REMAINS_NUMERICALLY_DISTINGUISHABLE"

    out={
        "schema":"swap5.rom_root.s3d2.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3-D2",
        "date":"2026-09-23",
        "status":"S3D2_DYADIC_STATIC_SUPPORT_SWEEP_COMPLETE" if integrity_pass else "S3D2_INTEGRITY_FAILED",
        "decision":decision if integrity_pass else "STOP_NO_SCIENTIFIC_INTERPRETATION",
        "numerical_guard":GUARD,
        "support_order_nodes_per_layer":list(SUPPORT_NODES),
        "support_order_cm":[SUPPORT_CM[n] for n in SUPPORT_NODES],
        "integrity":{
            "pass":integrity_pass,
            "max_A_plus_B_identity_error":integrity
        },
        "cases":cases,
        "all_case_frontiers":{
            "total_functional_error":frontier_total,
            "A_threshold_nonlinearity":frontier_a,
            "B_representative_head_distribution":frontier_b,
        },
        "monotonicity":{
            "all_cases_E_nonincreasing_with_guard":all(c["E_max_abs_nonincreasing_with_guard"] for c in cases.values()),
            "all_cases_A_nonincreasing_with_guard":all(c["A_max_abs_nonincreasing_with_guard"] for c in cases.values()),
            "all_cases_B_nonincreasing_with_guard":all(c["B_max_abs_nonincreasing_with_guard"] for c in cases.values()),
        },
        "interpretation":{
            "dynamic_reduced_candidate_executed":False,
            "root_specific_state_selected":False,
            "application_tolerance_used":False,
            "note":"The frontier is a static same-state numerical distinguishability result only. It does not establish dynamic Layer-ROM sufficiency, efficiency, or application acceptance."
        },
        "scientific_firewall":{
            "reduced_candidate_response_generated":False,
            "new_root_specific_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":out["status"],"decision":out["decision"],
        "frontier_total":frontier_total,"frontier_A":frontier_a,"frontier_B":frontier_b,
        "integrity":integrity_pass,
        "monotonicity":out["monotonicity"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
