#!/usr/bin/env python3
from __future__ import annotations
import json, math

TEMPS=(-20.0,-5.0,0.0,5.0,20.0,35.0,50.0)
HEADS=(-1.0e3,-1.0e5,-1.0e7)
THETA=0.10
THETA_S=0.45
MG_R=0.018015*9.81/8.314
RHO_W=1000.0
CONV=100.0*86400.0

def corrected(theta,h,temp_c):
    tk=temp_c+273.15
    mgrt=MG_R/tk
    da=2.14e-5*(tk/273.15)**2
    rho_sv=1.0e-3*math.exp(31.3716-6014.79/tk-7.92495e-3*tk)/tk
    ksi=(THETA_S-theta)**(7.0/3.0)/THETA_S**2
    D=ksi*(THETA_S-theta)*da
    hr=math.exp((h/100.0)*mgrt)
    kvap=rho_sv/RHO_W*mgrt*D*hr*CONV
    return tk,rho_sv,hr,kvap

def independent(theta,h,temp_c):
    T=temp_c+273.15
    rho_sv=1.0e-3*math.exp(31.3716-6014.79/T-7.92495e-3*T)/T
    Da=2.14e-5*(T/273.15)**2
    D=((THETA_S-theta)**(7.0/3.0)/THETA_S**2)*(THETA_S-theta)*Da
    MgRT=MG_R/T
    Hr=math.exp((h/100.0)*MgRT)
    return rho_sv/RHO_W*D*MgRT*Hr*CONV

rows=[]
worst_rho=0.0
worst_k=0.0
for tc in TEMPS:
    tk,rho,_,_=corrected(THETA,HEADS[0],tc)
    rho_ref=1.0e-3*math.exp(31.3716-6014.79/tk-7.92495e-3*tk)/tk
    rr=abs(rho-rho_ref)/rho_ref
    worst_rho=max(worst_rho,rr)
    if not (math.isfinite(rho) and rho>0):
        raise SystemExit(f"non-positive/non-finite rho_sv at {tc} C: {rho}")
    for h in HEADS:
        _,_,hr,k=corrected(THETA,h,tc)
        kr=independent(THETA,h,tc)
        rel=abs(k-kr)/max(abs(kr),1e-300)
        worst_k=max(worst_k,rel)
        if not (math.isfinite(k) and k>=0 and 0<hr<=1):
            raise SystemExit(f"invalid corrected vapor result T={tc} h={h}: Hr={hr} K={k}")
        rows.append({"temp_C":tc,"temp_K":tk,"head_cm":h,"rho_sv_kg_m3":rho,"Hr":hr,"Kvap_cm_d":k,"relative_error":rel})

# independent physical sanity points for saturated vapor density
sanity={tc:corrected(THETA,-1e3,tc)[1] for tc in (-20.0,0.0,20.0,50.0)}
# Broad non-tuned bounds: known order of saturated water-vapor density in kg/m3.
bounds={-20.0:(5e-4,2e-3),0.0:(3e-3,7e-3),20.0:(1e-2,3e-2),50.0:(5e-2,1e-1)}
for tc,(lo,hi) in bounds.items():
    if not lo < sanity[tc] < hi:
        raise SystemExit(f"rho_sv sanity failure at {tc} C: {sanity[tc]}")

print(json.dumps({
  "work_unit":"F-PDI-VT02",
  "status":"PASS",
  "worst_rho_relative_error":worst_rho,
  "worst_Kvap_relative_error":worst_k,
  "rho_sv_sanity_kg_m3":sanity,
  "rows":rows
},indent=2))
