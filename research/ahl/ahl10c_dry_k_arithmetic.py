#!/usr/bin/env python3
"""F-AHL10C: diagnose very-dry Mualem conductivity cancellation."""
from __future__ import annotations
import json, math
import ahl01_adaptive_lookup as base

def standard_k(h,p):
    tr,ts,a,n,ks,lam=p
    m=1.0-1.0/n
    theta,_,_=base.evaluate_core(h,p)
    se=(theta-tr)/(ts-tr)
    if se>1.0-1.0e-6:
        return ks
    term=(1.0-se**(1.0/m))**m
    return min(ks*se**lam*(1.0-term)**2,ks)

def stable_k(h,p):
    tr,ts,a,n,ks,lam=p
    m=1.0-1.0/n
    theta,_,_=base.evaluate_core(h,p)
    se=(theta-tr)/(ts-tr)
    if se>1.0-1.0e-6:
        return ks
    u=se**(1.0/m)
    bracket=-math.expm1(m*math.log1p(-u))
    return min(ks*se**lam*bracket*bracket,ks)

rows={}
heads=[-1.0,-10.0,-100.0,-1e3,-1e4,-1e5,-5e5,-8e5,-8.7e5,-9e5,-1e6]
for mid,p in base.MATERIALS.items():
    vals=[]
    max_rel=0.0
    for h in heads:
        a=standard_k(h,p); b=stable_k(h,p)
        rel=abs(a-b)/max(abs(b),1e-300)
        max_rel=max(max_rel,rel)
        vals.append({"h_cm":h,"standard":a,"stable":b,"relative_difference":rel})
    rows[mid]={"max_relative_difference":max_rel,"samples":vals}
print(json.dumps({"work_unit":"F-AHL10C","materials":rows},indent=2,sort_keys=True))
