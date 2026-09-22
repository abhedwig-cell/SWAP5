from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"research"/"support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import AREA_M2,DAY_TO_S,solve_term

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12_PREREGISTRATION.json"

DURATION_DAY=1.0e-2
HREF_EXPECTED=0.012932896258566275
U_EXPECTED=0.0005760442426568357
QREF_EXPECTED=-6.459199925803855e-10
STARTS=(-1.0e-6,1.0e-6)
SCALES=(1.0e-6,5.0e-7,2.5e-7,1.25e-7,6.25e-8,3.125e-8,1.5625e-8,7.8125e-9)
SIG_INT_FIELDS=(
    "accepted_substeps","attempts","retries","solver_rejections",
    "temporal_rejections","internal_retries",
)
REL_TOL=0.05
GW_FIT_TOL=1.0e-16
FLUX_TOL=1.0e-15
MERIT_ABS_TOL=1.0e-18
MAX_OUTER=12
MAX_BACKTRACK=12
MASS_TOL_CM=1.0e-10
MAP09A_JR=-0.0005726906726621905
FGC44_MF_REFERENCE_HREF=-0.7149999706136307
MAP09_DATUM_SHIFT=HREF_EXPECTED-FGC44_MF_REFERENCE_HREF


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_prereg()->dict[str,object]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G12","wrong G12 preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G12 preregistration not frozen")
    c=p["carrier"]
    require(float(c["duration_day"])==DURATION_DAY,"G12 duration drift")
    require(float(c["reference_head_m"])==HREF_EXPECTED,"G12 href drift")
    require(float(c["predictor_u"])==U_EXPECTED,"G12 u drift")
    require(float(c["reference_q_swap_m_per_s"])==QREF_EXPECTED,"G12 qref drift")
    require(tuple(float(x) for x in c["start_offsets_m"])==STARTS,"G12 starts drift")
    require(tuple(float(x) for x in p["tangent_E3_MAP"]["scale_ladder_m"])==SCALES,"G12 scales drift")
    return p


def solve_term_map09(
    libmf6:Path,
    swaplib:Path,
    href:float,
    k:float,
    ss:float,
    sy:float,
    head_bias:float,
    hcof:float,
    rhs_swap:float,
)->tuple[float,float,int]:
    """Run unchanged F-GC44 MODFLOW geometry under a pure vertical datum translation."""
    href_mf=href-MAP09_DATUM_SHIFT
    rhs_mf=rhs_swap-hcof*MAP09_DATUM_SHIFT
    h_mf,q,iters=solve_term(
        libmf6,swaplib,DURATION_DAY,href_mf,k,ss,sy,head_bias,hcof,rhs_mf
    )
    return h_mf+MAP09_DATUM_SHIFT,q,iters


def initialize_checked(swap:Map09ActiveDrainageSwap)->tuple[float,dict[str,object],tuple[int,float,int,float]]:
    _,_,href=swap.initialize()
    pred=swap.predictor()
    require(swap.drainage_coverage(),"G12 MAP09 drainage coverage lost")
    require(bool(pred["mass_complete"]),"G12 MAP09 predictor mass incomplete")
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),f"G12 href drift {href}")
    require(math.isclose(float(pred["u"]),U_EXPECTED,rel_tol=0.0,abs_tol=1e-14),f"G12 u drift {pred['u']}")
    origin=swap.state()
    require(origin==(0,0.0,0,0.0),f"G12 dirty origin {origin}")
    return href,pred,origin


def trial_discard(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    head:float,
)->tuple[int,float]:
    status,q=swap.try_trial(head)
    if status==0:
        require(math.isfinite(q),"G12 nonfinite participant flux")
        swap.discard()
    require(swap.state()==origin,"G12 participant trial mutated accepted authority")
    return int(status),float(q)


def raw_ready(raw:dict[str,object])->bool:
    return int(raw["result_status"])==0 and bool(raw["completed"]) and bool(raw["candidate_ready"])


def sample(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    head:float,
)->dict[str,object]:
    status,q=trial_discard(swap,origin,head)
    raw=swap.corrector_diagnostics(head)
    require(swap.state()==origin,"G12 raw diagnostic mutated accepted authority")
    ready=(status==0 and raw_ready(raw))
    sig=None
    if ready:
        sig=tuple(
            [int(raw[k]) for k in SIG_INT_FIELDS]
            + [float(raw["min_accepted_substep_day"]),float(raw["max_accepted_substep_day"])]
        )
    return {
        "head_m":head,
        "participant_status":status,
        "q_swap_m_per_s":q if status==0 else None,
        "raw_ready":raw_ready(raw),
        "ready":ready,
        "signature":sig,
        "raw":raw,
    }


def same_class(*samples:dict[str,object])->bool:
    if not all(bool(s["ready"]) for s in samples):
        return False
    sigs=[s["signature"] for s in samples]
    return all(sig==sigs[0] for sig in sigs[1:])


def candidate_at_scale(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    head:float,
    d:float,
    cache:dict[str,dict[str,object]],
)->dict[str,object]:
    def get(h:float)->dict[str,object]:
        key=h.hex()
        if key not in cache:
            cache[key]=sample(swap,origin,h)
        return cache[key]

    c=get(head); m1=get(head-d); p1=get(head+d); m2=get(head-2*d); p2=get(head+2*d)
    out={
        "scale_m":d,"classification":"NO_STENCIL","mode":None,"slope_per_s":None,
        "center_signature":list(c["signature"]) if c["signature"] is not None else None,
        "minus1":{"status":m1["participant_status"],"signature":list(m1["signature"]) if m1["signature"] is not None else None},
        "plus1":{"status":p1["participant_status"],"signature":list(p1["signature"]) if p1["signature"] is not None else None},
        "minus2":{"status":m2["participant_status"],"signature":list(m2["signature"]) if m2["signature"] is not None else None},
        "plus2":{"status":p2["participant_status"],"signature":list(p2["signature"]) if p2["signature"] is not None else None},
    }
    slope=None
    if same_class(m1,p1):
        slope=(float(p1["q_swap_m_per_s"])-float(m1["q_swap_m_per_s"]))/(2*d)
        mode="CENTRAL_PAIR_CLASS"
    elif same_class(c,m1,m2):
        slope=(3*float(c["q_swap_m_per_s"])-4*float(m1["q_swap_m_per_s"])+float(m2["q_swap_m_per_s"]))/(2*d)
        mode="BACKWARD_CENTER_CLASS"
    elif same_class(c,p1,p2):
        slope=(-3*float(c["q_swap_m_per_s"])+4*float(p1["q_swap_m_per_s"])-float(p2["q_swap_m_per_s"]))/(2*d)
        mode="FORWARD_CENTER_CLASS"
    else:
        return out
    out["mode"]=mode
    out["slope_per_s"]=slope
    out["classification"]="CANDIDATE" if math.isfinite(slope) and slope<0 else "NONNEGATIVE_OR_NONFINITE"
    return out


def estimate_e3_map(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    head:float,
)->dict[str,object]:
    center=sample(swap,origin,head)
    if not bool(center["ready"]):
        return {"classification":"CENTER_UNAVAILABLE","center":center}
    cache={head.hex():center}
    candidates=[candidate_at_scale(swap,origin,head,d,cache) for d in SCALES]
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


def residual_at(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    head:float,
    a:float,
    b:float,
)->tuple[int,float|None,float|None]:
    status,q=trial_discard(swap,origin,head)
    if status!=0:
        return status,None,None
    return 0,q,q-(a*head+b)


def calibrate_groundwater(
    libmf6:Path,
    swaplib:Path,
    href:float,
    qref:float,
    p_href:float,
    regime:dict[str,object],
)->dict[str,object]:
    duration_s=DURATION_DAY*DAY_TO_S
    rule=str(regime["sy_rule"])
    if rule=="0.5*abs(p_href)*duration_seconds":
        sy=0.5*abs(p_href)*duration_s
    elif rule=="2.0*abs(p_href)*duration_seconds":
        sy=2.0*abs(p_href)*duration_s
    elif rule=="0.15":
        sy=0.15
    else:
        raise AssertionError(f"unknown G12 sy rule {rule}")

    k=float(regime["k_m_per_day"]); ss=float(regime["ss_per_m"])
    h0,q0,_=solve_term_map09(
        libmf6,swaplib,href,k,ss,sy,0.0,
        0.0,-qref*AREA_M2*DAY_TO_S,
    )
    require(abs(q0-qref)<=64*np.finfo(float).eps*max(1.0,abs(qref)),"G12 calibration flux drift")
    bias=href-h0

    offsets=(-2e-10,-1e-10,0.0,1e-10,2e-10)
    points=[]
    for dq in offsets:
        q=qref+dq
        h,qgw,iters=solve_term_map09(
            libmf6,swaplib,href,k,ss,sy,bias,
            0.0,-q*AREA_M2*DAY_TO_S,
        )
        require(abs(qgw-q)<=64*np.finfo(float).eps*max(1.0,abs(q)),"G12 groundwater probe flux drift")
        points.append({"q_m_per_s":q,"head_m":h,"mf_iterations":iters})
    heads=np.asarray([x["head_m"] for x in points],dtype=float)
    flux=np.asarray([x["q_m_per_s"] for x in points],dtype=float)
    a,b=np.polyfit(heads,flux,1)
    a=float(a); b=float(b)
    fit_error=float(np.max(np.abs(a*heads+b-flux)))
    require(math.isfinite(a) and a>0,"G12 groundwater slope invalid")
    require(fit_error<=GW_FIT_TOL,f"G12 groundwater fit error {fit_error}")
    href_res=qref-(a*href+b)
    require(abs(href_res)<=FLUX_TOL,f"G12 groundwater calibration missed href root {href_res}")
    return {
        "regime_id":regime["id"],"k_m_per_day":k,"ss_per_m":ss,"sy":sy,
        "head_bias_m":bias,"a_per_s":a,"intercept":b,
        "fit_error_m_per_s":fit_error,"href_residual_m_per_s":href_res,
        "points":points,
    }


def run_policy(
    policy:str,
    libmf6:Path,
    swaplib:Path,
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    href:float,
    start_dh:float,
    gw:dict[str,object],
)->dict[str,object]:
    head=href+start_dh
    contractions=0
    raw_inadmissible=0
    merit_increases=0
    modes=[]
    trace=[]
    a=float(gw["a_per_s"]); b=float(gw["intercept"])

    for outer in range(1,MAX_OUTER+1):
        status,q,res=residual_at(swap,origin,head,a,b)
        if status!=0 or q is None or res is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer,"status":status}
        if abs(res)<=FLUX_TOL:
            return {
                "classification":"CONVERGED","outer":outer-1,
                "final_head_m":head,"final_dh_m":head-href,
                "final_residual_m_per_s":res,
                "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                "merit_increases":merit_increases,"modes":modes,"trace":trace,
            }

        est=estimate_e3_map(swap,origin,head)
        if est["classification"]!="AVAILABLE":
            return {"classification":"TANGENT_UNAVAILABLE","outer":outer,"estimator":est}
        p=float(est["slope_per_s"]); modes.append(str(est["mode"]))
        slope_day=p*AREA_M2*DAY_TO_S
        rhs=slope_day*head-q*AREA_M2*DAY_TO_S
        raw_head,_,mf_iters=solve_term_map09(
            libmf6,swaplib,href,
            float(gw["k_m_per_day"]),float(gw["ss_per_m"]),float(gw["sy"]),
            float(gw["head_bias_m"]),slope_day,rhs,
        )
        raw_status,_,raw_res=residual_at(swap,origin,raw_head,a,b)
        if raw_status!=0:
            raw_inadmissible+=1

        if policy=="P1_E3_MAP":
            if raw_status!=0 or raw_res is None:
                return {
                    "classification":"RAW_PROPOSAL_INADMISSIBLE","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "modes":modes,"trace":trace,
                }
            candidate=raw_head; candidate_res=raw_res
            if abs(candidate_res)>abs(res)+MERIT_ABS_TOL:
                merit_increases+=1
        elif policy=="P4_E3_MAP":
            candidate=raw_head; candidate_status=raw_status; candidate_res=raw_res
            accepted=(
                candidate_status==0 and candidate_res is not None
                and abs(candidate_res)<=abs(res)+MERIT_ABS_TOL
            )
            local=0
            while not accepted and local<MAX_BACKTRACK:
                candidate=head+0.5*(candidate-head)
                local+=1
                candidate_status,_,candidate_res=residual_at(swap,origin,candidate,a,b)
                accepted=(
                    candidate_status==0 and candidate_res is not None
                    and abs(candidate_res)<=abs(res)+MERIT_ABS_TOL
                )
            contractions+=local
            if not accepted or candidate_res is None:
                return {
                    "classification":"SAFEGUARD_EXHAUSTED","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "modes":modes,"trace":trace,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer":outer,"current_head_m":head,"current_residual_m_per_s":res,
            "raw_head_m":raw_head,"raw_status":raw_status,"raw_residual_m_per_s":raw_res,
            "accepted_head_m":candidate,"accepted_residual_m_per_s":candidate_res,
            "tangent_per_s":p,"tangent_mode":est["mode"],
            "tangent_d_m":est["selected_d_m"],
            "confirming_mode":est["confirming_mode"],
            "confirming_d_m":est["confirming_d_m"],
            "tangent_relative_difference":est["relative_difference"],
            "cumulative_contractions":contractions,"mf_iterations":mf_iters,
        })
        head=candidate

    status,_,res=residual_at(swap,origin,head,a,b)
    return {
        "classification":"OUTER_BUDGET_EXHAUSTED","outer":MAX_OUTER,
        "status":status,"final_head_m":head,"final_dh_m":head-href,
        "final_residual_m_per_s":res,"contractions":contractions,
        "raw_inadmissible":raw_inadmissible,"merit_increases":merit_increases,
        "modes":modes,"trace":trace,
    }


def symmetric_decomposition(
    swap:Map09ActiveDrainageSwap,
    href:float,
    e3:dict[str,object],
)->dict[str,object]:
    if str(e3["mode"])!="CENTRAL_PAIR_CLASS":
        return {"classification":"NOT_SYMMETRIC","mode":e3["mode"],"selected_d_m":e3["selected_d_m"]}
    d=float(e3["selected_d_m"])
    minus=swap.corrector_mass_diagnostics(href-d)
    plus=swap.corrector_mass_diagnostics(href+d)
    for label,row in (("minus",minus),("plus",plus)):
        require(int(row["result_status"])==0 and bool(row["completed"]) and bool(row["candidate_ready"]),f"G12 {label} mass trial unavailable")
        require(bool(row["mass_complete"]),f"G12 {label} mass incomplete")
        require(abs(float(row["mass_residual_native"]))<=MASS_TOL_CM,f"G12 {label} mass residual")
    j_s=(float(plus["storage_change_native"])-float(minus["storage_change_native"]))*0.01/(2*d)
    j_r=(float(plus["bottom_outward_exchange_native"])-float(minus["bottom_outward_exchange_native"]))*0.01/(2*d)
    return {
        "classification":"SYMMETRIC",
        "selected_d_m":d,
        "J_S":j_s,"J_R":j_r,"J_nonbottom":j_s+j_r,
        "minus":minus,"plus":plus,
    }


def main()->None:
    p=load_prereg()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing MAP09 SWAP bridge library")

    swap=Map09ActiveDrainageSwap(swaplib)
    href,pred,origin=initialize_checked(swap)
    status,qref=trial_discard(swap,origin,href)
    require(status==0,"G12 MAP09 href corrector not admitted")
    require(math.isclose(qref,QREF_EXPECTED,rel_tol=0.0,abs_tol=1e-18),f"G12 qref drift {qref}")

    estimator_rows=[]
    for label,dh in (("HREF",0.0),("NEG",STARTS[0]),("POS",STARTS[1])):
        e3=estimate_e3_map(swap,origin,href+dh)
        require(e3["classification"]=="AVAILABLE",f"G12 E3_MAP unavailable {label}")
        require(float(e3["relative_difference"])<=REL_TOL,f"G12 E3_MAP inconsistent {label}")
        row={"label":label,"dh_m":dh,"e3":e3}
        estimator_rows.append(row)
        print("GC_G12_ESTIMATOR_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    href_e3=estimator_rows[0]["e3"]
    p_href=float(href_e3["slope_per_s"])
    expected_p=MAP09A_JR/(DURATION_DAY*DAY_TO_S)
    p_rel=abs(p_href-expected_p)/max(abs(p_href),abs(expected_p))
    require(p_rel<=0.01,f"G12 MAP09A tangent crosscheck failed {p_rel}")
    decomposition=symmetric_decomposition(swap,href,href_e3)
    print("GC_G12_DECOMPOSITION_JSON="+json.dumps(decomposition,sort_keys=True,separators=(",",":")))

    gw_rows=[]
    policy_rows=[]
    for regime in p["groundwater_regimes"]:
        gw=calibrate_groundwater(libmf6,swaplib,href,qref,p_href,dict(regime))
        gw_rows.append(gw)
        print("GC_G12_GROUNDWATER_JSON="+json.dumps(gw,sort_keys=True,separators=(",",":")))
        for side,dh in (("NEG",STARTS[0]),("POS",STARTS[1])):
            for policy in ("P1_E3_MAP","P4_E3_MAP"):
                result=run_policy(policy,libmf6,swaplib,swap,origin,href,dh,gw)
                row={"regime_id":gw["regime_id"],"start_side":side,"start_dh_m":dh,"policy":policy,**result}
                policy_rows.append(row)
                print("GC_G12_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    p1=[x for x in policy_rows if x["policy"]=="P1_E3_MAP"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3_MAP"]
    require(all(x["classification"]=="CONVERGED" for x in p4),f"G12 P4 process-diverse replay failure {p4}")
    require(swap.state()==origin,"G12 changed accepted MAP09 authority")

    summary={
        "active_drainage_coverage":bool(swap.drainage_coverage()),
        "href_e3_mode":href_e3["mode"],
        "href_e3_slope_per_s":p_href,
        "map09a_expected_slope_per_s":expected_p,
        "map09a_relative_difference":p_rel,
        "decomposition_classification":decomposition["classification"],
        "J_nonbottom":decomposition.get("J_nonbottom"),
        "groundwater_regime_count":len(gw_rows),
        "policy_case_count":len(policy_rows),
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
    }
    print("GC_G12_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_G12_MAP09_PROCESS_BINDING=PASS")
    print("GC_G12_MAP09A_TANGENT_CROSSCHECK=PASS")
    print("GC_G12_GROUNDWATER_ORACLES=PASS")
    print("GC_G12_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12_EXECUTION=PASS")


if __name__=="__main__":
    main()
