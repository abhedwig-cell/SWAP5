from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

G13=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G13_RESULT.json"
G09D=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G09D_RESULT.json"
SERVICE_SOURCE=ROOT/"src"/"runtime"/"mod_fmr_groundwater_swap_tangent_observation_service.f90"

REL_TOL=0.05
Q_TOL=1.0e-18
CLASS_FIELDS=(
    "accepted_substeps","attempts","retries","solver_rejections",
    "temporal_rejections","internal_retries","min_substep","max_substep",
)
OBS_FIELDS=(
    "available","participant_status","q_available","q_swap_m_per_s",
    "result_status","completed","candidate_ready","transaction_calls",
    "accepted_substeps","attempts","retries","trial_rollbacks",
    "solver_rejections","temporal_rejections","temporal_unavailable_rejections",
    "mass_rejections","internal_retries","min_substep","max_substep",
)


def require(value:bool,message:str)->None:
    if not value:
        raise AssertionError(message)


def observation_equal(a:dict[str,object],b:dict[str,object])->bool:
    return all(a[k]==b[k] for k in OBS_FIELDS)


def execution_class(obs:dict[str,object])->tuple[object,...]|None:
    if int(obs["participant_status"])!=0:
        return None
    if int(obs["result_status"])!=0 or not bool(obs["completed"]) or not bool(obs["candidate_ready"]):
        return None
    return tuple(obs[x] for x in CLASS_FIELDS)


def candidate(center:dict[str,object],samples:dict[int,dict[str,object]],d:float)->dict[str,object]|None:
    q0=float(center["q_swap_m_per_s"])
    cm=execution_class(samples[-1]); cp=execution_class(samples[1])
    if cm is not None and cp is not None and cm==cp:
        slope=(float(samples[1]["q_swap_m_per_s"])-float(samples[-1]["q_swap_m_per_s"]))/(2.0*d)
        mode="CENTRAL_PAIR_CLASS"
    else:
        c0=execution_class(center)
        cm1=execution_class(samples[-1]); cm2=execution_class(samples[-2])
        cp1=execution_class(samples[1]); cp2=execution_class(samples[2])
        if c0 is not None and c0==cm1==cm2:
            slope=(3.0*q0-4.0*float(samples[-1]["q_swap_m_per_s"])+float(samples[-2]["q_swap_m_per_s"]))/(2.0*d)
            mode="BACKWARD_CENTER_CLASS"
        elif c0 is not None and c0==cp1==cp2:
            slope=(-3.0*q0+4.0*float(samples[1]["q_swap_m_per_s"])-float(samples[2]["q_swap_m_per_s"]))/(2.0*d)
            mode="FORWARD_CENTER_CLASS"
        else:
            return None
    if not math.isfinite(slope) or slope>=0.0:
        return None
    return {"scale_m":d,"mode":mode,"slope_per_s":float(slope)}


def source_audit()->dict[str,object]:
    source=SERVICE_SOURCE.read_text()
    lowered=source.lower()
    forbidden=(
        "backend%run_trial",
        "backend%commit_trial_candidate",
        "backend%discard_trial_candidate",
        "groundwater_interface_mass_ledger",
        "mod_modflow6_linear_response_backend",
        "hcof",
        "rhs",
    )
    for token in forbidden:
        require(token not in lowered,f"G16 service source contains forbidden ownership/policy token: {token}")
    required=(
        "participant%trial_from_origin",
        "participant%observe_last_trial",
        "participant%discard_candidate",
    )
    for token in required:
        require(token in lowered,f"G16 service source missing required participant delegation: {token}")
    require("procedure, public :: commit" not in lowered,"G16 service exposes commit authority")
    require("procedure, public :: publication" not in lowered,"G16 service exposes publication authority")
    return {
        "direct_backend_run_calls":0,
        "direct_backend_commit_calls":0,
        "direct_backend_discard_calls":0,
        "ledger_dependencies":0,
        "hcof_rhs_dependencies":0,
        "participant_trial_delegation":True,
        "participant_observation_delegation":True,
        "participant_cleanup_delegation":True,
    }


def run_state(
    swap:Fgc44RealSwap,
    authority:dict[str,object],
    expected:dict[str,object],
    state_id:str,
)->dict[str,object]:
    duration=float(authority["duration_day"])
    qbot=float(authority["qbot_cm_per_day"])
    center_dh=float(authority["dh_m"])
    scales=[float(x["scale_m"]) for x in authority["e3"]["candidates"]]

    _,_,href=swap.initialize_configured(duration,qbot)
    origin=swap.state()
    require(origin==(0,0.0,0,0.0),f"{state_id} dirty G16 origin {origin}")
    require(not swap.g15_has_live_candidate(),f"{state_id} live candidate before G16 session")
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),f"{state_id} nonzero G16 counters at session start")

    first_observations:dict[str,dict[str,object]]={}
    max_q_diff=0.0

    def observe(head:float)->dict[str,object]:
        nonlocal max_q_diff
        before=swap.g16_counts()
        obs=swap.g16_observe_head(head)
        after=swap.g16_counts()

        require(after[0]==before[0]+1,f"{state_id} logical request count did not increment")
        require(not swap.g15_has_live_candidate(),f"{state_id} G16 returned live diagnostic candidate")
        require(swap.state()==origin,f"{state_id} G16 observation changed accepted/ledger authority")

        key=head.hex()
        if after[1]==before[1]+1:
            require(after[2]==before[2],f"{state_id} cache miss incremented hit counter")
            direct=swap.g15_last_trial_observation()
            require(observation_equal(obs,direct),f"{state_id} service observation differs from participant-owned same trial")
            first_observations[key]=obs
        else:
            require(after[1]==before[1],f"{state_id} G16 trial count changed unexpectedly")
            require(after[2]==before[2]+1,f"{state_id} cache hit count did not increment")
            require(key in first_observations,f"{state_id} cache hit without earlier miss")
            require(observation_equal(obs,first_observations[key]),f"{state_id} cached observation drift")

        require(bool(obs["available"]),f"{state_id} unavailable G16 observation")
        require(bool(obs["q_available"])==(int(obs["participant_status"])==0),
                f"{state_id} q authority mismatch")
        if bool(obs["q_available"]):
            max_q_diff=max(max_q_diff,abs(float(obs["q_swap_m_per_s"])-float(first_observations[key]["q_swap_m_per_s"])))
        return obs

    center_head=href+center_dh
    center=observe(center_head)
    require(execution_class(center) is not None,f"{state_id} center unavailable")

    previous=None
    selected=None
    confirming=None
    rel=None
    scale_count=0
    for d in scales:
        scale_count+=1
        samples={m:observe(center_head+m*d) for m in (-2,-1,0,1,2)}
        current=candidate(center,samples,d)
        if previous is not None and current is not None:
            s0=float(previous["slope_per_s"]); s1=float(current["slope_per_s"])
            this_rel=abs(s0-s1)/max(abs(s0),abs(s1))
            if this_rel<=REL_TOL:
                selected=previous
                confirming=current
                rel=this_rel
                break
        previous=current

    require(selected is not None and confirming is not None,f"{state_id} G16 E3 observation stream unavailable")
    requests,trials,hits,cached=swap.g16_counts()
    expected_requests=1+5*scale_count
    require(requests==expected_requests,f"{state_id} request count {requests} != {expected_requests}")
    require(trials==len(first_observations),f"{state_id} participant trial count/cache misses mismatch")
    require(cached==trials,f"{state_id} cache size/trial count mismatch")
    require(hits==requests-trials,f"{state_id} cache hit accounting mismatch")
    require(trials==int(expected["streaming_unique_heads"]),f"{state_id} unique-head trial count mismatch")
    require(scale_count==int(expected["streaming_scale_count"]),f"{state_id} scale-count mismatch")
    require(selected["scale_m"]==float(expected["selected_scale_m"]),f"{state_id} selected scale mismatch")
    require(selected["mode"]==str(expected["selected_mode"]),f"{state_id} selected mode mismatch")
    require(math.isclose(float(selected["slope_per_s"]),float(expected["selected_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
            f"{state_id} selected slope mismatch")
    require(confirming["scale_m"]==float(expected["confirming_scale_m"]),f"{state_id} confirming scale mismatch")
    require(confirming["mode"]==str(expected["confirming_mode"]),f"{state_id} confirming mode mismatch")
    require(math.isclose(float(confirming["slope_per_s"]),float(expected["confirming_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
            f"{state_id} confirming slope mismatch")

    before_end=swap.state()
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),f"{state_id} G16 end_session did not clear cache/counters")
    require(swap.state()==before_end==origin,f"{state_id} end_session changed authority")

    return {
        "state_id":state_id,
        "logical_requests":requests,
        "participant_trials":trials,
        "cache_hits":hits,
        "cached_heads":cached,
        "scale_count":scale_count,
        "selected_scale_m":selected["scale_m"],
        "selected_mode":selected["mode"],
        "selected_slope_per_s":selected["slope_per_s"],
        "confirming_scale_m":confirming["scale_m"],
        "confirming_mode":confirming["mode"],
        "confirming_slope_per_s":confirming["slope_per_s"],
        "relative_difference":rel,
        "max_same_trial_q_diff_m_per_s":max_q_diff,
    }


def session_reset_gate(swap:Fgc44RealSwap)->dict[str,object]:
    _,_,href=swap.initialize_configured(1.0e-4,1.0e-6)
    origin=swap.state()
    swap.g16_begin_session()
    first=swap.g16_observe_head(href)
    require(swap.g16_counts()==(1,1,0,1),"G16 session reset control first request mismatch")
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),"G16 end_session did not clear first reset control")
    swap.g16_begin_session()
    second=swap.g16_observe_head(href)
    require(swap.g16_counts()==(1,1,0,1),"G16 repeated numeric head reused cross-session cache")
    require(observation_equal(first,second),"G16 repeated-head fresh-session observation drift")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G16 reset gate changed authority")
    swap.g16_end_session()
    return {
        "same_numeric_head":href,
        "first_session_counts":[1,1,0,1],
        "second_session_counts":[1,1,0,1],
        "cross_session_cache_reuse":False,
    }


def main()->None:
    audit=source_audit()
    print("FGC44_G16_SOURCE_AUDIT_JSON="+json.dumps(audit,sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"missing FGC44 SWAP bridge")
    g13=json.loads(G13.read_text())
    g09=json.loads(G09D.read_text())
    expected={x["state_id"]:x for x in g13["state_results"] if x["carrier"]=="FGC44"}
    authority={f"{x['case_id']}_{x['side']}":x for x in g09["estimator_results"]}
    require(set(expected)==set(authority),"G16 frozen FGC44 authority mismatch")

    swap=Fgc44RealSwap(lib)
    rows=[]
    for state_id,item in authority.items():
        row=run_state(swap,item,expected[state_id],state_id)
        rows.append(row)
        print("FGC44_G16_STATE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    total_requests=sum(int(x["logical_requests"]) for x in rows)
    total_trials=sum(int(x["participant_trials"]) for x in rows)
    total_hits=sum(int(x["cache_hits"]) for x in rows)
    total_cached=sum(int(x["cached_heads"]) for x in rows)
    require(total_requests==103,f"G16 logical requests {total_requests} != 103")
    require(total_trials==62,f"G16 participant trials {total_trials} != 62")
    require(total_hits==41,f"G16 cache hits {total_hits} != 41")
    require(total_cached==62,f"G16 cached-head total {total_cached} != 62")

    reset=session_reset_gate(swap)
    print("FGC44_G16_SESSION_RESET_JSON="+json.dumps(reset,sort_keys=True,separators=(",",":")))

    summary={
        "state_count":len(rows),
        "logical_observe_requests":total_requests,
        "participant_trials":total_trials,
        "cache_hits":total_hits,
        "streaming_unique_heads":total_cached,
        "additional_backend_runs_from_cache_or_observation":0,
        "same_trial_observation_equivalence":"PASS",
        "g13_e3_decision_equivalence":"PASS",
        "immutable_origin_authority":"PASS",
        "cross_session_cache_isolation":"PASS",
        "source_ownership_audit":"PASS",
    }
    print("FGC44_G16_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G16_CACHE_ACCOUNTING=PASS")
    print("GC_FIXED_INTERFACE_G16_E3_OBSERVATION_EQUIVALENCE=PASS")
    print("GC_FIXED_INTERFACE_G16_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G16_EXECUTION=PASS")


if __name__=="__main__":
    main()
