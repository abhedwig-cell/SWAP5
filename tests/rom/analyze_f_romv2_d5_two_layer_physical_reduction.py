#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

HISTORIES=[*(f"D{i:02d}" for i in range(1,9)),*(f"V{i:02d}" for i in range(1,5))]
NSTEPS=64
DT=0.0008
SE0=0.85
THETA_R=0.02
THETA_S=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
ELL=0.98087
LAYER=80.0
HARD_MASS=1.0e-12

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def parse_reference(path):
    states={}
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D5_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D5_REF_STATE|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]=r
    expected={(h,s) for h in HISTORIES for s in range(1,NSTEPS+1)}
    if set(states)!=expected:
        missing=sorted(expected-set(states))[:10]
        extra=sorted(set(states)-expected)[:10]
        raise SystemExit(f"reference state structure mismatch missing={missing} extra={extra}")
    return states

def qstats(values):
    vals=[float(x) for x in values]
    if not vals:
        return {"count":0}
    av=sorted(abs(x) for x in vals)
    return {
        "count":len(vals),
        "mean":sum(vals)/len(vals),
        "mean_abs":sum(abs(x) for x in vals)/len(vals),
        "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
        "p95_abs":av[min(len(av)-1,math.ceil(0.95*len(av))-1)],
        "max_abs":av[-1],
    }

def sgn(x):
    return 1 if x>0.0 else -1 if x<0.0 else 0

def reversals(flux_by_step):
    result=[]
    prev=None
    for step in sorted(flux_by_step):
        cur=sgn(flux_by_step[step])
        if cur==0:
            continue
        if prev is not None and cur!=prev:
            result.append(step)
        prev=cur
    return result

def in_bounds(theta):
    return math.isfinite(theta) and THETA_R < theta < THETA_S

def se_of_theta(theta):
    if not in_bounds(theta):
        raise ValueError("theta outside open constitutive domain")
    return (theta-THETA_R)/(THETA_S-THETA_R)

def h_of_theta(theta):
    se=se_of_theta(theta)
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def theta_of_h(h):
    if not math.isfinite(h):
        raise ValueError("nonfinite boundary head")
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    theta=THETA_R+(THETA_S-THETA_R)*se
    if not in_bounds(theta):
        raise ValueError("boundary theta outside open constitutive domain")
    return theta

def k_of_theta(theta):
    se=se_of_theta(theta)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

def harmonic(a,b):
    if not (math.isfinite(a) and math.isfinite(b) and a>0.0 and b>0.0):
        raise ValueError("invalid conductivity")
    return 2.0*a*b/(a+b)

THETA0=THETA_R+SE0*(THETA_S-THETA_R)
H0=h_of_theta(THETA0)
K0=k_of_theta(THETA0)

def forcing(symbol):
    if symbol in ("TOP_PLUS","COMBINED_RISE_PLUS"):
        qtop=0.99*K0
    elif symbol in ("TOP_MINUS","COMBINED_FALL_MINUS"):
        qtop=1.01*K0
    elif symbol in ("HOLD","BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"):
        qtop=K0
    else:
        raise ValueError(f"unknown forcing symbol {symbol}")

    if symbol in ("HOLD","TOP_PLUS","TOP_MINUS"):
        return qtop,2,None,K0
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):
        return qtop,5,0.75*H0,None
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):
        return qtop,5,1.25*H0,None
    raise ValueError(f"unknown forcing symbol {symbol}")

def q_internal(theta_u,theta_l):
    hu=h_of_theta(theta_u)
    hl=h_of_theta(theta_l)
    return harmonic(k_of_theta(theta_u),k_of_theta(theta_l))*(1.0-(hl-hu)/80.0)

def q_bottom(theta_l,bottom_mode,bottom_head,bottom_flux):
    if bottom_mode==2:
        return float(bottom_flux)
    if bottom_mode!=5:
        raise ValueError("unsupported bottom mode")
    theta_b=theta_of_h(float(bottom_head))
    kb=harmonic(k_of_theta(theta_l),k_of_theta(theta_b))
    return kb*(1.0-(float(bottom_head)-h_of_theta(theta_l))/40.0)

def derivative(theta_u,theta_l,symbol):
    qtop,mode,hb,qb_fixed=forcing(symbol)
    q12=q_internal(theta_u,theta_l)
    qb=q_bottom(theta_l,mode,hb,qb_fixed)
    return (qtop-q12)/LAYER,(q12-qb)/LAYER,qtop,q12,qb

def heun_step(theta_u,theta_l,symbol):
    du1,dl1,qtop,q12a,qba=derivative(theta_u,theta_l,symbol)
    pu=theta_u+DT*du1
    pl=theta_l+DT*dl1
    if not (in_bounds(pu) and in_bounds(pl)):
        return {"ok":False,"stage":"PREDICTOR_PHYSICAL_BOUND","theta_predictor":[pu,pl]}
    du2,dl2,qtop2,q12b,qbb=derivative(pu,pl,symbol)
    if qtop2!=qtop:
        raise RuntimeError("piecewise-constant forcing drift")
    nu=theta_u+0.5*DT*(du1+du2)
    nl=theta_l+0.5*DT*(dl1+dl2)
    if not (in_bounds(nu) and in_bounds(nl)):
        return {"ok":False,"stage":"CORRECTED_PHYSICAL_BOUND","theta_corrected":[nu,nl]}
    bex=0.5*DT*(qba+qbb)
    top_exchange=-qtop*DT
    terminal_q=q_bottom(nl,*forcing(symbol)[1:])
    mass=LAYER*(nu-theta_u)+LAYER*(nl-theta_l)+top_exchange+bex
    finite=all(math.isfinite(x) for x in (nu,nl,bex,top_exchange,terminal_q,mass,q12a,q12b,qba,qbb))
    if not finite:
        return {"ok":False,"stage":"NONFINITE"}
    if abs(mass)>HARD_MASS:
        return {"ok":False,"stage":"HARD_MASS_GATE","mass_residual_cm":mass}
    return {
        "ok":True,
        "theta_u":nu,"theta_l":nl,
        "bottom_exchange_cm":bex,
        "top_exchange_cm":top_exchange,
        "terminal_bottom_flux_cm_per_day":terminal_q,
        "mass_residual_cm":mass,
        "q12_stage1":q12a,"q12_stage2":q12b,
    }

def seed_state():
    u=l=THETA0
    max_mass=0.0
    # exact equilibrium forcing: prescribed qtop=qbottom=K0.
    for _ in range(2):
        du1=(K0-q_internal(u,l))/LAYER
        dl1=(q_internal(u,l)-K0)/LAYER
        pu=u+0.0016*du1
        pl=l+0.0016*dl1
        q12b=q_internal(pu,pl)
        du2=(K0-q12b)/LAYER
        dl2=(q12b-K0)/LAYER
        nu=u+0.5*0.0016*(du1+du2)
        nl=l+0.5*0.0016*(dl1+dl2)
        mass=LAYER*(nu-u)+LAYER*(nl-l)-K0*0.0016+K0*0.0016
        if not (in_bounds(nu) and in_bounds(nl) and abs(mass)<=HARD_MASS):
            raise RuntimeError("seed integrity failure")
        max_mass=max(max_mass,abs(mass))
        u,l=nu,nl
    return u,l,max_mass

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--d4-result",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    prereg=json.loads(pathlib.Path(args.prereg).read_text())
    d4=json.loads(pathlib.Path(args.d4_result).read_text())
    ref=parse_reference(args.reference)

    if prereg["candidate"]["id"]!="L2_IMC":
        raise SystemExit("candidate identity drift")
    if prereg["time_integration"]["method"]!="single explicit Heun predictor-corrector per declared observation interval":
        raise SystemExit("integrator drift")
    if prereg["candidate"]["adaptive_substepping_allowed"] is not False or prereg["candidate"]["clipping_allowed"] is not False:
        raise SystemExit("candidate firewall drift")
    if d4["decision"]!="STRONGLY_COARSE_RICHARDS_HYDROLOGICALLY_MEASURABLE_UNDER_INTEGRATED_MASS_POLICY":
        raise SystemExit("D4 comparator authority drift")

    all_total=[]; all_upper=[]; all_lower=[]; all_cum=[]; all_q=[]
    by_history={}
    max_mass=0.0
    integrity_failure=None
    total_sign_errors=0
    reversal_mismatches=0
    seed_u,seed_l,seed_max_mass=seed_state()
    max_mass=max(max_mass,seed_max_mass)

    for hist in HISTORIES:
        u,l=seed_u,seed_l
        cum=0.0
        refcum=0.0
        e_total=[]; e_upper=[]; e_lower=[]; e_cum=[]; e_q=[]
        candidate_flux={}; reference_flux={}
        sign_errors=0
        final_ref_cum=None
        final_candidate_cum=None

        for step in range(1,NSTEPS+1):
            rr=ref[(hist,step)]
            symbol=rr["SYMBOL"].strip()
            out=heun_step(u,l,symbol)
            if not out["ok"]:
                integrity_failure={"history":hist,"step":step,"symbol":symbol,**out}
                break
            u=out["theta_u"]; l=out["theta_l"]
            max_mass=max(max_mass,abs(out["mass_residual_cm"]))
            cum += out["bottom_exchange_cm"]
            refcum += float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            total=LAYER*u+LAYER*l
            upper=LAYER*u
            lower=LAYER*l
            ref_total=float(rr["TOTAL_STORAGE"])
            ref_upper=float(rr["UPPER_STORAGE"])
            ref_lower=float(rr["LOWER_STORAGE"])
            ref_q=float(rr["BOTTOM_FLUX"])
            q=out["terminal_bottom_flux_cm_per_day"]
            et=total-ref_total; eu=upper-ref_upper; el=lower-ref_lower; ec=cum-refcum; eq=q-ref_q
            e_total.append(et); e_upper.append(eu); e_lower.append(el); e_cum.append(ec); e_q.append(eq)
            candidate_flux[step]=q; reference_flux[step]=ref_q
            if sgn(q)!=sgn(ref_q):
                sign_errors+=1
            final_ref_cum=refcum; final_candidate_cum=cum

        if integrity_failure is not None:
            break

        cr=reversals(candidate_flux)
        rr_rev=reversals(reference_flux)
        mismatch=(cr!=rr_rev)
        total_sign_errors+=sign_errors
        reversal_mismatches+=int(mismatch)
        by_history[hist]={
            "total_storage_error_cm":qstats(e_total),
            "upper_storage_error_cm":qstats(e_upper),
            "lower_storage_error_cm":qstats(e_lower),
            "cumulative_bottom_exchange_error_cm":qstats(e_cum),
            "terminal_bottom_flux_error_cm_per_day":qstats(e_q),
            "bottom_flux_sign_error_count":sign_errors,
            "R16_reversal_steps":rr_rev,
            "L2_IMC_reversal_steps":cr,
            "reversal_sequence_mismatch":mismatch,
            "final_cumulative_bottom_exchange_error_cm":e_cum[-1],
            "R16_final_cumulative_bottom_exchange_cm":final_ref_cum,
            "relative_final_cumulative_bottom_exchange_error":e_cum[-1]/final_ref_cum if final_ref_cum else None,
        }
        all_total+=e_total; all_upper+=e_upper; all_lower+=e_lower; all_cum+=e_cum; all_q+=e_q

    integrity_pass=integrity_failure is None and len(by_history)==len(HISTORIES)
    pooled={
        "total_storage_error_cm":qstats(all_total),
        "upper_storage_error_cm":qstats(all_upper),
        "lower_storage_error_cm":qstats(all_lower),
        "cumulative_bottom_exchange_error_cm":qstats(all_cum),
        "terminal_bottom_flux_error_cm_per_day":qstats(all_q),
        "bottom_flux_sign_error_count":total_sign_errors,
        "history_reversal_sequence_mismatch_count":reversal_mismatches,
    } if integrity_pass else None

    r2=prereg["preexisting_comparators"]["R2"]
    balance_positive=False
    transient_positive=False
    if integrity_pass:
        balance_positive=(
            pooled["total_storage_error_cm"]["rmse"] <= float(r2["total_storage_rmse_cm"])
            and pooled["cumulative_bottom_exchange_error_cm"]["rmse"] <= float(r2["cumulative_bottom_exchange_rmse_cm"])
        )
        transient_positive=(
            pooled["terminal_bottom_flux_error_cm_per_day"]["rmse"] <= float(r2["terminal_bottom_flux_rmse_cm_per_day"])
            and pooled["bottom_flux_sign_error_count"] <= int(r2["bottom_flux_sign_errors"])
        )

    positive=integrity_pass and (balance_positive or transient_positive)
    decision=("L2_IMC_REMAINS_SERIOUS_BALANCE_FOCUSED_PHYSICAL_REDUCTION_CANDIDATE"
              if positive else "L2_IMC_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN")

    result={
        "schema":"swap5.f-romv2-d5.result.v1",
        "workstream":"F-ROM",
        "work_unit":"F-ROMV2-D5",
        "decision":decision,
        "blind_confirmation":False,
        "application_acceptance":False,
        "candidate":{
            "id":"L2_IMC",
            "state_dimension":2,
            "training_required":False,
            "nonlinear_Richards_solve_required":False,
            "adaptive_substepping_used":False,
            "clipping_used":False,
            "full_order_fallback_used":False,
        },
        "constitutive_identity":{
            "theta_r":THETA_R,"theta_s":THETA_S,"alpha_per_cm":ALPHA,"n":N,"m":M,
            "Ksat_cm_per_day":KS,"Mualem_l":ELL,"initial_h_cm":H0,"initial_K_cm_per_day":K0
        },
        "integrity":{
            "pass":integrity_pass,
            "failure":integrity_failure,
            "max_abs_transaction_mass_residual_cm":max_mass,
            "hard_mass_gate_cm":HARD_MASS,
        },
        "pooled":pooled,
        "by_history":by_history,
        "preexisting_R2_comparator":r2,
        "development_frontier_test":{
            "balance_view_pass":balance_positive,
            "transient_view_pass":transient_positive,
            "non_dominated_on_at_least_one_preregistered_view":positive,
            "formal_performance_claim":False,
        },
        "purpose_dependent_interpretation":{
            "LONG_TERM_REGIONAL_WATER_BALANCE":"ARCHITECTURE_RETAINS_CANDIDACY_NOT_APPLICATION_QUALIFICATION" if positive else "NOT_RETAINED_BY_D5_COMPARATIVE_FRONTIER",
            "OPERATIONAL_SOIL_MOISTURE_DROUGHT":"NOT_TESTED",
            "GROUNDWATER_COUPLED_MANY_COLUMN":"NOT_QUALIFIED",
            "FAST_EVENT_THRESHOLD":"NOT_QUALIFIED",
            "SCIENTIFIC_PROCESS_OR_EXTREME_INFERENCE":"NOT_QUALIFIED",
        },
        "scientific_boundary":"Development architecture discrimination on exposed B01 hydraulic histories only. No application tolerance or formal speedup is inferred.",
        "production_rom_authorized":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "integrity":result["integrity"],
        "pooled":pooled,
        "development_frontier_test":result["development_frontier_test"],
        "history_summary":{h:{
            "cum_rmse":v["cumulative_bottom_exchange_error_cm"]["rmse"],
            "q_rmse":v["terminal_bottom_flux_error_cm_per_day"]["rmse"],
            "sign_errors":v["bottom_flux_sign_error_count"],
            "reversal_mismatch":v["reversal_sequence_mismatch"],
            "relative_final_cum":v["relative_final_cumulative_bottom_exchange_error"],
        } for h,v in by_history.items()},
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
