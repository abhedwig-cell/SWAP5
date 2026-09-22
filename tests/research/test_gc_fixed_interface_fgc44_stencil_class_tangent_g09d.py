from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    AREA_M2,
    DAY_TO_S,
    FLUX_TOL,
    HEAD_TOL_M,
    MAX_BACKTRACK,
    MAX_OUTER,
    initialize_case,
    scan_swap,
    groundwater_response,
    reference_root,
    residual_at,
    solve_term,
    trial_discard,
)

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09D_PREREGISTRATION.json"
G08_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"
G09_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09_PREREGISTRATION.json"

REL_TOL = 0.05
MERIT_ABS_TOL = 1.0e-18
SCALES_M = (2.5e-7,1.25e-7,6.25e-8,3.125e-8,1.5625e-8,7.8125e-9,3.90625e-9)

BOUNDARY_STATES = (
    ("C0_CONTROL",1.0e-4,1.0e-6,-2.0e-6,5.0e-6),
    ("C1_LOW_FORCING",1.0e-4,5.0e-7,-5.0e-6,5.0e-6),
    ("C2_HIGH_FORCING",1.0e-4,2.0e-6,-5.0e-6,2.0e-6),
    ("C3_LONG_HIGH",2.0e-4,2.0e-6,-5.0e-6,2.0e-6),
)
REPLAYS = (
    ("C1_LOW_FORCING",1.0e-4,5.0e-7,-5.0e-6),
    ("C2_HIGH_FORCING",1.0e-4,2.0e-6,-5.0e-6),
    ("C3_LONG_HIGH",2.0e-4,2.0e-6,2.0e-6),
)
SIG_INT_FIELDS = (
    "accepted_substeps","attempts","retries","solver_rejections",
    "temporal_rejections","internal_retries",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> list[dict[str, object]]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G09D","wrong G09D preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G09D preregistration not frozen")
    require(tuple(float(x) for x in p["scale_ladder_m"])==SCALES_M,"G09D scale ladder drifted")
    g09=json.loads(G09_PREREG.read_text())
    frozen=tuple(
        (
            str(x["case_id"]),float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]),
            float(x["negative_dh_m"]),float(x["positive_dh_m"]),
        )
        for x in g09["frozen_boundary_states"]
    )
    require(frozen==BOUNDARY_STATES,"G09D boundary states drifted from G09")
    g08=json.loads(G08_PREREG.read_text())
    return [dict(x) for x in g08["groundwater_regimes"]]


def ready_raw(raw: dict[str, object]) -> bool:
    return int(raw["result_status"])==0 and bool(raw["completed"]) and bool(raw["candidate_ready"])


def sample(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    head:float,
) -> dict[str,object]:
    status,q=trial_discard(swap,origin,head)
    raw=swap.raw_corrector_diagnostics(head)
    require(swap.state()==origin,"G09D raw diagnostic mutated accepted authority")
    ready=status==0 and ready_raw(raw)
    sig=None
    if ready:
        sig=tuple(
            [int(raw[k]) for k in SIG_INT_FIELDS]
            + [float(raw["min_substep"]),float(raw["max_substep"])]
        )
    return {
        "head_m":head,
        "participant_status":int(status),
        "q_swap_m_per_s":float(q) if status==0 else None,
        "raw_ready":ready_raw(raw),
        "ready":ready,
        "signature":sig,
        "raw":raw,
    }


def same_class(*samples:dict[str,object]) -> bool:
    if not all(bool(s["ready"]) for s in samples):
        return False
    sigs=[s["signature"] for s in samples]
    return all(sig==sigs[0] for sig in sigs[1:])


def candidate_at_scale(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    head:float,
    d:float,
    cache:dict[str,dict[str,object]],
) -> dict[str,object]:
    def get(h:float)->dict[str,object]:
        key=h.hex()
        if key not in cache:
            cache[key]=sample(swap,origin,h)
        return cache[key]

    c=get(head); m1=get(head-d); p1=get(head+d); m2=get(head-2.0*d); p2=get(head+2.0*d)
    candidate:dict[str,object]={
        "scale_m":d,
        "classification":"NO_STENCIL",
        "mode":None,
        "slope_per_s":None,
        "center_signature":list(c["signature"]) if c["signature"] is not None else None,
        "minus1":{"status":m1["participant_status"],"signature":list(m1["signature"]) if m1["signature"] is not None else None},
        "plus1":{"status":p1["participant_status"],"signature":list(p1["signature"]) if p1["signature"] is not None else None},
        "minus2":{"status":m2["participant_status"],"signature":list(m2["signature"]) if m2["signature"] is not None else None},
        "plus2":{"status":p2["participant_status"],"signature":list(p2["signature"]) if p2["signature"] is not None else None},
    }
    slope=None
    if same_class(m1,p1):
        slope=(float(p1["q_swap_m_per_s"])-float(m1["q_swap_m_per_s"]))/(2.0*d)
        mode="CENTRAL_PAIR_CLASS"
    elif same_class(c,m1,m2):
        slope=(3.0*float(c["q_swap_m_per_s"])-4.0*float(m1["q_swap_m_per_s"])+float(m2["q_swap_m_per_s"]))/(2.0*d)
        mode="BACKWARD_CENTER_CLASS"
    elif same_class(c,p1,p2):
        slope=(-3.0*float(c["q_swap_m_per_s"])+4.0*float(p1["q_swap_m_per_s"])-float(p2["q_swap_m_per_s"]))/(2.0*d)
        mode="FORWARD_CENTER_CLASS"
    else:
        return candidate
    if math.isfinite(slope) and slope<0.0:
        candidate["classification"]="CANDIDATE"
        candidate["mode"]=mode
        candidate["slope_per_s"]=slope
    else:
        candidate["classification"]="NONNEGATIVE_OR_NONFINITE"
        candidate["mode"]=mode
        candidate["slope_per_s"]=slope
    return candidate


def estimate_e3(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    head:float,
) -> dict[str,object]:
    center=sample(swap,origin,head)
    if not bool(center["ready"]):
        return {"classification":"CENTER_UNAVAILABLE","center":center}
    cache={head.hex():center}
    candidates=[
        candidate_at_scale(swap,origin,head,d,cache)
        for d in SCALES_M
    ]
    for coarse,fine in zip(candidates[:-1],candidates[1:]):
        if coarse["classification"]!="CANDIDATE" or fine["classification"]!="CANDIDATE":
            continue
        sc=float(coarse["slope_per_s"]); sf=float(fine["slope_per_s"])
        rel=abs(sc-sf)/max(abs(sc),abs(sf))
        if rel<=REL_TOL:
            return {
                "classification":"AVAILABLE",
                "mode":coarse["mode"],
                "slope_per_s":sc,
                "selected_d_m":coarse["scale_m"],
                "confirming_mode":fine["mode"],
                "confirming_slope_per_s":sf,
                "confirming_d_m":fine["scale_m"],
                "relative_difference":rel,
                "candidates":candidates,
            }
    return {"classification":"TANGENT_UNAVAILABLE","candidates":candidates}


def resolve_sy(regime:dict[str,object],u:float)->float:
    f=str(regime["sy_formula"])
    if f=="0.75*u_predictor": return 0.75*u
    if f=="2.0*u_predictor": return 2.0*u
    if f=="0.15": return 0.15
    raise AssertionError(f"unknown G09D sy formula {f}")


def run_policy(
    policy:str,
    libmf6:Path,
    swaplib:Path,
    swap:Fgc44RealSwap,
    duration:float,
    qbot:float,
    regime:dict[str,object],
    sy:float,
    a:float,
    intercept:float,
    root:float,
    start_dh:float,
)->dict[str,object]:
    _,_,href,origin,_=initialize_case(swap,duration,qbot)
    head=href+start_dh
    contractions=0
    raw_inadmissible=0
    merit_increases=0
    modes:list[str]=[]
    trace:list[dict[str,object]]=[]

    for outer in range(1,MAX_OUTER+1):
        status,q,residual=residual_at(swap,origin,head,a,intercept)
        if status!=0 or q is None or residual is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer,"status":status}
        if abs(residual)<=FLUX_TOL and abs(head-root)<=HEAD_TOL_M:
            return {
                "classification":"CONVERGED","outer":outer-1,"final_head_m":head,
                "final_residual_m_per_s":residual,"head_error_m":head-root,
                "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                "merit_increases":merit_increases,"modes":modes,"trace":trace,
            }

        est=estimate_e3(swap,origin,head)
        if est["classification"]!="AVAILABLE":
            return {"classification":"TANGENT_UNAVAILABLE","outer":outer,"estimator":est,"contractions":contractions}
        p=float(est["slope_per_s"]); modes.append(str(est["mode"]))
        slope_day=p*AREA_M2*DAY_TO_S
        rhs=slope_day*head-q*AREA_M2*DAY_TO_S
        raw_head,_,mf_iters=solve_term(
            libmf6,swaplib,duration,href,
            float(regime["k_m_per_day"]),float(regime["ss_per_m"]),sy,
            float(regime["initial_head_bias_m"]),slope_day,rhs,
        )
        raw_status,_,raw_residual=residual_at(swap,origin,raw_head,a,intercept)
        if raw_status!=0: raw_inadmissible+=1

        if policy=="P1_E3":
            if raw_status!=0 or raw_residual is None:
                return {
                    "classification":"RAW_PROPOSAL_INADMISSIBLE","outer":outer,
                    "raw_head_m":raw_head,"status":raw_status,
                    "contractions":contractions,"modes":modes,
                }
            candidate=raw_head; candidate_residual=raw_residual
            if abs(candidate_residual)>abs(residual)+MERIT_ABS_TOL:
                merit_increases+=1
        elif policy=="P4_E3":
            candidate=raw_head; candidate_residual=raw_residual
            accepted=(
                raw_status==0 and candidate_residual is not None
                and abs(candidate_residual)<=abs(residual)+MERIT_ABS_TOL
            )
            local=0
            while not accepted and local<MAX_BACKTRACK:
                candidate=head+0.5*(candidate-head); local+=1
                cstatus,_,cres=residual_at(swap,origin,candidate,a,intercept)
                candidate_residual=cres
                accepted=(
                    cstatus==0 and candidate_residual is not None
                    and abs(candidate_residual)<=abs(residual)+MERIT_ABS_TOL
                )
            contractions+=local
            if not accepted or candidate_residual is None:
                return {
                    "classification":"SAFEGUARD_EXHAUSTED","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"modes":modes,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer":outer,"head_m":candidate,
            "residual_m_per_s":float(candidate_residual),
            "raw_head_m":raw_head,"tangent_per_s":p,
            "tangent_mode":est["mode"],"tangent_d_m":est["selected_d_m"],
            "confirming_mode":est["confirming_mode"],
            "confirming_d_m":est["confirming_d_m"],
            "tangent_relative_difference":est["relative_difference"],
            "mf_iterations":mf_iters,
        })
        head=candidate

    status,_,final_res=residual_at(swap,origin,head,a,intercept)
    return {
        "classification":"OUTER_BUDGET_EXHAUSTED","outer":MAX_OUTER,
        "status":status,"final_head_m":head,"final_residual_m_per_s":final_res,
        "head_error_m":head-root,"contractions":contractions,
        "raw_inadmissible":raw_inadmissible,"merit_increases":merit_increases,
        "modes":modes,"trace":trace,
    }


def main()->None:
    regimes=load_prereg()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")
    swap=Fgc44RealSwap(swaplib)

    estimator_rows=[]
    for case_id,duration,qbot,neg_dh,pos_dh in BOUNDARY_STATES:
        _,_,href,origin,_=initialize_case(swap,duration,qbot)
        for side,dh in (("NEG",neg_dh),("POS",pos_dh)):
            e3=estimate_e3(swap,origin,href+dh)
            require(e3["classification"]=="AVAILABLE",f"G09D E3 unavailable {case_id} {side}")
            require(float(e3["relative_difference"])<=REL_TOL,f"G09D E3 inconsistent {case_id} {side}")
            row={
                "case_id":case_id,"duration_day":duration,
                "qbot_cm_per_day":qbot,"side":side,"dh_m":dh,"e3":e3,
            }
            estimator_rows.append(row)
            print("FGC44_G09D_ESTIMATOR_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
        require(swap.state()==origin,f"G09D estimator sweep mutated authority {case_id}")

    c1neg=next(x for x in estimator_rows if x["case_id"]=="C1_LOW_FORCING" and x["side"]=="NEG")
    c2neg=next(x for x in estimator_rows if x["case_id"]=="C2_HIGH_FORCING" and x["side"]=="NEG")
    c3pos=next(x for x in estimator_rows if x["case_id"]=="C3_LONG_HIGH" and x["side"]=="POS")
    require(str(c1neg["e3"]["mode"])=="CENTRAL_PAIR_CLASS","G09D C1-negative did not use pairwise central class")
    require(str(c2neg["e3"]["mode"]).startswith("BACKWARD"),"G09D C2-negative did not use backward class")
    require(str(c3pos["e3"]["mode"]).startswith("BACKWARD"),"G09D C3-positive did not reject cross-branch central stencil")

    policy_rows=[]
    for case_id,duration,qbot,start_dh in REPLAYS:
        _,_,href,origin,diag=initialize_case(swap,duration,qbot)
        scan=scan_swap(swap,origin,href)
        u=float(diag["u"])
        for regime in regimes:
            sy=resolve_sy(regime,u)
            a,intercept,fit_error=groundwater_response(libmf6,swaplib,duration,href,regime,sy)
            root=reference_root(swap,origin,scan,a,intercept)
            require(root is not None,f"G09D missing reference root {case_id} {regime['id']}")
            for policy in ("P1_E3","P4_E3"):
                result=run_policy(
                    policy,libmf6,swaplib,swap,duration,qbot,regime,sy,
                    a,intercept,float(root),start_dh,
                )
                row={
                    "case_id":case_id,"regime_id":regime["id"],"policy":policy,
                    "start_dh_m":start_dh,"a_per_s":a,
                    "gw_fit_error_m_per_s":fit_error,"reference_root_m":root,
                    **result,
                }
                policy_rows.append(row)
                print("FGC44_G09D_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
                require(result["classification"]=="CONVERGED",
                        f"G09D replay failed {case_id} {regime['id']} {policy}: {result}")
        require(swap.state()==origin,f"G09D replay mutated authority {case_id}")

    p1=[x for x in policy_rows if x["policy"]=="P1_E3"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3"]
    summary={
        "boundary_state_count":len(estimator_rows),
        "e3_available_count":sum(x["e3"]["classification"]=="AVAILABLE" for x in estimator_rows),
        "e3_consistent_count":sum(float(x["e3"]["relative_difference"])<=REL_TOL for x in estimator_rows),
        "c1_negative_mode":c1neg["e3"]["mode"],
        "c1_negative_slope_per_s":c1neg["e3"]["slope_per_s"],
        "c2_negative_mode":c2neg["e3"]["mode"],
        "c2_negative_slope_per_s":c2neg["e3"]["slope_per_s"],
        "c3_positive_mode":c3pos["e3"]["mode"],
        "c3_positive_slope_per_s":c3pos["e3"]["slope_per_s"],
        "policy_replay_count":len(policy_rows),
        "p1_e3_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_e3_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p1_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p1),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
    }
    print("FGC44_G09D_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G09D_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G09D_MULTISCALE_CLASS_CONSISTENCY=PASS")
    print("GC_FIXED_INTERFACE_G09D_EXECUTION=PASS")


if __name__=="__main__":
    main()
