from __future__ import annotations

import json
import math
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import AREA_M2,DAY_TO_S,initialize_case,solve_term

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G17_PREREGISTRATION.json"
G11=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G11_RESULT.json"

DURATION_DAY=1.0e-2
QBOT_CM_PER_DAY=1.0e-6
HREF_EXPECTED=-0.7149999311459918
U_EXPECTED=0.00119027208545508
K=1.0e-10
SS=0.0
HEAD_BIAS=-3.332218778007957e-5
QPROBES=(-2e-10,-1e-10,0.0,1e-10,2e-10)
SCALES_M=(2.5e-7,1.25e-7,6.25e-8,3.125e-8,1.5625e-8,7.8125e-9,3.90625e-9)
REL_TOL=0.05
FLUX_TOL=1.0e-15
MERIT_ABS_TOL=1.0e-18
MAX_OUTER=12
MAX_BACKTRACK=12
CLASS_FIELDS=("accepted_substeps","attempts","retries","solver_rejections","temporal_rejections","internal_retries","min_substep","max_substep")


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_authority()->dict[str,object]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G17","wrong G17 preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G17 preregistration not frozen")
    carrier=p["frozen_carrier"]
    require(float(carrier["duration_day"])==DURATION_DAY,"G17 duration drift")
    require(float(carrier["predictor_qbot_cm_per_day"])==QBOT_CM_PER_DAY,"G17 qbot drift")
    require(float(carrier["reference_head_m"])==HREF_EXPECTED,"G17 href prereg drift")
    require(float(carrier["predictor_u"])==U_EXPECTED,"G17 predictor-u prereg drift")
    gw=p["frozen_groundwater_stress"]
    require(float(gw["k_m_per_day"])==K,"G17 K drift")
    require(float(gw["ss_per_m"])==SS,"G17 Ss drift")
    require(float(gw["initial_head_bias_m"])==HEAD_BIAS,"G17 head-bias drift")
    require(tuple(float(x) for x in gw["q_probes_m_per_s"])==QPROBES,"G17 groundwater probes drift")
    require(float(gw["max_affine_fit_error_m_per_s"])==1.0e-16,"G17 groundwater fit gate drift")
    controller=p["frozen_controller"]
    require(str(controller["policy"])=="P4_E3","G17 policy drift")
    require(tuple(float(x) for x in controller["scale_ladder_m"])==SCALES_M,"G17 scale ladder drift")
    require(float(controller["convergence_flux_tolerance_m_per_s"])==FLUX_TOL,"G17 flux tolerance drift")
    require(float(controller["merit_absolute_tolerance_m_per_s"])==MERIT_ABS_TOL,"G17 merit tolerance drift")
    require(str(controller["safeguard"])=="factor-1/2 contraction","G17 safeguard drift")
    require(int(controller["max_outer"])==MAX_OUTER,"G17 outer budget drift")
    require(int(controller["max_backtrack"])==MAX_BACKTRACK,"G17 backtrack budget drift")
    require(bool(controller["no_policy_retuning"]),"G17 prereg permits policy retuning")
    frozen_classes=tuple(str(x) for x in controller["execution_class_fields"])
    require(frozen_classes==CLASS_FIELDS,"G17 execution-class contract drift")
    return p


def execution_class(obs:dict[str,object])->tuple[object,...]|None:
    if int(obs["participant_status"])!=0:
        return None
    if int(obs["result_status"])!=0 or not bool(obs["completed"]) or not bool(obs["candidate_ready"]):
        return None
    return tuple(obs[x] for x in CLASS_FIELDS)


def tangent_candidate(center:dict[str,object],samples:dict[int,dict[str,object]],d:float)->dict[str,object]|None:
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


def fit_groundwater(libmf6:Path,swaplib:Path,href:float,sy:float)->tuple[float,float,float]:
    points=[]
    for q in QPROBES:
        h,qgw,iters=solve_term(libmf6,swaplib,DURATION_DAY,href,K,SS,sy,HEAD_BIAS,0.0,-q*AREA_M2*DAY_TO_S)
        tol=64.0*sys.float_info.epsilon*max(1.0,abs(q))
        require(abs(qgw-q)<=tol,f"G17 constant-flux probe drift requested={q} got={qgw}")
        points.append((float(h),float(qgw),int(iters)))
    xm=sum(x[0] for x in points)/len(points)
    ym=sum(x[1] for x in points)/len(points)
    denom=sum((x[0]-xm)**2 for x in points)
    require(denom>0.0,"G17 degenerate groundwater fit")
    a=sum((x[0]-xm)*(x[1]-ym) for x in points)/denom
    b=ym-a*xm
    err=max(abs(a*x[0]+b-x[1]) for x in points)
    require(math.isfinite(a) and a>0.0,"G17 groundwater slope invalid")
    require(err<=1.0e-16,f"G17 groundwater fit error {err}")
    row={"a_per_s":a,"intercept":b,"max_fit_error_m_per_s":err,"points":[{"head_m":h,"q_m_per_s":q,"mf_iterations":it} for h,q,it in points]}
    print("FGC44_G17_GW_FIT_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
    return float(a),float(b),float(err)


class DiagnosticSession:
    def __init__(self,swap:Fgc44RealSwap,origin:tuple[int,float,int,float],a:float,b:float):
        self.swap=swap
        self.origin=origin
        self.a=a
        self.b=b
        self.unique:set[str]=set()
        self.status6=0

    def observe(self,head:float)->dict[str,object]:
        before=self.swap.g16_counts()
        obs=self.swap.g16_observe_head(head)
        after=self.swap.g16_counts()
        require(after[0]==before[0]+1,"G17 logical request did not increment")
        trial_delta=after[1]-before[1]
        hit_delta=after[2]-before[2]
        require((trial_delta,hit_delta) in ((1,0),(0,1)),"G17 invalid trial/cache accounting increment")
        key=float(head).hex()
        if trial_delta==1:
            require(key not in self.unique,"G17 duplicate physical trial for exact cached head")
            self.unique.add(key)
        else:
            require(key in self.unique,"G17 cache hit without prior physical trial")
        require(self.swap.state()==self.origin,"G17 diagnostic observation mutated accepted/ledger authority")
        require(not self.swap.g15_has_live_candidate(),"G17 diagnostic observation leaked live candidate")
        require(not self.swap.swap_preflight(),"G17 diagnostic observation acquired publication readiness")
        require(not self.swap.ledger_preflight(),"G17 diagnostic observation acquired ledger preflight authority")
        require(bool(obs["available"]),"G17 unavailable service observation")
        status=int(obs["participant_status"])
        require(bool(obs["q_available"])==(status==0),"G17 q authority inconsistent with participant status")
        if status==6:
            self.status6+=1
        return obs

    def residual(self,head:float)->tuple[dict[str,object],float|None]:
        obs=self.observe(head)
        if int(obs["participant_status"])!=0:
            return obs,None
        return obs,float(obs["q_swap_m_per_s"])-(self.a*head+self.b)

    def estimate_e3(self,head:float)->dict[str,object]:
        center=self.observe(head)
        if execution_class(center) is None:
            return {"classification":"CENTER_UNAVAILABLE"}
        previous=None
        for d in SCALES_M:
            samples={m:self.observe(head+m*d) for m in (-2,-1,0,1,2)}
            current=tangent_candidate(center,samples,d)
            if previous is not None and current is not None:
                s0=float(previous["slope_per_s"]); s1=float(current["slope_per_s"])
                rel=abs(s0-s1)/max(abs(s0),abs(s1))
                if rel<=REL_TOL:
                    return {
                        "classification":"AVAILABLE",
                        "mode":previous["mode"],
                        "slope_per_s":s0,
                        "selected_d_m":previous["scale_m"],
                        "confirming_mode":current["mode"],
                        "confirming_slope_per_s":s1,
                        "confirming_d_m":current["scale_m"],
                        "relative_difference":rel,
                    }
            previous=current
        return {"classification":"TANGENT_UNAVAILABLE"}


def solve_p4(libmf6:Path,swaplib:Path,swap:Fgc44RealSwap,session:DiagnosticSession,href:float,a:float,b:float,sy:float)->dict[str,object]:
    head=href
    contractions=0
    raw_inadmissible=0
    trace=[]
    first_raw=None
    for outer in range(1,MAX_OUTER+1):
        current,current_res=session.residual(head)
        if current_res is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer}
        if abs(current_res)<=FLUX_TOL:
            return {
                "classification":"CONVERGED","outer":outer-1,"final_head_m":head,
                "final_dh_m":head-href,"final_residual_m_per_s":current_res,
                "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                "first_raw":first_raw,"trace":trace,"final_observation":current,
            }
        est=session.estimate_e3(head)
        if est["classification"]!="AVAILABLE":
            return {"classification":"TANGENT_UNAVAILABLE","outer":outer,"estimator":est}
        p=float(est["slope_per_s"])
        slope_day=p*AREA_M2*DAY_TO_S
        rhs=slope_day*head-float(current["q_swap_m_per_s"])*AREA_M2*DAY_TO_S
        raw_head,_,mf_iters=solve_term(libmf6,swaplib,DURATION_DAY,href,K,SS,sy,HEAD_BIAS,slope_day,rhs)
        raw_obs,raw_res=session.residual(raw_head)
        raw_status=int(raw_obs["participant_status"])
        if raw_status!=0:
            raw_inadmissible+=1
        raw_bad=raw_status!=0 or raw_res is None or abs(raw_res)>abs(current_res)+MERIT_ABS_TOL
        if first_raw is None:
            first_raw={"head_m":raw_head,"dh_m":raw_head-href,"status":raw_status,"residual_m_per_s":raw_res,"bad":raw_bad}
        candidate=raw_head
        candidate_obs=raw_obs
        candidate_res=raw_res
        accepted=(raw_status==0 and candidate_res is not None and abs(candidate_res)<=abs(current_res)+MERIT_ABS_TOL)
        local=0
        while not accepted and local<MAX_BACKTRACK:
            candidate=head+0.5*(candidate-head)
            local+=1
            candidate_obs,candidate_res=session.residual(candidate)
            accepted=(int(candidate_obs["participant_status"])==0 and candidate_res is not None and abs(candidate_res)<=abs(current_res)+MERIT_ABS_TOL)
        contractions+=local
        if not accepted or candidate_res is None:
            return {"classification":"SAFEGUARD_EXHAUSTED","outer":outer,"contractions":contractions,"first_raw":first_raw,"trace":trace}
        row={
            "outer":outer,"current_head_m":head,"current_residual_m_per_s":current_res,
            "raw_head_m":raw_head,"raw_dh_m":raw_head-href,"raw_status":raw_status,"raw_residual_m_per_s":raw_res,
            "accepted_head_m":candidate,"accepted_dh_m":candidate-href,"accepted_residual_m_per_s":candidate_res,
            "local_contractions":local,"cumulative_contractions":contractions,
            "tangent_per_s":p,"tangent_mode":est["mode"],"tangent_d_m":est["selected_d_m"],
            "confirming_mode":est["confirming_mode"],"confirming_d_m":est["confirming_d_m"],
            "tangent_relative_difference":est["relative_difference"],"mf_iterations":int(mf_iters),
        }
        trace.append(row)
        print("FGC44_G17_TRACE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
        head=candidate
    return {"classification":"OUTER_BUDGET_EXHAUSTED","outer":MAX_OUTER,"contractions":contractions,"first_raw":first_raw,"trace":trace}


def publish_at_head(swap:Fgc44RealSwap,head:float,origin:tuple[int,float,int,float],cached_q:float|None)->dict[str,object]:
    require(not swap.g15_has_live_candidate(),"G17 publication started with live candidate")
    require(not swap.swap_preflight(),"G17 preflight true before final candidate")
    require(not swap.ledger_preflight(),"G17 ledger preflight true before prepare")
    direct_before=swap.g15_trial_call_count()
    status,q=swap.try_trial(head)
    direct_after=swap.g15_trial_call_count()
    require(status==0,"G17 final candidate reacquisition failed")
    require(direct_after==direct_before+1,"G17 final reacquisition was not exactly one ordinary participant trial")
    require(swap.g15_has_live_candidate(),"G17 final reacquisition did not leave live candidate")
    require(swap.state()==origin,"G17 final candidate trial mutated committed authority before publication")
    obs=swap.g15_last_trial_observation()
    require(bool(obs["available"]) and int(obs["participant_status"])==0 and bool(obs["q_available"]),"G17 final participant observation invalid")
    require(abs(float(obs["q_swap_m_per_s"])-q)<=1e-18,"G17 final participant observation q mismatch")
    if cached_q is not None:
        require(abs(q-cached_q)<=1e-18,"G17 reacquired final q differs from cached diagnostic q")
    require(swap.swap_preflight(),"G17 final candidate failed FMR preflight")
    require(not swap.ledger_preflight(),"G17 ledger preflight true before ledger prepare")
    q_diag,bottom_exchange_cm=swap.last_trial_diagnostics()
    require(abs(q_diag-q)<=1e-18,"G17 final last-trial diagnostic q mismatch")
    swap.prepare_ledger()
    require(swap.ledger_preflight(),"G17 prepared ledger failed preflight")
    require(swap.state()==origin,"G17 prepare/preflight mutated committed authority")
    swap.commit_swap()
    mid=swap.state()
    require(mid[0]==1 and math.isclose(mid[1],DURATION_DAY,rel_tol=0.0,abs_tol=1e-15),"G17 SWAP commit state invalid")
    require(mid[2]==0 and abs(mid[3])<=1e-30,"G17 ledger committed before explicit ledger commit")
    swap.commit_ledger()
    final=swap.state()
    expected_exchange=bottom_exchange_cm*0.01
    require(final[0]==1 and math.isclose(final[1],DURATION_DAY,rel_tol=0.0,abs_tol=1e-15),"G17 final committed FMR state invalid")
    require(final[2]==1,"G17 final committed ledger count invalid")
    require(math.isclose(final[3],expected_exchange,rel_tol=0.0,abs_tol=1e-18),"G17 final ledger exchange differs from final candidate")
    require(not swap.g15_has_live_candidate(),"G17 live candidate remained after commit")
    return {
        "head_m":head,"q_swap_m_per_s":q,"bottom_exchange_cm":bottom_exchange_cm,
        "expected_ledger_exchange_m":expected_exchange,
        "ordinary_trial_calls_before":direct_before,"ordinary_trial_calls_after":direct_after,
        "mid_state":list(mid),"final_state":list(final),
    }


def direct_publish_child(head:float)->None:
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G17 child href drift")
    result=publish_at_head(swap,head,origin,None)
    print("FGC44_G17_DIRECT_CHILD_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))


def main()->None:
    if len(sys.argv)==3 and sys.argv[1]=="--direct-publish":
        direct_publish_child(float(sys.argv[2]))
        return

    p=load_authority()
    g11=json.loads(G11.read_text())
    frozen_ref=p["frozen_reference_behavior"]
    g11_ref=g11["summary"]
    require(int(g11_ref["first_raw_status"])==int(frozen_ref["first_raw_participant_status"]),"G17/G11 first-raw status authority drift")
    require(float(g11_ref["first_raw_dh_m"])==float(frozen_ref["first_raw_dh_m"]),"G17/G11 first-raw head authority drift")
    require(int(g11_ref["p4_contractions"])==int(frozen_ref["expected_total_contractions"]),"G17/G11 contraction authority drift")
    require(float(g11_ref["p4_final_dh_m"])==float(frozen_ref["reference_final_dh_m"]),"G17/G11 final-head authority drift")
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing FGC44 SWAP library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(origin==(0,0.0,0,0.0),f"G17 dirty origin {origin}")
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G17 href authority drift")
    require(math.isclose(float(diag["u"]),U_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G17 predictor u authority drift")
    sy=0.5*float(diag["u"])
    a,b,fit_error=fit_groundwater(libmf6,swaplib,href,sy)

    require(swap.g15_trial_call_count()==0,"G17 ordinary participant trial count dirty before G16")
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),"G17 dirty G16 session counters")
    session=DiagnosticSession(swap,origin,a,b)
    result=solve_p4(libmf6,swaplib,swap,session,href,a,b,sy)
    require(result["classification"]=="CONVERGED",f"G17 P4 orchestration failed: {result}")
    require(result["first_raw"] is not None,"G17 missing first raw proposal")
    ref=frozen_ref
    require(int(result["first_raw"]["status"])==int(ref["first_raw_participant_status"])==6,"G17 first raw status drift")
    require(abs(float(result["first_raw"]["dh_m"])-float(ref["first_raw_dh_m"]))<=1e-12,"G17 first raw head drift")
    require(int(result["contractions"])==int(ref["expected_total_contractions"])==2,"G17 safeguard contraction count drift")
    require(abs(float(result["final_head_m"])-(HREF_EXPECTED+float(ref["reference_final_dh_m"])))<=1e-12,"G17 final head drift from preregistered G11 reference")
    require(abs(float(result["final_residual_m_per_s"]))<=FLUX_TOL,"G17 final residual above tolerance")

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2],"G17 service request accounting mismatch")
    require(counts[1]==counts[3]==len(session.unique),"G17 physical trial/unique cache accounting mismatch")
    require(session.status6>=1,"G17 did not exercise a status-6 diagnostic trial")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G17 diagnostic solve acquired authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G17 diagnostic solve reached publication preflight")
    require(swap.g15_trial_call_count()==0,"G17 diagnostic solve used ordinary publication trial path")
    accounting={
        "logical_requests":counts[0],"participant_trials":counts[1],"cache_hits":counts[2],
        "cached_heads":counts[3],"status6_observations":session.status6,
        "ordinary_publication_path_trials_during_diagnostics":swap.g15_trial_call_count(),
    }
    print("FGC44_G17_DIAGNOSTIC_ACCOUNTING_JSON="+json.dumps(accounting,sort_keys=True,separators=(",",":")))

    cached_final=result["final_observation"]
    require(int(cached_final["participant_status"])==0 and bool(cached_final["q_available"]),"G17 cached final diagnostic unavailable")
    cached_q=float(cached_final["q_swap_m_per_s"])
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),"G17 end_session did not clear service authority")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G17 session close changed authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G17 session close left publication authority")

    publication=publish_at_head(swap,float(result["final_head_m"]),origin,cached_q)
    print("FGC44_G17_PUBLICATION_JSON="+json.dumps(publication,sort_keys=True,separators=(",",":")))

    child=subprocess.run(
        [sys.executable,str(Path(__file__).resolve()),"--direct-publish",repr(float(result["final_head_m"]))],
        check=True,capture_output=True,text=True,env=os.environ.copy(),
    )
    marker="FGC44_G17_DIRECT_CHILD_JSON="
    line=next((x for x in child.stdout.splitlines() if x.startswith(marker)),None)
    require(line is not None,"G17 direct-publication control marker missing")
    direct=json.loads(line[len(marker):])
    require(direct["final_state"][0]==publication["final_state"][0],"G17 direct control revision mismatch")
    require(math.isclose(float(direct["final_state"][1]),float(publication["final_state"][1]),rel_tol=0.0,abs_tol=1e-15),"G17 direct control time mismatch")
    require(direct["final_state"][2]==publication["final_state"][2],"G17 direct control ledger count mismatch")
    require(math.isclose(float(direct["final_state"][3]),float(publication["final_state"][3]),rel_tol=0.0,abs_tol=1e-18),"G17 direct control ledger exchange mismatch")
    print("FGC44_G17_DIRECT_CONTROL_JSON="+json.dumps(direct,sort_keys=True,separators=(",",":")))

    summary={
        "classification":result["classification"],
        "first_raw_dh_m":result["first_raw"]["dh_m"],
        "first_raw_status":result["first_raw"]["status"],
        "p4_contractions":result["contractions"],
        "final_head_m":result["final_head_m"],
        "final_dh_m":result["final_dh_m"],
        "final_residual_m_per_s":result["final_residual_m_per_s"],
        "gw_fit_error_m_per_s":fit_error,
        "logical_requests":counts[0],"diagnostic_participant_trials":counts[1],
        "cache_hits":counts[2],"diagnostic_unique_heads":counts[3],
        "status6_observations":session.status6,
        "final_reacquisition_ordinary_trials":publication["ordinary_trial_calls_after"]-publication["ordinary_trial_calls_before"],
        "cached_vs_reacquired_q_diff_m_per_s":abs(publication["q_swap_m_per_s"]-cached_q),
        "direct_publication_equivalence":"PASS",
        "diagnostic_non_authority":"PASS",
        "nominal_preflight_publication_sequence":"PASS",
        "crash_atomicity_claim":"NOT_MADE",
        "persistent_modflow_transaction_publication_claim":"NOT_MADE",
    }
    print("FGC44_G17_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G17_DIAGNOSTIC_NON_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G17_FINAL_CANDIDATE_HANDOFF=PASS")
    print("GC_FIXED_INTERFACE_G17_NOMINAL_PUBLICATION=PASS")
    print("GC_FIXED_INTERFACE_G17_EXECUTION=PASS")


if __name__=="__main__":
    main()
