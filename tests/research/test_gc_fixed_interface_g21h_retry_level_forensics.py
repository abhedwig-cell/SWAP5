from __future__ import annotations

import json
import math
import os
import re
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21H_PREREGISTRATION.json"
G21G=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21G_RESULT.json"
TX_SOURCE=ROOT/"src"/"transaction"/"mod_transaction_reference.f90"
BRIDGE_SOURCE=ROOT/"tests"/"fgc"/"support"/"mod_fgc44_real_swap_c_bridge.f90"

SW_SOLVE_CONVERGED=1


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_audit()->dict[str,object]:
    tx=TX_SOURCE.read_text()
    bridge=BRIDGE_SOURCE.read_text()
    require(re.search(r"attempt_dt\s*=\s*attempt_dt\s*\*\s*policy%retry_scale",tx) is not None,
            "G21H retry duration source drift")
    require("if (retry_index >= policy%max_retries)" in tx,"G21H retry exhaustion source drift")
    marker='integer(c_int) function fgc44_g21h_isolated_attempt_c'
    start=bridge.lower().find(marker)
    require(start>=0,"G21H isolated probe missing")
    end=bridge.lower().find("end function fgc44_g21h_isolated_attempt_c",start)
    require(end>start,"G21H isolated probe end missing")
    block=bridge[start:end]
    require("probe_config=corrector_config" in block,"G21H probe does not copy numerical config")
    require("probe_config%transaction%max_retries=0" in block,"G21H probe does not isolate one transaction attempt")
    require("corrector_backend%run_trial" in block,"G21H probe does not use existing backend")
    require("corrector_backend%discard_trial_candidate" in block,"G21H probe does not discard raw candidate")
    require("corrector_config%transaction%max_retries=" not in block,
            "G21H probe mutates saved corrector retry policy")
    return {
        "retry_duration_update":"attempt_dt*=retry_scale",
        "retry_exhaustion":"retry_index>=max_retries",
        "probe_config_copy":True,
        "probe_max_retries":0,
        "saved_corrector_config_mutation":False,
    }


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21G.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21H","wrong G21H preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21H preregistration not frozen")
    require(parent["decision"]=="QUALIFIED_DETERMINISTIC_RETRY_SOLVER_BIFURCATION",
            "G21H parent classification drift")

    base=float(prereg["frozen_transaction"]["requested_duration_day"])
    scale=float(prereg["frozen_transaction"]["retry_scale"])
    max_retries=int(prereg["frozen_transaction"]["max_retries"])
    durations=[float(x) for x in prereg["frozen_transaction"]["retry_durations_day"]]
    expected_durations=[base*(scale**i) for i in range(max_retries+1)]
    require(durations==expected_durations,"G21H retry duration ladder drift")

    lower=-0.7150100297648363
    upper=-0.7150100297646383
    scan=[float(x) for x in np.linspace(lower,upper,33,dtype=np.float64)]
    boundaries=prereg["frozen_boundaries"]
    frozen_heads=[]
    for b in boundaries:
        for side in ("left","right"):
            row=b[side]
            idx=int(row["index"])
            head=float(row["head_m"])
            require(head==scan[idx],f"G21H frozen binary64 head drift {b['id']} {side}")
            frozen_heads.append((str(b["id"]),side,idx,head,int(row["status"])))

    source=source_audit()
    print("FGC44_G21H_SOURCE_AUDIT_JSON="+json.dumps(source,sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21H missing FGC44 library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21H dirty origin")
    require(not swap.g15_has_live_candidate(),"G21H participant unexpectedly live at origin")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21H preflight unexpectedly ready at origin")

    rows=[]
    per_head={}
    for boundary_id,side,index,head,parent_status in frozen_heads:
        levels=[]
        for level,duration in enumerate(durations):
            before=swap.state()
            probe=swap.g21h_isolated_attempt(head,duration)
            backend=swap.g21g_backend_observation()
            after=swap.state()
            require(before==origin and after==origin,
                    f"G21H isolated probe mutated accepted authority {boundary_id} {side} level={level}")
            require(not swap.g15_has_live_candidate(),
                    f"G21H isolated probe leaked participant candidate {boundary_id} {side} level={level}")
            require(not swap.swap_preflight() and not swap.ledger_preflight(),
                    f"G21H isolated probe acquired publication authority {boundary_id} {side} level={level}")
            require(int(probe["attempts"])==1,
                    f"G21H isolated probe did not execute exactly one transaction attempt {boundary_id} {side} level={level}")
            require(int(probe["retries"])==0,
                    f"G21H isolated probe retried despite max_retries=0 {boundary_id} {side} level={level}")
            require(bool(backend["solver_executed"]),
                    f"G21H solver did not execute {boundary_id} {side} level={level}")
            row={
                "boundary":boundary_id,"side":side,"index":index,"head_m":head,"head_hex":head.hex(),
                "parent_status":parent_status,"retry_level":level,"duration_day":duration,
                "probe":probe,"backend":backend,
            }
            rows.append(row)
            levels.append(row)
        per_head[(boundary_id,side)]=levels
        print("FGC44_G21H_HEAD_JSON="+json.dumps({
            "boundary":boundary_id,"side":side,"index":index,"head_m":head,
            "parent_status":parent_status,
            "solver_status_by_level":[int(x["backend"]["solver_status"]) for x in levels],
            "temporal_rejections_by_level":[int(x["probe"]["temporal_rejections"]) for x in levels],
            "solver_rejections_by_level":[int(x["probe"]["solver_rejections"]) for x in levels],
            "normalized_indicator_by_level":[float(x["backend"]["temporal_normalized_indicator"]) for x in levels],
        },sort_keys=True,separators=(",",":")))

    exact_boundaries=0
    partial_boundaries=0
    details=[]
    for b in boundaries:
        bid=str(b["id"])
        status6_side="left" if int(b["left"]["status"])==6 else "right"
        status0_side="right" if status6_side=="left" else "left"
        fail=per_head[(bid,status6_side)]
        ok=per_head[(bid,status0_side)]

        earlier_solver_converged=all(int(x["backend"]["solver_status"])==SW_SOLVE_CONVERGED for x in fail[:8])
        earlier_temporal_rejected=all(
            int(x["probe"]["solver_rejections"])==0 and
            int(x["probe"]["temporal_rejections"])==1 and
            bool(x["backend"]["temporal_certificate_available"])
            for x in fail[:8]
        )
        level8_fail=(
            int(fail[8]["backend"]["solver_status"])!=SW_SOLVE_CONVERGED and
            int(fail[8]["probe"]["solver_rejections"])==1 and
            int(fail[8]["probe"]["temporal_rejections"])==0 and
            not bool(fail[8]["backend"]["temporal_certificate_available"])
        )
        adjacent_level8_converged=int(ok[8]["backend"]["solver_status"])==SW_SOLVE_CONVERGED

        exact=earlier_solver_converged and earlier_temporal_rejected and level8_fail and adjacent_level8_converged
        partial=(level8_fail != (int(ok[8]["backend"]["solver_status"])!=SW_SOLVE_CONVERGED)) or earlier_temporal_rejected
        exact_boundaries+=int(exact)
        partial_boundaries+=int(partial)
        details.append({
            "boundary":bid,
            "status6_side":status6_side,
            "status0_side":status0_side,
            "status6_levels_0_7_solver_converged":earlier_solver_converged,
            "status6_levels_0_7_temporal_rejected":earlier_temporal_rejected,
            "status6_level8_solver_failed":level8_fail,
            "status0_level8_solver_converged":adjacent_level8_converged,
            "exact_retry_sequence":exact,
        })

    if exact_boundaries==len(boundaries):
        classification="ISOLATED_FINAL_RETRY_SOLVER_BIFURCATION_CONFIRMED"
    elif partial_boundaries>0:
        classification="ISOLATED_RETRY_SEQUENCE_PARTIAL_SUPPORT"
    else:
        classification="TRANSACTION_HISTORY_CONTEXT_REQUIRED"

    summary={
        "classification":classification,
        "boundary_count":len(boundaries),
        "exact_boundaries":exact_boundaries,
        "partial_boundaries":partial_boundaries,
        "retry_durations_day":durations,
        "details":details,
        "rows":rows,
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_policy_claim":"NONE",
    }
    print("FGC44_G21H_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21H_RETRY_LEVEL_FORENSICS=PASS")
    print("GC_FIXED_INTERFACE_G21H_EXECUTION=PASS")


if __name__=="__main__":
    main()
