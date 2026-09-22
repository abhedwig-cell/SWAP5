from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case
from test_gc_fixed_interface_g16_tangent_observation_service import OBS_FIELDS

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21F_PREREGISTRATION.json"
G21E=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21E_RESULT.json"

EXEC_FIELDS=(
    "result_status","completed","candidate_ready","transaction_calls",
    "accepted_substeps","attempts","retries","trial_rollbacks",
    "solver_rejections","temporal_rejections","temporal_unavailable_rejections",
    "mass_rejections","internal_retries","min_substep","max_substep",
)


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def bits(x:float)->int:
    return int(np.asarray(np.float64(x)).view(np.int64).item())


def ulp_distance(a:float,b:float)->int:
    return abs(bits(a)-bits(b))


def compact_observation(head:float,obs:dict[str,object])->dict[str,object]:
    row={"head_m":float(head),"head_hex":float(head).hex()}
    for key in OBS_FIELDS:
        value=obs[key]
        if isinstance(value,np.generic):
            value=value.item()
        row[key]=value
    return row


def observe_checked(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    head:float,
)->dict[str,object]:
    obs=swap.g16_observe_head(float(head))
    require(bool(obs["available"]),"G21F unavailable G16 observation")
    status=int(obs["participant_status"])
    require(status in (0,6),f"G21F unexpected participant status {status}")
    require(bool(obs["q_available"])==(status==0),"G21F q authority/status mismatch")
    require(not swap.g15_has_live_candidate(),"G21F diagnostic observation leaked live candidate")
    require(swap.state()==origin,"G21F diagnostic observation changed accepted/ledger state")
    require(not swap.swap_preflight(),"G21F diagnostic observation acquired FMR preflight")
    require(not swap.ledger_preflight(),"G21F diagnostic observation acquired ledger preflight")
    return compact_observation(float(head),obs)


def ordered_unique(values:list[float])->list[float]:
    return sorted(set(float(np.float64(x)) for x in values))


def neighbourhood(lo:float,hi:float,n:int=4)->list[float]:
    left=[]
    x=np.float64(lo)
    for _ in range(n):
        x=np.nextafter(x,np.float64(-np.inf))
        left.append(float(x))
    left.reverse()
    right=[]
    x=np.float64(hi)
    for _ in range(n):
        x=np.nextafter(x,np.float64(np.inf))
        right.append(float(x))
    return ordered_unique(left+[float(lo),float(hi)]+right)


def session_probe(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    heads:list[float],
    session_id:int,
)->dict[str,object]:
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),f"G21F session {session_id} dirty counters")
    rows=[]
    for head in heads:
        rows.append(observe_checked(swap,origin,head))
    counts=swap.g16_counts()
    require(counts[0]==len(heads),f"G21F session {session_id} logical request count")
    require(counts[1]==len(heads),f"G21F session {session_id} expected fresh physical trial per unique head")
    require(counts[2]==0,f"G21F session {session_id} unexpected cache hit")
    require(counts[3]==len(heads),f"G21F session {session_id} cache size mismatch")
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),f"G21F session {session_id} end did not clear cache")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),
            f"G21F session {session_id} changed authority")
    return {"session":session_id,"rows":rows,"counts":list(counts)}


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21E.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21F","wrong G21F preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G21F preregistration not frozen")
    require(parent["decision"]=="QUALIFIED_MATCHED_COMPARISON_BOTH_PHYSICALLY_CONVERGED_NO_SOLVER_CONFIGURATION_SELECTION",
            "G21F parent G21E authority drift")

    anchors=prereg["frozen_anchors"]
    g17=float(anchors["g17_outer2_accepted_head_m"])
    nour=float(anchors["nour_outer2_lambda1_head_m"])
    standard=float(anchors["standard_outer2_head_m"])
    require(nour<g17<standard,"G21F frozen head ordering drift")
    require(math.isclose(nour-g17,float(anchors["nour_minus_g17_head_m"]),rel_tol=0.0,abs_tol=1e-18),
            "G21F frozen NOUR/G17 separation drift")

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"missing FGC44 SWAP library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(
        swap,
        float(prereg["fixed_carrier"]["duration_day"]),
        float(prereg["fixed_carrier"]["predictor_qbot_cm_per_day"]),
    )
    require(origin==(0,0.0,0,0.0),"G21F dirty accepted origin")
    require(swap.g15_trial_call_count()==0,"G21F ordinary trial counter dirty")

    # Session 1 owns the anchor check, coarse topology scan, and ULP bisection.
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),"G21F primary session dirty")

    frozen_rows={
        "NOUR":observe_checked(swap,origin,nour),
        "G17":observe_checked(swap,origin,g17),
        "STANDARD":observe_checked(swap,origin,standard),
    }
    require(int(frozen_rows["NOUR"]["participant_status"])==6,"G21F NOUR frozen status drift")
    require(int(frozen_rows["G17"]["participant_status"])==0,"G21F G17 frozen status drift")
    require(int(frozen_rows["STANDARD"]["participant_status"])==0,"G21F STANDARD frozen status drift")
    print("FGC44_G21F_ANCHORS_JSON="+json.dumps(frozen_rows,sort_keys=True,separators=(",",":")))

    coarse=ordered_unique([float(x) for x in np.linspace(nour,g17,33,dtype=np.float64)])
    require(len(coarse)==33,"G21F coarse scan collapsed binary64 heads")
    coarse_rows=[observe_checked(swap,origin,h) for h in coarse]
    statuses=[int(x["participant_status"]) for x in coarse_rows]
    require(all(x in (0,6) for x in statuses),"G21F coarse scan unexpected status")
    transition_count=sum(1 for a,b in zip(statuses[:-1],statuses[1:]) if a!=b)
    reversal_count=sum(1 for a,b in zip(statuses[:-1],statuses[1:]) if a==0 and b==6)
    monotone=(
        statuses[0]==6 and statuses[-1]==0 and transition_count==1 and reversal_count==0
    )
    coarse_summary={
        "head_count":len(coarse),
        "statuses":statuses,
        "transition_count":transition_count,
        "reversal_count":reversal_count,
        "monotone_6_to_0":monotone,
        "initial_bracket_width_m":g17-nour,
        "initial_bracket_ulps":ulp_distance(nour,g17),
    }
    print("FGC44_G21F_COARSE_JSON="+json.dumps(coarse_summary,sort_keys=True,separators=(",",":")))

    boundary=None
    primary_neighbour_rows=[]
    if monotone:
        lo=float(nour)
        hi=float(g17)
        iterations=0
        while iterations<80 and float(np.nextafter(np.float64(lo),np.float64(hi)))!=hi:
            mid=float(np.float64(lo+(hi-lo)*0.5))
            if mid==lo or mid==hi:
                break
            row=observe_checked(swap,origin,mid)
            status=int(row["participant_status"])
            if status==6:
                lo=mid
            elif status==0:
                hi=mid
            else:
                raise AssertionError(f"G21F unexpected bisection status {status}")
            iterations+=1

        lo_row=observe_checked(swap,origin,lo)
        hi_row=observe_checked(swap,origin,hi)
        require(int(lo_row["participant_status"])==6,"G21F final lower endpoint not status6")
        require(int(hi_row["participant_status"])==0,"G21F final upper endpoint not status0")
        adjacent=float(np.nextafter(np.float64(lo),np.float64(hi)))==hi
        midpoint_exhausted=float(np.float64(lo+(hi-lo)*0.5)) in (lo,hi)
        require(adjacent or midpoint_exhausted,"G21F bisection did not exhaust binary64 bracket")

        neighbour_heads=neighbourhood(lo,hi,4)
        primary_neighbour_rows=[observe_checked(swap,origin,h) for h in neighbour_heads]
        exec_diffs={
            key:[lo_row[key],hi_row[key]]
            for key in EXEC_FIELDS if lo_row[key]!=hi_row[key]
        }
        boundary={
            "status6_head_m":lo,
            "status6_head_hex":lo.hex(),
            "status0_head_m":hi,
            "status0_head_hex":hi.hex(),
            "width_m":hi-lo,
            "ulp_distance":ulp_distance(lo,hi),
            "adjacent_binary64":adjacent,
            "midpoint_exhausted":midpoint_exhausted,
            "bisection_iterations":iterations,
            "execution_field_differences":exec_diffs,
            "status6_observation":lo_row,
            "status0_observation":hi_row,
            "neighbour_heads_m":neighbour_heads,
        }
        print("FGC44_G21F_BOUNDARY_JSON="+json.dumps(boundary,sort_keys=True,separators=(",",":")))

    primary_counts=swap.g16_counts()
    require(primary_counts[0]==primary_counts[1]+primary_counts[2],
            "G21F primary G16 accounting mismatch")
    require(swap.g15_trial_call_count()==0,"G21F primary diagnostics used ordinary participant path")
    swap.g16_end_session()
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21F primary session changed authority")

    repeats=[]
    deterministic=False
    if monotone and boundary is not None:
        heads=[float(x) for x in boundary["neighbour_heads_m"]]
        # Primary-neighbour rows are session 1. Sessions 2 and 3 force fresh physical trials.
        repeats.append({"session":1,"rows":primary_neighbour_rows})
        repeats.append(session_probe(swap,origin,heads,2))
        repeats.append(session_probe(swap,origin,heads,3))
        status_vectors=[
            [int(row["participant_status"]) for row in item["rows"]]
            for item in repeats
        ]
        deterministic=all(v==status_vectors[0] for v in status_vectors[1:])
        require(deterministic,"G21F cross-session neighbourhood status drift")
        lower=float(boundary["status6_head_m"]); upper=float(boundary["status0_head_m"])
        for item in repeats:
            table={float(row["head_m"]):int(row["participant_status"]) for row in item["rows"]}
            require(table[lower]==6 and table[upper]==0,
                    f"G21F boundary endpoint status drift session={item['session']}")

    if not monotone:
        classification="NONMONOTONE_OR_UNRESOLVED"
    elif not deterministic:
        classification="NONMONOTONE_OR_UNRESOLVED"
    elif boundary is not None and bool(boundary["execution_field_differences"]):
        classification="DETERMINISTIC_EXECUTION_THRESHOLD"
    else:
        classification="DETERMINISTIC_STATUS_BOUNDARY_CAUSE_UNRESOLVED"

    require(swap.g15_trial_call_count()==0,"G21F ordinary publication path was used")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21F final authority changed")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21F final publication authority leaked")

    summary={
        "classification":classification,
        "anchors":frozen_rows,
        "coarse":coarse_summary,
        "boundary":boundary,
        "cross_session_neighbourhood_status_deterministic":deterministic,
        "repeat_sessions":repeats,
        "accepted_state_ledger_mutation":0,
        "ordinary_publication_trials":swap.g15_trial_call_count(),
        "production_policy_claim":"NONE",
    }
    print("FGC44_G21F_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21F_BOUNDARY_DIAGNOSTIC=PASS")
    print("GC_FIXED_INTERFACE_G21F_EXECUTION=PASS")


if __name__=="__main__":
    main()
