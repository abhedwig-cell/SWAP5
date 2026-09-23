#!/usr/bin/env python3
"""Materialize the prospectively bound ROM-ROOT-REF01 total-balance policy.

Applies only to a generated C6R root-active research harness. The steady seed
keeps the original strict C6R policy. Immediately before every root-active
Reference trial, only the total HeadCalc balance-rate discriminator is replaced
by the externally authorized P2E20 representation-floor formula:

  F_repr = sum_i(dz_i * spacing(theta_s_i))
  A_total = max(1.6e-15 cm, F_repr)
  CritDevBalTot = A_total / actual_trial_dt_day

No observed C6R/REF01 response enters this formula.
"""
from __future__ import annotations
import argparse
from pathlib import Path

MARKER="ROM_ROOT_REF01_REPRESENTATION_FLOOR"
DECL_OLD="    real(real64) :: root_rate,cumulative_root,observation_root\n"
DECL_NEW=DECL_OLD+"    real(real64) :: ref01_repr_floor_cm,ref01_total_allowance_cm\n"
SUBDT_OLD="    sub_dt=step_dt/real(substeps,real64)\n"
SUBDT_NEW=SUBDT_OLD+"""    ref01_repr_floor_cm=sum(p%dz*spacing(p%cofgen(2,:)))
    ref01_total_allowance_cm=max(1.6e-15_real64,ref01_repr_floor_cm)
    call require(ieee_is_finite(ref01_repr_floor_cm).and.ref01_repr_floor_cm>0.0_real64, &
         'ROM-ROOT REF01 finite positive representation floor')
    call require(ieee_is_finite(ref01_total_allowance_cm).and.ref01_total_allowance_cm>=1.6e-15_real64, &
         'ROM-ROOT REF01 finite total allowance')
    write(*,'(*(g0))') 'ROM_ROOT_REF01_POLICY|CASE=',trim(case_label(ih)), &
         '|F_REPR_CM=',ref01_repr_floor_cm,'|A_TOTAL_CM=',ref01_total_allowance_cm, &
         '|NOMINAL_DT_DAY=',sub_dt,'|NOMINAL_TOTAL_RATE=',ref01_total_allowance_cm/sub_dt, &
         '|LOCAL_RATE=',p%compartment_balance_tolerance,'|MAXIT=',p%max_iterations
"""
CALL_OLD="""        call evaluate_committed_root_sink(ih,p,state,forcing,root_rate)
        call strict_first_sample(column,template,p,state,forcing,sub_t0,sub_t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
"""
CALL_NEW="""        p%total_balance_tolerance=ref01_total_allowance_cm/(sub_t1-sub_t0)
        call require(ieee_is_finite(p%total_balance_tolerance).and.p%total_balance_tolerance>0.0_real64, &
             'ROM-ROOT REF01 finite total rate policy')
        call evaluate_committed_root_sink(ih,p,state,forcing,root_rate)
        call strict_first_sample(column,template,p,state,forcing,sub_t0,sub_t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
"""

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--path",required=True,type=Path)
    args=ap.parse_args()
    text=args.path.read_text()
    if MARKER in text:
        return 0
    text=one(text,DECL_OLD,DECL_NEW,"REF01 declaration")
    text=one(text,SUBDT_OLD,SUBDT_NEW+"    ! "+MARKER+"\n","REF01 floor setup")
    text=one(text,CALL_OLD,CALL_NEW,"REF01 per-trial policy")
    args.path.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
