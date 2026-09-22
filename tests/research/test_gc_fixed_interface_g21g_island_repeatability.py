from __future__ import annotations

import json
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

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21G_PREREGISTRATION.json"
G21F=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21F_RESULT.json"
TX_SOURCE=ROOT/"src"/"transaction"/"mod_transaction_reference.f90"
CANON_SOURCE=ROOT/"src"/"runtime"/"mod_canonical_contracts.f90"
RUNTIME_SOURCE=ROOT/"src"/"runtime"/"mod_canonical_interval_runtime.f90"
BRIDGE_SOURCE=ROOT/"tests"/"fgc"/"support"/"mod_fgc44_real_swap_c_bridge.f90"

SW_SOLVE_CONVERGED=1

PARTICIPANT_KEYS=(
    "participant_status","result_status","completed","candidate_ready","attempts","retries",
    "solver_rejections","temporal_rejections","temporal_unavailable_rejections",
    "mass_rejections","accepted_substeps","internal_retries",
)
BACKEND_KEYS=(
    "solver_executed","solver_status","nonlinear_iterations","jacobian_builds","linear_solves",
    "backtracking_attempts","alternative_solver_calls","internal_retries",
    "temporal_indicator_enabled","temporal_previous_derivative_available",
    "temporal_current_derivative_available","temporal_indicator_status",
    "temporal_indicator_available","temporal_head_budget_supplied","temporal_head_budget_valid",
    "temporal_certificate_available","temporal_head_inf_bound","temporal_head_budget",
    "temporal_normalized_indicator",
)


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_audit()->dict[str,object]:
    tx=TX_SOURCE.read_text()
    canon=CANON_SOURCE.read_text()
    runtime=RUNTIME_SOURCE.read_text()
    bridge=BRIDGE_SOURCE.read_text()

    require(re.search(r"retry_scale\s*=\s*0\.5_real64",tx) is not None,"G21G retry_scale source drift")
    require(re.search(r"max_retries\s*=\s*8",tx) is not None,"G21G max_retries source drift")
    require("if (.not. full_outcome%solver_ok)" in tx,"G21G missing full solver rejection branch")
    require("result%solver_rejections = result%solver_rejections + 1" in tx,"G21G solver rejection counter source drift")
    require("result%status = TX_STATUS_RETRY_EXHAUSTED" in tx,"G21G retry exhaustion source drift")
    require("CANONICAL_STATUS_TRANSACTION_FAILED = 2" in canon,"G21G canonical transaction status source drift")
    require("result%status = CANONICAL_STATUS_TRANSACTION_FAILED" in runtime,"G21G canonical transaction mapping drift")

    marker="integer(c_int) function fgc44_g21g_backend_observation_c"
    start=bridge.lower().find(marker)
    require(start>=0,"G21G bridge accessor missing")
    end=bridge.lower().find("end function fgc44_g21g_backend_observation_c",start)
    require(end>start,"G21G bridge accessor end missing")
    block=bridge[start:end]
    require("corrector_backend%observation()" in block,"G21G accessor does not read backend observation")
    forbidden=[x for x in ("run_trial","commit_trial_candidate","discard_trial_candidate","participant%","tangent_observation_service%") if x in block]
    require(not forbidden,f"G21G accessor contains mutable/executing calls {forbidden}")
    require("pred%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE" in bridge,
            "G21G FGC44 temporal-mode binding drift")
    require("pred%transaction%retry_scale=0.5_real64" in bridge,
            "G21G FGC44 retry-scale binding drift")
    require("pred%transaction%max_retries=8" in bridge,
            "G21G FGC44 retry-budget binding drift")
    require("corr=pred" in bridge,
            "G21G FGC44 corrector no longer inherits frozen transaction policy")
    return {
        "canonical_transaction_failed_status":2,
        "max_retries":8,
        "retry_scale":0.5,
        "bridge_accessor_observation_copy":True,
        "bridge_forbidden_calls":forbidden,
        "fgc44_temporal_mode":"TX_TEMPORAL_MODEL_CERTIFICATE",
        "fgc44_retry_scale":0.5,
        "fgc44_max_retries":8,
    }


def islands(statuses:list[int])->list[dict[str,int]]:
    out=[]
    start=0
    for i in range(1,len(statuses)+1):
        if i==len(statuses) or statuses[i]!=statuses[start]:
            out.append({"status":statuses[start],"start_index":start,"end_index":i-1})
            start=i
    return out


def key_snapshot(participant:dict[str,object],backend:dict[str,object])->dict[str,object]:
    return {
        "participant":{k:participant[k] for k in PARTICIPANT_KEYS},
        "backend":{k:backend[k] for k in BACKEND_KEYS},
    }


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21F.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21G","wrong G21G preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21G preregistration not frozen")
    expected=[int(x) for x in prereg["frozen_scan"]["g21f_statuses"]]
    require(expected==[int(x) for x in parent["coarse_scan"]["statuses"]],"G21G G21F status authority drift")
    require(int(prereg["frozen_scan"]["expected_island_count"])==6,"G21G expected island count drift")
    require(int(prereg["frozen_scan"]["expected_transition_count"])==5,"G21G expected transition count drift")
    source=source_audit()
    print("FGC44_G21G_SOURCE_AUDIT_JSON="+json.dumps(source,sort_keys=True,separators=(",",":")))

    lower=float(prereg["frozen_scan"]["lower_head_m"])
    upper=float(prereg["frozen_scan"]["upper_head_m"])
    heads=[float(x) for x in np.linspace(lower,upper,33,dtype=np.float64)]
    require(len(set(heads))==33,"G21G frozen head vector not unique")

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21G missing FGC44 library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21G dirty origin")
    require(swap.g15_trial_call_count()==0,"G21G ordinary trial counter dirty")

    passes=[]
    status6_signatures=[]
    physical_repeatable=True
    previous_by_head=None

    for pass_id in (1,2,3):
        swap.g16_begin_session()
        require(swap.g16_counts()==(0,0,0,0),f"G21G pass {pass_id} dirty service counters")
        rows=[]
        current_by_head={}
        for index,head in enumerate(heads):
            obs=swap.g16_observe_head(head)
            back=swap.g21g_backend_observation()
            require(bool(obs["available"]),f"G21G unavailable participant observation pass={pass_id} index={index}")
            require(int(obs["participant_status"]) in (0,6),f"G21G unexpected status pass={pass_id} index={index}")
            require(bool(back["solver_executed"]),f"G21G physical solver not executed pass={pass_id} index={index}")
            require(not swap.g15_has_live_candidate(),"G21G live candidate leaked")
            require(swap.state()==origin,"G21G accepted authority mutated")
            require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21G publication authority leaked")
            row={
                "pass":pass_id,"index":index,"head_m":head,"head_hex":head.hex(),
                "participant":{k:obs[k] for k in PARTICIPANT_KEYS},
                "backend":{k:back[k] for k in BACKEND_KEYS},
            }
            rows.append(row)
            current_by_head[head.hex()]=key_snapshot(obs,back)

            if int(obs["participant_status"])==6:
                sig={
                    "attempts":int(obs["attempts"]),"retries":int(obs["retries"]),
                    "temporal_rejections":int(obs["temporal_rejections"]),
                    "solver_rejections":int(obs["solver_rejections"]),
                    "mass_rejections":int(obs["mass_rejections"]),
                    "temporal_unavailable_rejections":int(obs["temporal_unavailable_rejections"]),
                    "accepted_substeps":int(obs["accepted_substeps"]),
                    "final_solver_status":int(back["solver_status"]),
                }
                status6_signatures.append(sig)

        counts=swap.g16_counts()
        require(counts==(33,33,0,33),f"G21G pass {pass_id} service accounting {counts}")
        vector=[int(r["participant"]["participant_status"]) for r in rows]
        isl=islands(vector)
        print("FGC44_G21G_PASS_JSON="+json.dumps({
            "pass":pass_id,"statuses":vector,"islands":isl,"counts":list(counts)
        },sort_keys=True,separators=(",",":")))
        require(all(x in (0,6) for x in vector),"G21G status outside 0/6")
        passes.append({"pass":pass_id,"statuses":vector,"islands":isl,"rows":rows,"counts":list(counts)})
        if previous_by_head is not None and current_by_head!=previous_by_head:
            physical_repeatable=False
        previous_by_head=current_by_head
        swap.g16_end_session()
        require(swap.g16_counts()==(0,0,0,0),f"G21G pass {pass_id} service cache not cleared")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G21G pass {pass_id} authority changed")

    topology_repeatable=all(p["statuses"]==expected for p in passes) and all(
        p["islands"]==passes[0]["islands"] for p in passes[1:]
    )
    expected_islands=islands(expected)
    require(len(expected_islands)==6,"G21G frozen vector no longer has six islands")
    require(sum(1 for a,b in zip(expected[:-1],expected[1:]) if a!=b)==5,"G21G frozen transition count drift")

    status6_signature_exact=all(
        s["attempts"]==9 and s["retries"]==8 and s["temporal_rejections"]==8 and
        s["solver_rejections"]==1 and s["mass_rejections"]==0 and
        s["temporal_unavailable_rejections"]==0 and s["accepted_substeps"]==0
        for s in status6_signatures
    )
    status6_final_nonconverged=all(s["final_solver_status"]!=SW_SOLVE_CONVERGED for s in status6_signatures)

    status0_rows=[r for p in passes for r in p["rows"] if int(r["participant"]["participant_status"])==0]
    status0_completed=all(
        bool(r["participant"]["completed"]) and bool(r["participant"]["candidate_ready"]) and
        int(r["participant"]["solver_rejections"])==0 and
        int(r["backend"]["solver_status"])==SW_SOLVE_CONVERGED
        for r in status0_rows
    )

    if not topology_repeatable:
        classification="NONDETERMINISTIC_ISLAND_TOPOLOGY"
    elif status6_signature_exact and status6_final_nonconverged and status0_completed:
        classification="DETERMINISTIC_RETRY_SOLVER_BIFURCATION"
    elif topology_repeatable:
        classification="DETERMINISTIC_ISLANDS_MIXED_EXECUTION_CAUSE"
    else:
        classification="SOURCE_OR_INSTRUMENTATION_UNRESOLVED"

    unique_status6_signatures=[]
    for sig in status6_signatures:
        if sig not in unique_status6_signatures:
            unique_status6_signatures.append(sig)

    status0_execution_classes=[]
    for r in status0_rows:
        sig={
            "accepted_substeps":int(r["participant"]["accepted_substeps"]),
            "attempts":int(r["participant"]["attempts"]),
            "temporal_rejections":int(r["participant"]["temporal_rejections"]),
            "final_solver_status":int(r["backend"]["solver_status"]),
            "final_solver_nonlinear_iterations":int(r["backend"]["nonlinear_iterations"]),
            "final_solver_internal_retries":int(r["backend"]["internal_retries"]),
            "temporal_indicator_status":int(r["backend"]["temporal_indicator_status"]),
            "temporal_certificate_available":bool(r["backend"]["temporal_certificate_available"]),
        }
        if sig not in status0_execution_classes:
            status0_execution_classes.append(sig)

    summary={
        "classification":classification,
        "topology_repeatable":topology_repeatable,
        "full_observation_repeatable_exactly":physical_repeatable,
        "full_observation_repeatability_is_diagnostic_not_classification_gate":True,
        "expected_statuses":expected,
        "islands":expected_islands,
        "status6_signature_exact":status6_signature_exact,
        "status6_final_solver_nonconverged":status6_final_nonconverged,
        "status0_final_solver_converged_and_completed":status0_completed,
        "unique_status6_signatures":unique_status6_signatures,
        "status0_execution_classes":status0_execution_classes,
        "passes":passes,
        "accepted_state_ledger_mutation":0,
        "ordinary_publication_trials":swap.g15_trial_call_count(),
        "production_policy_claim":"NONE",
    }
    require(swap.g15_trial_call_count()==0,"G21G ordinary publication path used")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21G final authority changed")
    print("FGC44_G21G_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21G_REPEATABILITY=PASS")
    print("GC_FIXED_INTERFACE_G21G_EXECUTION=PASS")


if __name__=="__main__":
    main()
