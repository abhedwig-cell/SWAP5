from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"/"support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap

G13=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G13_RESULT.json"
G12B=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12B_RESULT.json"
REL_TOL=0.05
Q_TOL=1.0e-18
CLASS_FIELDS=(
    "accepted_substeps","attempts","retries","solver_rejections",
    "temporal_rejections","internal_retries","min_substep","max_substep",
)
RAW_FIELDS=(
    "result_status","completed","candidate_ready","transaction_calls",
    "accepted_substeps","attempts","retries","trial_rollbacks",
    "solver_rejections","temporal_rejections","temporal_unavailable_rejections",
    "mass_rejections","internal_retries",
)


def require(value:bool,message:str)->None:
    if not value:
        raise AssertionError(message)


def fresh(lib:Path)->tuple[Map09ActiveDrainageSwap,float,tuple[int,float,int,float]]:
    swap=Map09ActiveDrainageSwap(lib)
    _,_,href=swap.initialize()
    origin=swap.state()
    require(origin==(0,0.0,0,0.0),f"dirty MAP09 origin {origin}")
    return swap,href,origin


def participant_observation(lib:Path,head:float)->dict[str,object]:
    swap,_,origin=fresh(lib)
    status,q=swap.try_trial(head)
    if status==0:
        swap.discard()
    require(swap.state()==origin,"participant observation mutated MAP09 authority")
    return {"participant_status":int(status),"q_swap_m_per_s":float(q)}


def raw_observation(lib:Path,head:float)->dict[str,object]:
    swap,_,origin=fresh(lib)
    raw=swap.corrector_diagnostics(head)
    raw["min_substep"]=raw["min_accepted_substep_day"]
    raw["max_substep"]=raw["max_accepted_substep_day"]
    require(swap.state()==origin,"raw observation mutated MAP09 authority")
    return raw


def fused_observation(lib:Path,head:float)->dict[str,object]:
    swap,_,origin=fresh(lib)
    require(swap.g14_fused_run_count()==0,"MAP09 fused counter did not reset")
    obs=swap.g14_fused_observation(head)
    require(swap.g14_fused_run_count()==1,"MAP09 fused observation did not use exactly one backend run")
    require(swap.state()==origin,"fused observation mutated MAP09 authority")
    return obs


def compare_observations(part:dict[str,object],raw:dict[str,object],fused:dict[str,object],tag:str)->float:
    require(int(fused["participant_status"])==int(part["participant_status"]),f"{tag} participant status mismatch")
    qdiff=0.0
    if int(part["participant_status"])==0:
        qdiff=abs(float(fused["q_swap_m_per_s"])-float(part["q_swap_m_per_s"]))
        require(qdiff<=Q_TOL,f"{tag} q mismatch {qdiff}")
    for field in RAW_FIELDS:
        a=fused[field]; b=raw[field]
        if isinstance(a,bool) or isinstance(b,bool):
            require(bool(a)==bool(b),f"{tag} raw field mismatch {field}: {a} != {b}")
        else:
            require(int(a)==int(b),f"{tag} raw field mismatch {field}: {a} != {b}")
    require(float(fused["min_substep"])==float(raw["min_substep"]),f"{tag} min_substep mismatch")
    require(float(fused["max_substep"])==float(raw["max_substep"]),f"{tag} max_substep mismatch")
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


def fused_streaming(lib:Path,center_head:float,scales:list[float])->dict[str,object]:
    swap,_,origin=fresh(lib)
    cache:dict[str,dict[str,object]]={}
    def obs(head:float)->dict[str,object]:
        key=head.hex()
        if key not in cache:
            before=swap.g14_fused_run_count()
            cache[key]=swap.g14_fused_observation(head)
            after=swap.g14_fused_run_count()
            require(after==before+1,"MAP09 fused streaming did not increment backend run counter once")
            require(swap.state()==origin,"MAP09 fused streaming sample mutated authority")
        return cache[key]

    center=obs(center_head)
    require(execution_class(center) is not None,"MAP09 fused streaming center unavailable")
    previous=None
    scale_count=0
    for d in scales:
        scale_count+=1
        samples={m:obs(center_head+m*d) for m in (-2,-1,0,1,2)}
        current=candidate(center,samples,d)
        if previous is not None and current is not None:
            s0=float(previous["slope_per_s"]); s1=float(current["slope_per_s"])
            rel=abs(s0-s1)/max(abs(s0),abs(s1))
            if rel<=REL_TOL:
                require(swap.g14_fused_run_count()==len(cache),"MAP09 fused counter/cache mismatch")
                return {
                    "classification":"AVAILABLE",
                    "selected":previous,
                    "confirming":current,
                    "relative_difference":rel,
                    "scale_count":scale_count,
                    "unique_head_count":len(cache),
                    "fused_backend_runs":swap.g14_fused_run_count(),
                }
        previous=current
    return {
        "classification":"TANGENT_UNAVAILABLE",
        "scale_count":scale_count,
        "unique_head_count":len(cache),
        "fused_backend_runs":swap.g14_fused_run_count(),
    }


def main()->None:
    lib=Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(lib.is_file(),"missing MAP09 SWAP bridge")
    g13=json.loads(G13.read_text())
    g12=json.loads(G12B.read_text())
    g13_rows={x["state_id"]:x for x in g13["state_results"] if x["carrier"]=="MAP09"}
    authority={str(x["label"]):x for x in g12["estimator_results"]}
    require(set(g13_rows)==set(authority),"G14 MAP09 state authority drift")

    rows=[]
    total_heads=0
    total_fused_runs=0
    max_q_diff=0.0

    for state_id,item in authority.items():
        dh=float(item["dh_m"])
        e3=item["e3"]
        cost=g13_rows[state_id]
        scales=[float(x["scale_m"]) for x in e3["candidates"]][:int(cost["streaming_scale_count"])]
        tmp,href,_=fresh(lib)
        del tmp
        center=href+dh
        offsets={0.0}
        for d in scales:
            offsets.update((-2*d,-d,d,2*d))
        require(len(offsets)==int(cost["streaming_unique_heads"]),f"{state_id} G13 MAP09 head-count mismatch")

        state_q_diff=0.0
        status_counts:dict[str,int]={}
        for offset in sorted(offsets):
            head=center+offset
            part=participant_observation(lib,head)
            raw=raw_observation(lib,head)
            fused=fused_observation(lib,head)
            qdiff=compare_observations(part,raw,fused,f"{state_id}@{offset:.17g}")
            state_q_diff=max(state_q_diff,qdiff)
            key=str(int(part["participant_status"]))
            status_counts[key]=status_counts.get(key,0)+1

        stream=fused_streaming(lib,center,[float(x["scale_m"]) for x in e3["candidates"]])
        require(stream["classification"]=="AVAILABLE",f"{state_id} MAP09 fused E3 unavailable")
        require(int(stream["scale_count"])==int(cost["streaming_scale_count"]),f"{state_id} MAP09 scale-count mismatch")
        require(int(stream["unique_head_count"])==int(cost["streaming_unique_heads"]),f"{state_id} MAP09 head-count mismatch")
        require(stream["selected"]["scale_m"]==float(cost["selected_scale_m"]),f"{state_id} MAP09 selected scale mismatch")
        require(stream["selected"]["mode"]==str(cost["selected_mode"]),f"{state_id} MAP09 selected mode mismatch")
        require(math.isclose(float(stream["selected"]["slope_per_s"]),float(cost["selected_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
                f"{state_id} MAP09 selected slope mismatch")
        require(stream["confirming"]["scale_m"]==float(cost["confirming_scale_m"]),f"{state_id} MAP09 confirming scale mismatch")
        require(stream["confirming"]["mode"]==str(cost["confirming_mode"]),f"{state_id} MAP09 confirming mode mismatch")
        require(math.isclose(float(stream["confirming"]["slope_per_s"]),float(cost["confirming_slope_per_s"]),rel_tol=0.0,abs_tol=1e-18),
                f"{state_id} MAP09 confirming slope mismatch")

        row={
            "state_id":state_id,
            "head_count":len(offsets),
            "status_counts":status_counts,
            "max_q_diff_m_per_s":state_q_diff,
            "streaming_scale_count":stream["scale_count"],
            "streaming_unique_heads":stream["unique_head_count"],
            "fused_backend_runs":stream["fused_backend_runs"],
            "selected_scale_m":stream["selected"]["scale_m"],
            "selected_mode":stream["selected"]["mode"],
            "selected_slope_per_s":stream["selected"]["slope_per_s"],
            "confirming_scale_m":stream["confirming"]["scale_m"],
            "confirming_mode":stream["confirming"]["mode"],
            "confirming_slope_per_s":stream["confirming"]["slope_per_s"],
        }
        rows.append(row)
        total_heads+=len(offsets)
        total_fused_runs+=int(stream["fused_backend_runs"])
        max_q_diff=max(max_q_diff,state_q_diff)
        print("FGC44_G14_MAP09_STATE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    expected_heads=sum(int(x["streaming_unique_heads"]) for x in g13_rows.values())
    require(total_heads==expected_heads,f"G14 MAP09 total head count drifted: {total_heads} != {expected_heads}")
    require(total_fused_runs==total_heads,"G14 MAP09 fused run total is not one per unique streaming head")
    summary={
        "carrier":"MAP09",
        "state_count":len(rows),
        "streaming_unique_heads":total_heads,
        "fused_backend_runs":total_fused_runs,
        "max_q_diff_m_per_s":max_q_diff,
        "all_streaming_decisions_equivalent":True,
        "transaction_authority":"PASS",
    }
    print("FGC44_G14_MAP09_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G14_MAP09_FUSED_EQUIVALENCE=PASS")


if __name__=="__main__":
    main()
