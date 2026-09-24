#!/usr/bin/env python3
"""F-AHL10D: dry-end relevance-bounded derivative-consistent table builder."""
from __future__ import annotations
import json, math, pathlib, sys
import ahl09_derivative_consistent as dc

ROOT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl10d")
ROOT.mkdir(parents=True,exist_ok=True)
C_STOP=1e-13
H_NOMINAL=-1e6
H_MAX=-1.0
TOLS=[("k1",1e-3),("k03",3e-4),("k01",1e-4)]

def raw_c(h,p):
    return dc.base.evaluate_core(h,p)[1]

def dry_bound(p):
    if raw_c(H_NOMINAL,p) >= C_STOP:
        return H_NOMINAL
    lo,hi=math.log10(1.0),math.log10(abs(H_NOMINAL))
    # find largest magnitude where C ~= threshold
    for _ in range(100):
        m=0.5*(lo+hi)
        h=-(10.0**m)
        if raw_c(h,p) > C_STOP:
            lo=m
        else:
            hi=m
    return -(10.0**(0.5*(lo+hi)))

def stable_logk(h,p):
    tr,ts,a,n,ks,lam=p
    m=1.0-1.0/n
    theta,_,_=dc.base.evaluate_core(h,p)
    se=(theta-tr)/(ts-tr)
    if se>1.0-1.0e-6:
        k=ks
    else:
        u=se**(1.0/m)
        bracket=-math.expm1(m*math.log1p(-u))
        k=min(ks*se**lam*bracket*bracket,ks)
    return math.log(max(k,1e-300))

def kerr(h0,h1,p):
    x0,x1=dc.x_from_h(h0),dc.x_from_h(h1)
    y0,y1=stable_logk(h0,p),stable_logk(h1,p)
    mx=0.0
    for f in (0.125,0.25,0.5,0.75,0.875):
        x=x0+f*(x1-x0); h=dc.h_from_x(x)
        mx=max(mx,abs((y0+f*(y1-y0))-stable_logk(h,p)))
    return mx

def refine_k(h0,h1,p,tol,depth=0):
    if kerr(h0,h1,p)<=tol:return [h0,h1]
    if depth>=40: raise RuntimeError(f"depth h0={h0} h1={h1} tol={tol}")
    hm=dc.h_from_x(0.5*(dc.x_from_h(h0)+dc.x_from_h(h1)))
    l=refine_k(h0,hm,p,tol,depth+1); r=refine_k(hm,h1,p,tol,depth+1)
    return l[:-1]+r

def build(p,tol,hmin):
    old=dc.HMIN
    dc.HMIN=hmin
    try:
        base=dc.build(p)
    finally:
        dc.HMIN=old
    knots=[]
    for a,b in zip(base[:-1],base[1:]):
        seg=refine_k(a,b,p,tol)
        knots.extend(seg[:-1])
    knots.append(base[-1])
    return knots

def write(mid,p,knots,out):
    ordered=sorted(knots,key=dc.x_from_h)
    with (out/f"{mid}_dc.dat").open("w") as f:
        f.write(" ".join(f"{v:.17e}" for v in p)+"\n")
        f.write(f"{len(ordered)}\n")
        for h in ordered:
            z,m,_=dc.node_values(h,p)
            f.write(f"{dc.x_from_h(h):.17e} {z:.17e} {m:.17e} {stable_logk(h,p):.17e}\n")

summary={"work_unit":"F-AHL10D","C_stop":C_STOP,"variants":{}}
for tag,tol in TOLS:
    out=ROOT/tag; out.mkdir(parents=True,exist_ok=True)
    rows={}
    for mid,p in dc.base.MATERIALS.items():
        hb=dry_bound(p)
        knots=build(p,tol,hb)
        write(mid,p,knots,out)
        # validate only represented domain with same sampling logic
        oldh=dc.HMIN; oldk=dc.LOGK_TOL
        dc.HMIN=hb; dc.LOGK_TOL=tol
        try:
            e=dc.validate(knots,p)
        finally:
            dc.HMIN=oldh; dc.LOGK_TOL=oldk
        rows[mid]={
          "dry_lookup_bound_cm":hb,
          "points":len(knots),
          "theta_span_error":e[0],
          "log_capacity_error":e[1],
          "log_conductivity_error":e[2],
          "pass":e[0]<=dc.THETA_TOL and e[1]<=dc.LOGC_TOL and e[2]<=tol
        }
    summary["variants"][tag]={"logK_tolerance":tol,"materials":rows}
print(json.dumps(summary,indent=2,sort_keys=True))
