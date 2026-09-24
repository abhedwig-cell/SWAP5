#!/usr/bin/env python3
"""F-AHL10B: refine only conductivity on top of frozen F-AHL09 support."""
from __future__ import annotations
import json, pathlib, sys
import ahl09_derivative_consistent as dc

ROOT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl10b")
ROOT.mkdir(parents=True,exist_ok=True)
TOLS=[("k3",3e-3),("k1",1e-3),("k03",3e-4),("k01",1e-4)]

def logk(h,p):
    # Algebraically equivalent but cancellation-stable Mualem conductivity.
    tr,ts,a,n,ks,lam=p
    m=1.0-1.0/n
    theta,_,_=dc.base.evaluate_core(h,p)
    se=(theta-tr)/(ts-tr)
    if se>1.0-1.0e-6:
        k=ks
    else:
        u=se**(1.0/m)
        bracket=-__import__("math").expm1(m*__import__("math").log1p(-u))
        k=min(ks*se**lam*bracket*bracket,ks)
    return __import__("math").log(max(k,1e-300))

def k_interval_error(h0,h1,p):
    x0,x1=dc.x_from_h(h0),dc.x_from_h(h1)
    y0,y1=logk(h0,p),logk(h1,p)
    mx=0.0
    for f in (0.125,0.25,0.5,0.75,0.875):
        x=x0+f*(x1-x0)
        h=dc.h_from_x(x)
        truth=logk(h,p)
        interp=y0+f*(y1-y0)
        mx=max(mx,abs(interp-truth))
    return mx

def refine_k(h0,h1,p,tol,depth=0):
    if k_interval_error(h0,h1,p) <= tol:
        return [h0,h1]
    if depth>=30:
        raise RuntimeError(f"K refinement depth: h0={h0} h1={h1} tol={tol}")
    hm=dc.h_from_x(0.5*(dc.x_from_h(h0)+dc.x_from_h(h1)))
    left=refine_k(h0,hm,p,tol,depth+1)
    right=refine_k(hm,h1,p,tol,depth+1)
    return left[:-1]+right

def build_from_frozen_support(p,tol):
    dc.LOGK_TOL=1e-2
    base_knots=dc.build(p)
    knots=[]
    for h0,h1 in zip(base_knots[:-1],base_knots[1:]):
        seg=refine_k(h0,h1,p,tol)
        knots.extend(seg[:-1])
    knots.append(base_knots[-1])
    return knots

summary={"work_unit":"F-AHL10B","variants":{}}
for tag,tol in TOLS:
    out=ROOT/tag
    out.mkdir(parents=True,exist_ok=True)
    dc.OUT=out
    rows={}
    for mid,p in dc.base.MATERIALS.items():
        try:
            knots=build_from_frozen_support(p,tol)
            dc.LOGK_TOL=tol
            err=dc.validate(knots,p)
            dc.write_table(mid,p,knots)
            rows[mid]={
                "points":len(knots),
                "theta_span_error":err[0],
                "log_capacity_error":err[1],
                "log_conductivity_error":err[2],
                "constitutive_pass":err[0]<=dc.THETA_TOL and err[1]<=dc.LOGC_TOL and err[2]<=tol,
                "build_status":"PASS"
            }
        except RuntimeError as exc:
            rows[mid]={
                "build_status":"FAIL",
                "reason":str(exc)
            }
    summary["variants"][tag]={"logK_tolerance":tol,"materials":rows}
print(json.dumps(summary,indent=2,sort_keys=True))
