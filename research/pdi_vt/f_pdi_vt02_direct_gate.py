#!/usr/bin/env python3
from __future__ import annotations
import json, math

MGR=0.018015*9.81/8.314
RHOW=1000.0
CONV=100.0*86400.0
THETAS=0.45
THETA=0.10
P=7.0/3.0

TEMPS=(-20.0,-5.0,0.0,5.0,20.0,35.0,50.0)
HEADS=(-1e3,-1e5,-1e7)

def source_old(h,temp_c):
    mg_rt=MGR/(temp_c+273.15)
    da=2.14e-5*((temp_c+273.15)/273.15)**2
    rho=1e-3*math.exp(31.3716-6014.79/temp_c-7.92495e-3*temp_c)/temp_c
    f=rho/RHOW*mg_rt
    ksi=(THETAS-THETA)**P/THETAS**2
    d=ksi*(THETAS-THETA)*da
    hr=math.exp(h/100.0*mg_rt)
    return f*d*hr*CONV

def candidate(h,temp_c):
    tk=temp_c+273.15
    mg_rt=MGR/tk
    da=2.14e-5*(tk/273.15)**2
    rho=1e-3*math.exp(31.3716-6014.79/tk-7.92495e-3*tk)/tk
    f=rho/RHOW*mg_rt
    ksi=(THETAS-THETA)**P/THETAS**2
    d=ksi*(THETAS-THETA)*da
    hr=math.exp(h/100.0*mg_rt)
    return f*d*hr*CONV

def independent(h,temp_c):
    T=temp_c+273.15
    Da=2.14e-5*(T/273.15)**2
    rho_sv=1e-3/T*math.exp(31.3716-6014.79/T-7.92495e-3*T)
    mg_rt=MGR/T
    hr=math.exp(h/100.0*mg_rt)
    theta_a=THETAS-THETA
    xi=theta_a**(7.0/3.0)/THETAS**2
    D=xi*theta_a*Da
    return (rho_sv/RHOW*mg_rt)*D*hr*CONV

rows=[]
all_pass=True
for t in TEMPS:
    for h in HEADS:
        rec={"temperature_C":t,"head_cm":h}
        try:
            old=source_old(h,t)
            rec["old_value"]=old
            rec["old_finite"]=math.isfinite(old)
        except Exception as e:
            rec["old_value"]=None
            rec["old_finite"]=False
            rec["old_error"]=type(e).__name__+":"+str(e)
        c=candidate(h,t)
        ref=independent(h,t)
        rel=abs(c-ref)/max(abs(ref),1e-300)
        rec.update({
          "candidate_value":c,
          "independent_value":ref,
          "candidate_finite":math.isfinite(c),
          "candidate_nonnegative":c>=0.0,
          "candidate_relative_error":rel,
          "pass":math.isfinite(c) and c>=0.0 and rel<=1e-12
        })
        all_pass &= rec["pass"]
        rows.append(rec)
print(json.dumps({
  "work_unit":"F-PDI-VT02",
  "status":"PASS" if all_pass else "FAIL",
  "candidate_rule":"TK=TempC+273.15 used consistently in MgRT, Da, Rho_sv; signed h retained",
  "novap_semantics":"unchanged by construction; candidate modifies only vapor temperature conversion",
  "rows":rows
},indent=2))
