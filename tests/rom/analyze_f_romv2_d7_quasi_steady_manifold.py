#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import preflight_f_romv2_d7_finite_domain_manifold as qs

HISTORIES=[*(f"D{i:02d}" for i in range(1,9)),*(f"V{i:02d}" for i in range(1,5))]
NSTEPS=64
DT=0.0008
LAYER=80.0
DEPTH=160.0
HARD_MASS=1e-12

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def parse_reference(path):
    states={}
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D7_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D7_REF_STATE|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]=r
    expected={(h,s) for h in HISTORIES for s in range(1,NSTEPS+1)}
    if set(states)!=expected:
        raise SystemExit(f"R16 state structure mismatch states={len(states)} expected={len(expected)}")
    return states

def qstats(values):
    vals=[float(x) for x in values]
    if not vals: return {"count":0}
    a=sorted(abs(x) for x in vals)
    return {"count":len(vals),"mean":sum(vals)/len(vals),
            "mean_abs":sum(abs(x) for x in vals)/len(vals),
            "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
            "p95_abs":a[min(len(a)-1,math.ceil(0.95*len(a))-1],
            "max_abs":a[-1]}

def sign(x):
    return 1 if x>0 else -1 if x<0 else 0

def reversals(flux):
    out=[]; prev=None
    for step in sorted(flux):
        s=sign(flux[step])
        if s==0: continue
        if prev is not None and s!=prev: out.append(step)
        prev=s
    return out

def forcing(symbol):
    k0=qs.k_of_h(H0)
    if symbol in ("TOP_PLUS","COMBINED_RISE_PLUS"): qtop=0.99*k0
    elif symbol in ("TOP_MINUS","COMBINED_FALL_MINUS"): qtop=1.01*k0
    elif symbol in ("HOLD","BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"): qtop=k0
    else: raise ValueError(f"unknown symbol {symbol}")
    if symbol in ("HOLD","TOP_PLUS","TOP_MINUS"):
        return qtop,2,None,k0
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):
        return qtop,5,0.75*H0,None
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):
        return qtop,5,1.25*H0,None
    raise ValueError(symbol)

def integrate_partition(hb,q):
    dy=DEPTH/qs.NINT
    h=hb
    lower=0.0
    upper=0.0
    for i in range(qs.NINT):
        def dh(x): return q/qs.k_of_h(x)-1.0
        k1h=dh(h); k1s=qs.theta_of_h(h)
        h2=h+0.5*dy*k1h; k2h=dh(h2); k2s=qs.theta_of_h(h2)
        h3=h+0.5*dy*k2h; k3h=dh(h3); k3s=qs.theta_of_h(h3)
        h4=h+dy*k3h; k4h=dh(h4); k4s=qs.theta_of_h(h4)
        h += dy*(k1h+2*k2h+2*k3h+k4h)/6.0
        ds=dy*(k1s+2*k2s+2*k3s+k4s)/6.0
        if i < qs.NINT//2: lower += ds
        else: upper += ds
        if not (math.isfinite(h) and h<0.0): raise ValueError("partition profile domain")
    return upper,lower,h

def root_q(storage,hb,counters):
    r=qs.q_search(storage,hb)
    counters["q_root_calls"]+=1
    counters["q_search_candidates"]+=int(r.get("search",{}).get("candidate_count",0))
    counters["q_search_finite_candidates"]+=int(r.get("search",{}).get("finite_count",0))
    if not r["ok"]: raise ValueError("q search no finite bracket")
    return float(r["root"])

def root_h(storage,q,counters):
    r=qs.h_search(storage,q)
    counters["h_root_calls"]+=1
    counters["h_search_candidates"]+=int(r.get("search",{}).get("candidate_count",0))
    counters["h_search_finite_candidates"]+=int(r.get("search",{}).get("finite_count",0))
    if not r["ok"]: raise ValueError("h search no finite bracket")
    return float(r["root"])

def terminal_profile(storage,mode,hb,qfixed,counters):
    if mode==2:
        h=root_h(storage,qfixed,counters)
        q=qfixed
    else:
        q=root_q(storage,hb,counters)
        h=hb
    upper,lower,top_h=integrate_partition(h,q)
    if abs((upper+lower)-storage)>5e-11:
        raise ValueError("terminal partition/storage reconstruction drift")
    return q,upper,lower,top_h

THETA0=qs.TR+qs.SE0*(qs.TS-qs.TR)
H0=qs.h_of_theta(THETA0)
K0=qs.k_of_h(H0)
S0=DEPTH*THETA0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--preflight",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()

    p=json.loads(pathlib.Path(a.prereg).read_text())
    pf=json.loads(pathlib.Path(a.preflight).read_text())
    ref=parse_reference(a.reference)
    assert p["phase"]=="PREREGISTERED_BEFORE_PREFLIGHT_OR_TRAJECTORY_EXECUTION"
    assert pf["decision"]=="D7_FINITE_DOMAIN_SEARCH_PREFLIGHT_PASS"
    assert pf["trajectory_evidence_consumed"] is False

    counters={"q_root_calls":0,"h_root_calls":0,"q_search_candidates":0,
              "q_search_finite_candidates":0,"h_search_candidates":0,"h_search_finite_candidates":0}
    max_mass=0.0
    failure=None
    by_history={}
    all_total=[]; all_upper=[]; all_lower=[]; all_cum=[]; all_q=[]
    total_sign_errors=0; reversal_mismatch_count=0

    for hist in HISTORIES:
        storage=S0
        cumulative=0.0
        ref_cumulative=0.0
        eT=[]; eU=[]; eL=[]; eC=[]; eQ=[]
        qhist={}; qref={}
        sign_errors=0
        try:
            # Two equilibrium seed intervals. qtop=qbottom=K0 => exact scalar storage equilibrium.
            for _ in range(2):
                mass=(storage-storage)-0.0016*K0+0.0016*K0
                if abs(mass)>HARD_MASS: raise ValueError("seed hard mass")
            for step in range(1,NSTEPS+1):
                rr=ref[(hist,step)]
                symbol=rr["SYMBOL"].strip()
                qtop,mode,hb,qfixed=forcing(symbol)

                if mode==2:
                    q1=qfixed
                else:
                    q1=root_q(storage,hb,counters)
                pred=storage+DT*(qtop-q1)
                if not (qs.TR*DEPTH < pred < qs.TS*DEPTH):
                    raise ValueError("predictor storage physical bound")

                if mode==2:
                    q2=qfixed
                else:
                    q2=root_q(pred,hb,counters)

                new_storage=storage+0.5*DT*((qtop-q1)+(qtop-q2))
                if not (qs.TR*DEPTH < new_storage < qs.TS*DEPTH):
                    raise ValueError("corrected storage physical bound")

                bex=0.5*DT*(q1+q2)
                top_exchange=-DT*qtop
                mass=new_storage-storage+top_exchange+bex
                if not math.isfinite(mass) or abs(mass)>HARD_MASS:
                    raise ValueError("hard transaction mass gate")

                qend,upper,lower,top_h=terminal_profile(new_storage,mode,hb,qfixed,counters)
                if not all(math.isfinite(x) for x in (qend,upper,lower,top_h)):
                    raise ValueError("nonfinite terminal profile")
                max_mass=max(max_mass,abs(mass))

                cumulative+=bex
                ref_cumulative+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
                rt=float(rr["TOTAL_STORAGE"]); ru=float(rr["UPPER_STORAGE"]); rl=float(rr["LOWER_STORAGE"])
                rq=float(rr["BOTTOM_FLUX"])
                et=new_storage-rt; eu=upper-ru; el=lower-rl; ec=cumulative-ref_cumulative; eq=qend-rq
                eT.append(et); eU.append(eu); eL.append(el); eC.append(ec); eQ.append(eq)
                qhist[step]=qend; qref[step]=rq
                if sign(qend)!=sign(rq): sign_errors+=1
                storage=new_storage
        except Exception as exc:
            failure={"history":hist,"step":step if 'step' in locals() else 0,"error":str(exc)}
            break

        cr=reversals(qhist); rrrev=reversals(qref)
        mismatch=(cr!=rrrev)
        total_sign_errors+=sign_errors; reversal_mismatch_count+=int(mismatch)
        by_history[hist]={
          "total_storage_error_cm":qstats(eT),
          "upper_storage_error_cm":qstats(eU),
          "lower_storage_error_cm":qstats(eL),
          "cumulative_bottom_exchange_error_cm":qstats(eC),
          "terminal_bottom_flux_error_cm_per_day":qstats(eQ),
          "bottom_flux_sign_error_count":sign_errors,
          "R16_reversal_steps":rrrev,
          "QS1_reversal_steps":cr,
          "reversal_sequence_mismatch":mismatch,
          "final_cumulative_bottom_exchange_error_cm":eC[-1],
          "R16_final_cumulative_bottom_exchange_cm":ref_cumulative,
          "relative_final_cumulative_bottom_exchange_error":eC[-1]/ref_cumulative if ref_cumulative else None,
        }
        all_total+=eT; all_upper+=eU; all_lower+=eL; all_cum+=eC; all_q+=eQ

    integrity=(failure is None and len(by_history)==12)
    pooled=None
    if integrity:
        pooled={
          "total_storage_error_cm":qstats(all_total),
          "upper_storage_error_cm":qstats(all_upper),
          "lower_storage_error_cm":qstats(all_lower),
          "cumulative_bottom_exchange_error_cm":qstats(all_cum),
          "terminal_bottom_flux_error_cm_per_day":qstats(all_q),
          "bottom_flux_sign_error_count":total_sign_errors,
          "history_reversal_sequence_mismatch_count":reversal_mismatch_count
        }

    r2=p["comparators"]["R2"]
    balance=transient=False
    if integrity:
        balance=(pooled["total_storage_error_cm"]["rmse"]<=r2["total_storage_rmse_cm"] and
                 pooled["cumulative_bottom_exchange_error_cm"]["rmse"]<=r2["cumulative_bottom_exchange_rmse_cm"])
        transient=(pooled["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=r2["terminal_bottom_flux_rmse_cm_per_day"] and
                   pooled["bottom_flux_sign_error_count"]<=r2["bottom_flux_sign_errors"])
    positive=integrity and (balance or transient)
    decision="QS1_HYDROLOGICALLY_WORTH_TABULATING" if positive else "QS1_NOT_WORTH_TABULATING_IN_EXPOSED_B01_DOMAIN"

    out={"schema":"swap5.f-romv2-d7.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D7",
         "decision":decision,"preflight_decision":pf["decision"],"integrity":{"pass":integrity,"failure":failure,
         "max_abs_transaction_mass_residual_cm":max_mass,"hard_mass_gate_cm":HARD_MASS},
         "candidate":{"id":"QS1","state_dimension":1,"trajectory_training":False,
                      "adaptive_dynamic_substeps":False,"full_order_fallback":False,"clipping":False},
         "pooled":pooled,"by_history":by_history,"search_diagnostics":counters,
         "R2_comparator":r2,
         "frontier":{"balance_view_pass":balance,"transient_view_pass":transient,
                     "non_dominated_on_at_least_one_preregistered_view":positive},
         "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"pooled":pooled,
                      "frontier":out["frontier"],"search_diagnostics":counters},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
