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

REL_TOL=0.05
Q_TOL=1.0e-18
CLASS_FIELDS=(
    "accepted_substeps","attempts","retries","solver_rejections",
    "temporal_rejections","internal_retries","min_substep","max_substep",
)
OBS_COMPARE_FIELDS=(
    "participant_status","result_status","completed","candidate_ready",
    "transaction_calls","accepted_substeps","attempts","retries",
    "trial_rollbacks","solver_rejections","temporal_rejections",
    "temporal_unavailable_rejections","mass_rejections","internal_retries",
    "min_substep","max_substep",
)


def require(value:bool,message:str)->None:
    if not value:
        raise AssertionError(message)


def initialize(swap:Fgc44RealSwap,duration:float,qbot:float)->tuple[float,tuple[int,float,int,float]]:
    _,_,href=swap.initialize_configured(duration,qbot)
    origin=swap.state()
    require(origin==(0,0.0,0,0.0),f"dirty G15 origin {origin}")
    require(swap.g15_trial_call_count()==0,"G15 trial counter did not reset")
    require(not swap.g15_has_live_candidate(),"G15 initialized with live candidate")
    first=swap.g15_last_trial_observation()
    require(not first["available"],"G15 observation not reset by origin capture")
    return href,origin


def observation_equal(a:dict[str,object],b:dict[str,object])->bool:
    return all(a[k]==b[k] for k in a)


def compare_to_g14(obs:dict[str,object],fused:dict[str,object],tag:str)->float:
    require(bool(obs["available"]),f"{tag} observation unavailable")
    require(bool(obs["q_available"])==(int(obs["participant_status"])==0),f"{tag} q availability mismatch")
    for field in OBS_COMPARE_FIELDS:
        a=obs[field]; b=fused[field]
        if field in ("completed","candidate_ready"):
            require(bool(a)==bool(b),f"{tag} field mismatch {field}: {a} != {b}")
        elif field in ("min_substep","max_substep"):
            require(float(a)==float(b),f"{tag} field mismatch {field}: {a} != {b}")
        else:
            require(int(a)==int(b),f"{tag} field mismatch {field}: {a} != {b}")
    qdiff=0.0
    if bool(obs["q_available"]):
        qdiff=abs(float(obs["q_swap_m_per_s"])-float(fused["q_swap_m_per_s"]))
        require(qdiff<=Q_TOL,f"{tag} q mismatch {qdiff}")
    return qdiff


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


def run_state(
    swap:Fgc44RealSwap,
    duration:float,
    qbot:float,
    center_dh:float,
    scales:list[float],
    expected:dict[str,object],
    state_id:str,
)->dict[str,object]:
    href,origin=initialize(swap,duration,qbot)
    center_head=href+center_dh
    cache:dict[str,dict[str,object]]={}
    max_q_diff=0.0
    status_counts:dict[str,int]={}
    failure_then_success=False
    saw_failure=False

    def observe(head:float)->dict[str,object]:
        nonlocal max_q_diff,failure_then_success,saw_failure
        key=head.hex()
        if key in cache:
            return cache[key]

        before_calls=swap.g15_trial_call_count()
        status,q=swap.try_trial(head)
        require(swap.g15_trial_call_count()==before_calls+1,f"{state_id} participant trial call count mismatch")
        live_before=swap.g15_has_live_candidate()
        require(live_before==(status==0),f"{state_id} live-candidate state mismatch after trial")

        obs1=swap.g15_last_trial_observation()
        live_after_first=swap.g15_has_live_candidate()
        obs2=swap.g15_last_trial_observation()
        live_after_second=swap.g15_has_live_candidate()
        require(observation_equal(obs1,obs2),f"{state_id} repeated observation changed values")
        require(live_before==live_after_first==live_after_second,f"{state_id} observation changed candidate liveness")
        require(swap.state()==origin,f"{state_id} observation changed committed authority")
        require(int(obs1["participant_status"])==status,f"{state_id} observation participant status mismatch")
        if status==0:
            require(bool(obs1["q_available"]),f"{state_id} successful observation lost q")
            require(abs(float(obs1["q_swap_m_per_s"])-float(q))<=Q_TOL,f"{state_id} trial/observation q mismatch")
            if saw_failure:
                failure_then_success=True
            swap.discard()
            require(not swap.g15_has_live_candidate(),f"{state_id} discard left candidate live")
            require(observation_equal(obs1,swap.g15_last_trial_observation()),
                    f"{state_id} discard erased/changed historical observation")
        else:
            saw_failure=True
            require(not bool(obs1["q_available"]),f"{state_id} failed observation exposed q authority")
            require(not swap.g15_has_live_candidate(),f"{state_id} failed trial leaked live candidate")

        require(swap.state()==origin,f"{state_id} trial/discard changed committed authority")
        fused=swap.g14_fused_observation(head)
        qdiff=compare_to_g14(obs1,fused,f"{state_id}@{head:.17g}")
        max_q_diff=max(max_q_diff,qdiff)
        require(swap.state()==origin,f"{state_id} G14 comparison changed committed authority")

        k=str(status)
        status_counts[k]=status_counts.get(k,0)+1
        cache[key]=obs1
        return obs1

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

    require(selected is not None and confirming is not None,f"{state_id} G15 streaming tangent unavailable")
    require(scale_count==int(expected["streaming_scale_count"]),f"{state_id} scale-count mismatch")
    require(len(cache)==int(expected["streaming_unique_heads"]),f"{state_id} unique-head mismatch")
    require(swap.g15_trial_call_count()==len(cache),f"{state_id} not exactly one participant trial per unique head")
    require(selected["scale_m"]==float(expected["selected_scale_m"]),f"{state_id} selected scale mismatch")
    require(selected["mode"]==str(expected["selected_mode"]),f"{state_id} selected mode mismatch")
    require(math.isclose(float(selected["slope_per_s"]),float(expected["selected_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
            f"{state_id} selected slope mismatch")
    require(confirming["scale_m"]==float(expected["confirming_scale_m"]),f"{state_id} confirming scale mismatch")
    require(confirming["mode"]==str(expected["confirming_mode"]),f"{state_id} confirming mode mismatch")
    require(math.isclose(float(confirming["slope_per_s"]),float(expected["confirming_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
            f"{state_id} confirming slope mismatch")

    return {
        "state_id":state_id,
        "participant_trial_calls":swap.g15_trial_call_count(),
        "unique_heads":len(cache),
        "status_counts":status_counts,
        "max_q_diff_m_per_s":max_q_diff,
        "selected_scale_m":selected["scale_m"],
        "selected_mode":selected["mode"],
        "selected_slope_per_s":selected["slope_per_s"],
        "confirming_scale_m":confirming["scale_m"],
        "confirming_mode":confirming["mode"],
        "confirming_slope_per_s":confirming["slope_per_s"],
        "relative_difference":rel,
        "failure_then_success_observed":failure_then_success,
    }


def explicit_failure_recovery(swap:Fgc44RealSwap)->dict[str,object]:
    href,origin=initialize(swap,1.0e-4,1.0e-6)
    failed_head=href+5.25e-6
    status,_=swap.try_trial(failed_head)
    require(status==6,f"G15 explicit failure did not reproduce status 6: {status}")
    failed_obs=swap.g15_last_trial_observation()
    require(failed_obs["available"] and int(failed_obs["participant_status"])==6,"G15 failed observation missing")
    require(not swap.g15_has_live_candidate(),"G15 failed trial leaked candidate")
    require(swap.state()==origin,"G15 failed trial changed authority")

    status2,q2=swap.try_trial(href)
    require(status2==0 and math.isfinite(q2),"G15 admissible trial after failure did not recover")
    success_obs=swap.g15_last_trial_observation()
    require(int(success_obs["participant_status"])==0 and bool(success_obs["q_available"]),
            "G15 recovered trial observation invalid")
    require(swap.g15_has_live_candidate(),"G15 recovered successful candidate not live")
    swap.discard()
    require(swap.state()==origin,"G15 failure-recovery discard changed authority")
    return {
        "failed_status":status,
        "failed_solver_rejections":failed_obs["solver_rejections"],
        "recovered_status":status2,
        "trial_calls":swap.g15_trial_call_count(),
    }


def commit_path(swap:Fgc44RealSwap,with_observation:bool)->tuple[tuple[int,float,int,float],dict[str,object]|None]:
    href,origin=initialize(swap,1.0e-4,1.0e-6)
    status,q=swap.try_trial(href)
    require(status==0 and math.isfinite(q),"G15 commit-path trial failed")
    obs=None
    if with_observation:
        live_before=swap.g15_has_live_candidate()
        obs=swap.g15_last_trial_observation()
        require(obs["available"] and int(obs["participant_status"])==0,"G15 commit-path observation invalid")
        require(swap.g15_has_live_candidate()==live_before,"G15 commit-path observation changed candidate liveness")
        require(swap.state()==origin,"G15 commit-path observation changed authority")
    require(swap.swap_preflight(),"G15 commit-path SWAP preflight failed")
    swap.prepare_ledger()
    require(swap.ledger_preflight(),"G15 commit-path ledger preflight failed")
    require(swap.state()==origin,"G15 preflight changed authority")
    swap.commit_swap()
    mid=swap.state()
    require(mid[0]==1 and abs(mid[1]-1.0e-4)<=1e-14 and mid[2]==0,"G15 swap commit mismatch")
    swap.commit_ledger()
    final=swap.state()
    require(final[0]==1 and abs(final[1]-1.0e-4)<=1e-14 and final[2]==1,"G15 ledger commit mismatch")
    if with_observation:
        require(not swap.g15_last_trial_observation()["available"],"G15 observation not reset by commit")
    return final,obs


def source_contract()->dict[str,object]:
    source=(ROOT/"src"/"runtime"/"mod_fmr_groundwater_swap_participant.f90").read_text()
    start=source.index("  subroutine fmr_swap_observe_last_trial(")
    end=source.index("  end subroutine fmr_swap_observe_last_trial",start)
    body=source[start:end].lower()
    require("class(fmr_groundwater_swap_participant_t), intent(in) :: self" in source[start:end],
            "G15 accessor self is not intent(in)")
    for forbidden in ("backend","executor","materializer"):
        require(forbidden not in body,f"G15 accessor depends on mutable collaborator: {forbidden}")
    require("observation = self%last_observation" in source[start:end],
            "G15 accessor is not a direct participant-owned snapshot copy")
    return {
        "self_intent":"in",
        "mutable_collaborators":[],
        "snapshot_copy":True,
    }


def main()->None:
    contract=source_contract()
    print("FGC44_G15_SOURCE_CONTRACT_JSON="+json.dumps(contract,sort_keys=True,separators=(",",":")))
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"missing FGC44 SWAP bridge")
    g13=json.loads(G13.read_text())
    g09=json.loads(G09D.read_text())
    expected={x["state_id"]:x for x in g13["state_results"] if x["carrier"]=="FGC44"}
    authority={f"{x['case_id']}_{x['side']}":x for x in g09["estimator_results"]}
    require(set(expected)==set(authority),"G15 FGC44 authority state mismatch")

    swap=Fgc44RealSwap(lib)
    rows=[]
    for state_id,item in authority.items():
        row=run_state(
            swap,
            float(item["duration_day"]),
            float(item["qbot_cm_per_day"]),
            float(item["dh_m"]),
            [float(x["scale_m"]) for x in item["e3"]["candidates"]],
            expected[state_id],
            state_id,
        )
        rows.append(row)
        print("FGC44_G15_STATE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    total_heads=sum(int(x["unique_heads"]) for x in rows)
    total_calls=sum(int(x["participant_trial_calls"]) for x in rows)
    require(total_heads==62,f"G15 expected 62 FGC44 streaming heads, got {total_heads}")
    require(total_calls==62,f"G15 expected one participant trial per head, got {total_calls}")
    require(max(float(x["max_q_diff_m_per_s"]) for x in rows)<=Q_TOL,"G15 q equivalence failed")

    recovery=explicit_failure_recovery(swap)
    print("FGC44_G15_FAILURE_RECOVERY_JSON="+json.dumps(recovery,sort_keys=True,separators=(",",":")))

    baseline_state,_=commit_path(swap,False)
    observed_state,commit_obs=commit_path(swap,True)
    require(baseline_state==observed_state,f"G15 observation changed commit result: {baseline_state} != {observed_state}")
    commit_result={
        "baseline_state":list(baseline_state),
        "observed_state":list(observed_state),
        "observation_participant_status":int(commit_obs["participant_status"]) if commit_obs else None,
        "equivalent":True,
    }
    print("FGC44_G15_COMMIT_EQUIVALENCE_JSON="+json.dumps(commit_result,sort_keys=True,separators=(",",":")))

    summary={
        "state_count":len(rows),
        "streaming_unique_heads":total_heads,
        "participant_trial_calls":total_calls,
        "max_q_diff_m_per_s":max(float(x["max_q_diff_m_per_s"]) for x in rows),
        "status6_state_count":sum("6" in x["status_counts"] for x in rows),
        "explicit_failure_recovery":"PASS",
        "repeated_read_lifecycle":"PASS",
        "discard_authority":"PASS",
        "commit_equivalence":"PASS",
        "source_contract":"PASS",
    }
    print("FGC44_G15_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G15_SAME_TRIAL_OBSERVATION=PASS")
    print("GC_FIXED_INTERFACE_G15_TRANSACTION_SEMANTICS=PASS")
    print("GC_FIXED_INTERFACE_G15_EXECUTION=PASS")


if __name__=="__main__":
    main()
