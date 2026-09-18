from __future__ import annotations

import json
import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Any

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

MAX_EVALS=20
FLUX_TOL_M_PER_S=1.0e-15
INITIAL_HEAD_OFFSET_M=1.0e-6
C_VALUES=(0.1,0.5,0.9,1.1,1.5,2.0)

@dataclass
class Eval:
    h: float
    v: float
    f: float
    phi: float
    status: str

class Problem:
    def __init__(self, baseline: dict[str,Any], lib: Path) -> None:
        self.baseline=baseline
        self.window=float(baseline["window_day"])
        self.q0=float(baseline["qbot_cm_per_day"])
        self.u_A=float(baseline["u_A"])
        self.J_R=float(baseline["J_R"])
        self.swap=Fgc44RealSwap(lib)
        _,_,self.href=self.swap.initialize_configured(self.window,self.q0)
        self.origin_state=self.swap.state()
        ref=self._raw_trial(self.href)
        if ref["status"]!="OK":
            raise RuntimeError(f"reference head trial failed: {ref}")
        self.vref=float(ref["v_m"])
        self.reference_eval=ref

    def _raw_trial(self,h:float)->dict[str,Any]:
        before=self.swap.state()
        r=self.swap.e4_head_trial(float(h))
        after=self.swap.state()
        if after!=before:
            raise RuntimeError(f"head trial changed authoritative state: before={before} after={after}")
        if not bool(r["valid"]):
            return {"status":"SWAP_DOMAIN_FAIL","code":int(r["status"]),"h_m":float(h)}
        if not bool(r["mass_complete"]):
            raise RuntimeError("successful head trial has incomplete mass")
        v=float(r["bottom_outward_exchange_cm"])*0.01
        if not math.isfinite(v):
            raise RuntimeError("nonfinite E5 transfer")
        return {
            "status":"OK",
            "h_m":float(h),
            "v_m":v,
            "q_swap_m_per_s":float(r["q_swap_m_per_s"]),
            "mass_residual_native":float(r["mass_residual_native"]),
        }

    def evaluator(self,gamma:float):
        count=0
        trace:list[dict[str,Any]]=[]
        vtol=FLUX_TOL_M_PER_S*self.window*86400.0
        def evaluate(h:float)->Eval:
            nonlocal count
            if count>=MAX_EVALS:
                return Eval(h,math.nan,math.nan,math.nan,"MAX_EVALS")
            count+=1
            raw=self._raw_trial(h)
            if raw["status"]!="OK":
                trace.append({"eval":count,**raw})
                return Eval(h,math.nan,math.nan,math.nan,raw["status"])
            v=float(raw["v_m"])
            vgw=self.vref+(float(h)-self.href)/gamma
            f=v-vgw
            phi=self.href+gamma*(v-self.vref)
            trace.append({
                "eval":count,
                "h_m":float(h),
                "v_m":v,
                "v_gw_m":vgw,
                "transfer_residual_m":f,
                "head_fixed_point_residual_m":phi-float(h),
                "mass_residual_native":raw["mass_residual_native"],
            })
            return Eval(float(h),v,f,phi,"OK")
        return evaluate,trace,lambda:count,vtol

def outcome(status:str,method:str,C:float,eval_count:int,trace:list[dict[str,Any]],h:float|None,vtol:float,extra:dict[str,Any]|None=None)->dict[str,Any]:
    rec={
        "method":method,
        "C":C,
        "status":status,
        "swap_evaluations":eval_count,
        "trace":trace,
        "transfer_tolerance_m":vtol,
    }
    if h is not None and math.isfinite(h):
        rec["final_head_m"]=h
    if trace and "transfer_residual_m" in trace[-1]:
        rec["final_transfer_residual_m"]=trace[-1]["transfer_residual_m"]
    if extra:
        rec.update(extra)
    return rec

def run_fp(p:Problem,C:float,gamma:float)->dict[str,Any]:
    ev,tr,n,vtol=p.evaluator(gamma)
    h=p.href+INITIAL_HEAD_OFFSET_M
    while n()<MAX_EVALS:
        e=ev(h)
        if e.status!="OK":
            return outcome(e.status,"FP",C,n(),tr,h,vtol)
        if abs(e.f)<=vtol:
            return outcome("CONVERGED","FP",C,n(),tr,h,vtol)
        h=e.phi
    return outcome("MAX_EVALS","FP",C,n(),tr,h,vtol)

def run_aitken(p:Problem,C:float,gamma:float)->dict[str,Any]:
    ev,tr,n,vtol=p.evaluator(gamma)
    h=p.href+INITIAL_HEAD_OFFSET_M
    omega=1.0
    prev_r=None
    while n()<MAX_EVALS:
        e=ev(h)
        if e.status!="OK":
            return outcome(e.status,"AITKEN",C,n(),tr,h,vtol,{"omega":omega})
        if abs(e.f)<=vtol:
            return outcome("CONVERGED","AITKEN",C,n(),tr,h,vtol,{"omega":omega})
        r=e.phi-h
        if prev_r is not None:
            denom=r-prev_r
            scale=max(abs(r),abs(prev_r),1.0e-30)
            if abs(denom)<=64.0*sys.float_info.epsilon*scale:
                return outcome("AITKEN_BREAKDOWN","AITKEN",C,n(),tr,h,vtol,{"omega":omega})
            omega=-omega*prev_r/denom
            if not math.isfinite(omega):
                return outcome("AITKEN_BREAKDOWN","AITKEN",C,n(),tr,h,vtol)
        hnew=h+omega*r
        if not math.isfinite(hnew):
            return outcome("AITKEN_BREAKDOWN","AITKEN",C,n(),tr,h,vtol,{"omega":omega})
        prev_r=r
        h=hnew
    return outcome("MAX_EVALS","AITKEN",C,n(),tr,h,vtol,{"omega":omega})

def run_secant(p:Problem,C:float,gamma:float)->dict[str,Any]:
    ev,tr,n,vtol=p.evaluator(gamma)
    h0=p.href+INITIAL_HEAD_OFFSET_M
    e0=ev(h0)
    if e0.status!="OK":
        return outcome(e0.status,"SECANT_COLD",C,n(),tr,h0,vtol)
    if abs(e0.f)<=vtol:
        return outcome("CONVERGED","SECANT_COLD",C,n(),tr,h0,vtol)
    h1=e0.phi
    e1=ev(h1)
    if e1.status!="OK":
        return outcome(e1.status,"SECANT_COLD",C,n(),tr,h1,vtol)
    if abs(e1.f)<=vtol:
        return outcome("CONVERGED","SECANT_COLD",C,n(),tr,h1,vtol)
    while n()<MAX_EVALS:
        denom=e1.f-e0.f
        scale=max(abs(e1.f),abs(e0.f),1.0e-30)
        if abs(denom)<=64.0*sys.float_info.epsilon*scale:
            return outcome("SECANT_BREAKDOWN","SECANT_COLD",C,n(),tr,h1,vtol)
        h2=h1-e1.f*(h1-h0)/denom
        if not math.isfinite(h2):
            return outcome("SECANT_BREAKDOWN","SECANT_COLD",C,n(),tr,h1,vtol)
        e2=ev(h2)
        if e2.status!="OK":
            return outcome(e2.status,"SECANT_COLD",C,n(),tr,h2,vtol)
        if abs(e2.f)<=vtol:
            return outcome("CONVERGED","SECANT_COLD",C,n(),tr,h2,vtol)
        h0,e0=h1,e1
        h1,e1=h2,e2
    return outcome("MAX_EVALS","SECANT_COLD",C,n(),tr,h1,vtol)

def run_newton_fixed(p:Problem,C:float,gamma:float,method:str,j:float)->dict[str,Any]:
    ev,tr,n,vtol=p.evaluator(gamma)
    deriv=j-1.0/gamma
    if not math.isfinite(deriv) or abs(deriv)<=1.0e-30:
        return outcome("DERIVATIVE_BREAKDOWN",method,C,0,tr,None,vtol,{"response_derivative":j})
    h=p.href+INITIAL_HEAD_OFFSET_M
    while n()<MAX_EVALS:
        e=ev(h)
        if e.status!="OK":
            return outcome(e.status,method,C,n(),tr,h,vtol,{"response_derivative":j})
        if abs(e.f)<=vtol:
            return outcome("CONVERGED",method,C,n(),tr,h,vtol,{"response_derivative":j})
        hnew=h-e.f/deriv
        if not math.isfinite(hnew):
            return outcome("DERIVATIVE_BREAKDOWN",method,C,n(),tr,h,vtol,{"response_derivative":j})
        h=hnew
    return outcome("MAX_EVALS",method,C,n(),tr,h,vtol,{"response_derivative":j})

def main()->None:
    baseline_id=os.environ["E5_BASELINE_ID"]
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    e4_path=Path(os.environ.get(
        "E5_E4_RESULT",
        ROOT/"docs"/"publication"/"PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json",
    ))
    data=json.loads(e4_path.read_text())
    matches=[b for b in data["baselines"] if b["id"]==baseline_id]
    if len(matches)!=1:
        raise SystemExit(f"missing E4 baseline {baseline_id}")
    baseline=matches[0]
    if baseline.get("J_R") is None:
        raise SystemExit(f"baseline {baseline_id} has no J_R oracle")

    p=Problem(baseline,lib)
    # E4 dependency parity: the bridge should reproduce the same supplied u_A
    # through the configured predictor response. The E4 JSON remains the
    # authoritative frozen response value for this E5 experiment.
    results=[]
    for C in C_VALUES:
        gamma=C/abs(p.J_R)
        results.extend([
            run_fp(p,C,gamma),
            run_aitken(p,C,gamma),
            run_secant(p,C,gamma),
            run_newton_fixed(p,C,gamma,"U_A", -p.u_A),
            run_newton_fixed(p,C,gamma,"ORACLE_JR", p.J_R),
        ])

    for r in results:
        if "final_head_m" in r:
            r["final_head_error_m"]=abs(float(r["final_head_m"])-p.href)

    out={
        "schema":"pub-gc-e5-information-value-baseline-v1",
        "baseline_id":baseline_id,
        "window_day":p.window,
        "qbot_cm_per_day":p.q0,
        "H_ref_m":p.href,
        "V_ref_m":p.vref,
        "u_A":p.u_A,
        "J_u":-p.u_A,
        "J_R":p.J_R,
        "initial_head_offset_m":INITIAL_HEAD_OFFSET_M,
        "max_swap_evaluations":MAX_EVALS,
        "flux_tolerance_m_per_s":FLUX_TOL_M_PER_S,
        "results":results,
        "authority_state_final":p.swap.state(),
        "authority_state_origin":p.origin_state,
    }
    if out["authority_state_final"]!=out["authority_state_origin"]:
        raise AssertionError("E5 trials changed authoritative SWAP/ledger state")
    print("E5_JSON="+json.dumps(out,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
