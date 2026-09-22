from __future__ import annotations

import json
import math
import os
import sys
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case
from test_gc_fixed_interface_g21m_residual_arithmetic import bind_snapshot, snapshot

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21N_PREREGISTRATION.json"
G21M=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21M_RESULT.json"
DURATION=3.90625e-5
BASE=1.0e-12

def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)

def enumerate_heads(lo:float,hi:float)->list[float]:
    require(lo < hi,f"G21N interval not ascending: {lo} {hi}")
    out=[lo]
    while out[-1] != hi:
        nxt=math.nextafter(out[-1],hi)
        require(nxt != out[-1],"G21N nextafter stalled")
        out.append(nxt)
        require(len(out)<=128,f"G21N interval exceeds 128 binary64 heads: {lo} {hi}")
    return out

def monotone(values:list[float])->bool:
    if len(values)<3:
        return True
    nondec=all(b>=a for a,b in zip(values,values[1:]))
    noninc=all(b<=a for a,b in zip(values,values[1:]))
    return nondec or noninc

def sample_interval(swap:Fgc44RealSwap,fn,case:dict)->list[dict]:
    rows=[]
    for head in enumerate_heads(float(case["low_head_m"]),float(case["high_head_m"])):
        raw=swap.g21i_solver_prefix(head,DURATION,int(case["max_iterations"]))
        backend=swap.g21g_backend_observation()
        snap=snapshot(fn)
        require(snap["n"]==4,f"G21N node count drift {case['id']}")
        require(snap["iteration"]==int(case["max_iterations"]),f"G21N prefix iteration drift {case['id']}")
        require(int(backend["backtracking_attempts"])==int(snap["backtracking"]),
                f"G21N observer/backend backtracking mismatch {case['id']}")
        rows.append({
            "head_m":head,
            "solver_status":int(backend["solver_status"]),
            "raw_result_status":int(raw["result_status"]),
            "nonlinear_iterations":int(backend["nonlinear_iterations"]),
            "backtracking":int(backend["backtracking_attempts"]),
            "residual":[float(x) for x in snap["residual"]],
            "native_sum":float(snap["native_sum"]),
            "native_fmax":float(snap["native_fmax"]),
            "node4_terms":[float(x) for x in snap["node4_terms"]],
            "node4_residual":float(snap["residual"][3]),
        })
    return rows

def delta_fractions(deltas:list[float])->list[float|None]:
    total=sum(deltas)
    if total==0.0:
        return [None for _ in deltas]
    return [d/total for d in deltas]

def analyze(case_id:str,rows:list[dict])->dict:
    require(len(rows)>=2,f"G21N empty interval {case_id}")
    transitions=[]
    status_transitions=[]
    for i,(a,b) in enumerate(zip(rows,rows[1:])):
        ta=(a["solver_status"],a["nonlinear_iterations"],a["backtracking"])
        tb=(b["solver_status"],b["nonlinear_iterations"],b["backtracking"])
        if ta!=tb:
            transitions.append({
                "left_index":i,"right_index":i+1,
                "left_head_m":a["head_m"],"right_head_m":b["head_m"],
                "left_tuple":list(ta),"right_tuple":list(tb),
                "status_changed":a["solver_status"]!=b["solver_status"],
            })
        if a["solver_status"]!=b["solver_status"]:
            status_transitions.append(i)

    groups=defaultdict(list)
    for row in rows:
        key=(row["solver_status"],row["nonlinear_iterations"],row["backtracking"])
        groups[key].append(row)

    if case_id=="B1":
        endpoint_term_deltas=[rows[-1]["node4_terms"][i]-rows[0]["node4_terms"][i] for i in range(6)]
        dominant_index=max(range(6),key=lambda i:abs(endpoint_term_deltas[i]))
        dominant_label=["storage","sink","source","root","upper_flux","lower_flux"][dominant_index]
        active=lambda r:r["native_fmax"]
        dominant=lambda r:r["node4_terms"][dominant_index]
        endpoint_residual_delta=rows[-1]["node4_residual"]-rows[0]["node4_residual"]
        endpoint_attribution={
            "node4_residual_delta":endpoint_residual_delta,
            "term_deltas":endpoint_term_deltas,
            "term_delta_fractions_of_term_sum":delta_fractions(endpoint_term_deltas),
            "term_delta_sum":sum(endpoint_term_deltas),
            "reconstruction_error":sum(endpoint_term_deltas)-endpoint_residual_delta,
            "dominant_term":dominant_label,
            "dominant_index":dominant_index,
        }
    else:
        endpoint_component_deltas=[rows[-1]["residual"][i]-rows[0]["residual"][i] for i in range(4)]
        dominant_index=max(range(4),key=lambda i:abs(endpoint_component_deltas[i]))
        dominant_label=f"residual_{dominant_index+1}"
        active=lambda r:abs(r["native_sum"])
        dominant=lambda r:r["residual"][dominant_index]
        endpoint_total_delta=rows[-1]["native_sum"]-rows[0]["native_sum"]
        endpoint_attribution={
            "total_residual_delta":endpoint_total_delta,
            "component_deltas":endpoint_component_deltas,
            "component_delta_fractions_of_total":delta_fractions(endpoint_component_deltas),
            "component_delta_sum":sum(endpoint_component_deltas),
            "reconstruction_error":sum(endpoint_component_deltas)-endpoint_total_delta,
            "dominant_term":dominant_label,
            "dominant_index":dominant_index,
        }

    group_rows=[]
    jagged=False
    for key,vals in sorted(groups.items()):
        vals=sorted(vals,key=lambda r:r["head_m"])
        active_vals=[active(r) for r in vals]
        dominant_vals=[dominant(r) for r in vals]
        a_mono=monotone(active_vals)
        d_mono=monotone(dominant_vals)
        if len(vals)>=3 and (not a_mono or not d_mono):
            jagged=True
        group_rows.append({
            "path_tuple":list(key),"count":len(vals),
            "head_min_m":vals[0]["head_m"],"head_max_m":vals[-1]["head_m"],
            "active_metric_monotone":a_mono,
            "dominant_term_monotone":d_mono,
            "active_metric_min":min(active_vals),"active_metric_max":max(active_vals),
            "dominant_term_min":min(dominant_vals),"dominant_term_max":max(dominant_vals),
        })

    path_status_switch=any(t["status_changed"] for t in transitions)
    if jagged and path_status_switch:
        classification="MIXED"
    elif jagged:
        classification="TERM_JAGGED_WITHIN_PATH"
    elif path_status_switch:
        classification="PATH_SWITCH_DOMINATED"
    else:
        classification="TERM_SMOOTH_WITHIN_PATH"

    return {
        "sample_count":len(rows),
        "first_head_m":rows[0]["head_m"],"last_head_m":rows[-1]["head_m"],
        "status_sequence":[r["solver_status"] for r in rows],
        "unique_path_tuples":[list(k) for k in sorted(groups)],
        "path_transition_count":len(transitions),
        "status_transition_count":len(status_transitions),
        "path_transitions":transitions,
        "groups":group_rows,
        "endpoint_attribution":endpoint_attribution,
        "classification":classification,
        "criterion_crossing_count":sum(
            (active(a)>BASE)!=(active(b)>BASE) for a,b in zip(rows,rows[1:])
        ),
    }

def endpoint_check(case_id:str,rows:list[dict],parent:dict)->None:
    by={r["id"]:r for r in parent["cases"]}
    if case_id=="B1":
        fail=by["B1_STATUS6"]; passed=by["B1_STATUS0"]
        require(rows[0]["head_m"]==float(fail["head_m"]) and rows[-1]["head_m"]==float(passed["head_m"]),
                "G21N B1 endpoint heads drift")
        require(rows[0]["native_sum"]==float(fail["native_sum"]),"G21N B1 fail sum drift")
        require(rows[0]["native_fmax"]==float(fail["native_fmax"]),"G21N B1 fail fmax drift")
        require(rows[-1]["native_sum"]==float(passed["native_sum"]),"G21N B1 pass sum drift")
        require(rows[-1]["native_fmax"]==float(passed["native_fmax"]),"G21N B1 pass fmax drift")
    else:
        passed=by["B2_STATUS0"]; fail=by["B2_STATUS6"]
        require(rows[0]["head_m"]==float(passed["head_m"]) and rows[-1]["head_m"]==float(fail["head_m"]),
                "G21N B2 endpoint heads drift")
        require(rows[0]["native_sum"]==float(passed["native_sum"]),"G21N B2 pass sum drift")
        require(rows[-1]["native_sum"]==float(fail["native_sum"]),"G21N B2 fail sum drift")

def main()->None:
    p=json.loads(PREREG.read_text())
    parent=json.loads(G21M.read_text())
    require(p["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21N preregistration drift")
    require(parent["decision"]=="QUALIFIED_FINAL_AGGREGATION_NOT_CAUSAL_AT_CAPTURED_TERM_LEVEL","G21N parent drift")

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21N missing research library")
    swap=Fgc44RealSwap(lib)
    fn=bind_snapshot(swap)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21N dirty origin")

    output={}
    all_rows={}
    for case in p["frozen_intervals"]:
        cid=str(case["id"])
        rows=sample_interval(swap,fn,case)
        endpoint_check(cid,rows,parent)
        analysis=analyze(cid,rows)
        all_rows[cid]=rows
        output[cid]=analysis
        print("FGC44_G21N_INTERVAL_JSON="+json.dumps({
            "id":cid,**analysis
        },sort_keys=True,separators=(",",":")))

    require(output["B1"]["sample_count"]<=128 and output["B2"]["sample_count"]<=128,
            "G21N enumeration cap violated")

    # Normal participant topology remains a separate non-authoritative postcondition.
    endpoint_cases=[
        ("B1_STATUS6",-0.7150100297648301,6),
        ("B1_STATUS0",-0.715010029764824,0),
        ("B2_STATUS0",-0.715010029764793,0),
        ("B2_STATUS6",-0.7150100297647868,6),
    ]
    swap.g16_begin_session()
    post=[]
    for cid,head,expected in endpoint_cases:
        obs=swap.g16_observe_head(head)
        status=int(obs["participant_status"])
        require(status==expected,f"G21N G16 endpoint drift {cid}: {status}")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G21N authority drift {cid}")
        post.append(status)
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21N G16 accounting drift {counts}")
    swap.g16_end_session()

    summary={
        "b1_classification":output["B1"]["classification"],
        "b2_classification":output["B2"]["classification"],
        "b1_sample_count":output["B1"]["sample_count"],
        "b2_sample_count":output["B2"]["sample_count"],
        "b1_endpoint_attribution":output["B1"]["endpoint_attribution"],
        "b2_endpoint_attribution":output["B2"]["endpoint_attribution"],
        "b1_path_transition_count":output["B1"]["path_transition_count"],
        "b2_path_transition_count":output["B2"]["path_transition_count"],
        "b1_status_transition_count":output["B1"]["status_transition_count"],
        "b2_status_transition_count":output["B2"]["status_transition_count"],
        "saved_config_postprobe_status_vector":post,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_source_change":"NONE",
    }
    print("FGC44_G21N_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21N_EXECUTION=PASS")

if __name__=="__main__":
    main()
