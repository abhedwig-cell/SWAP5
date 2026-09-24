#!/usr/bin/env python3
"""Generate F-AHL04 research lookup tables for the frozen FSI24 nonlinear fixture.

The table domain is deliberately restricted to h <= -1 cm so the B1.10
step-duration-dependent capacity floor and near-saturation branch remain exact.
"""
from __future__ import annotations
import json, math, pathlib, sys

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ahl04")
OUT.mkdir(parents=True, exist_ok=True)

P = dict(theta_r=0.032, theta_s=0.423, ksat=4.75, alpha=0.0135,
         lam=0.365, n=1.455)
P["m"] = 1.0 - 1.0/P["n"]
HMIN = -1.0e6
HMAX = -1.0
THETA_TOL = 1.0e-5
LOGC_TOL = 1.0e-2
LOGK_TOL = 1.0e-2

def eval_core(h):
    tr, ts, a, n, m, ks, lam = P["theta_r"],P["theta_s"],P["alpha"],P["n"],P["m"],P["ksat"],P["lam"]
    span=ts-tr
    ah=abs(a*h)
    theta=tr+span/(1+ah**n)**m
    t1=ah**(n-1)
    cap=n*m*a*(span/(1+t1*ah)**(m+1))*t1
    rel=(theta-tr)/span
    if rel > 1.0-1.0e-6:
        k=ks
    else:
        term=(1-rel**(1/m))**m
        k=min(ks*rel**lam*(1-term)**2,ks)
    return theta,max(cap,1e-300),max(k,1e-300)

def x(h): return math.log10(-h)
def hfrom(xv): return -(10.0**xv)

def transformed(h):
    theta,c,k=eval_core(h)
    span=P["theta_s"]-P["theta_r"]
    se=(theta-P["theta_r"])/span
    se=min(max(se,1e-15),1-1e-15)
    return math.log(se/(1-se)),math.log(c),math.log(k)

def ierr(h0,h1):
    x0,x1=x(h0),x(h1)
    y0,y1=transformed(h0),transformed(h1)
    span=P["theta_s"]-P["theta_r"]
    maxima=[0.0,0.0,0.0]
    for f in (0.125,0.25,0.5,0.75,0.875):
        hh=hfrom(x0+f*(x1-x0))
        th,c,k=eval_core(hh)
        yi=[y0[j]+f*(y1[j]-y0[j]) for j in range(3)]
        z=yi[0]
        se=1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
        thi=P["theta_r"]+span*se
        e=(abs(thi-th)/span,abs(yi[1]-math.log(c)),abs(yi[2]-math.log(k)))
        maxima=[max(maxima[j],e[j]) for j in range(3)]
    return max(maxima[0]/THETA_TOL,maxima[1]/LOGC_TOL,maxima[2]/LOGK_TOL),maxima

def refine(h0,h1,d=0):
    score,_=ierr(h0,h1)
    if score<=1: return [h0,h1]
    if d>=40: raise RuntimeError("depth")
    hm=hfrom(0.5*(x(h0)+x(h1)))
    l=refine(h0,hm,d+1); r=refine(hm,h1,d+1)
    return l[:-1]+r

def fixed(n):
    x0,x1=x(HMAX),x(HMIN)
    return [hfrom(x0+i*(x1-x0)/(n-1)) for i in range(n)]

def adaptive():
    return refine(HMAX,HMIN)

def write(name, heads):
    heads=sorted(heads, key=x)
    with (OUT/f"{name}.dat").open("w") as f:
        f.write(f"{len(heads)}\n")
        for h in heads:
            z,lc,lk=transformed(h)
            f.write(f"{x(h):.17e} {z:.17e} {lc:.17e} {lk:.17e}\n")

write("fixed50",fixed(50))
write("fixed100",fixed(100))
ah=adaptive(); write("adaptive",ah)
_,err=ierr(HMAX,HMIN) if len(ah)==2 else (None,None)
summary={"adaptive_points":len(ah),"domain_cm":[HMIN,HMAX],
         "fixed_points":[50,100],"tolerances":{"theta_span":THETA_TOL,"logC":LOGC_TOL,"logK":LOGK_TOL}}
print(json.dumps(summary,indent=2))
