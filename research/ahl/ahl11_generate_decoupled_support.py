#!/usr/bin/env python3
"""F-AHL11 Stage-A: generate compact derivative-consistent retention tables
plus independent adaptive log(K) supports for prospective K tolerances.
"""
from __future__ import annotations
import math, pathlib, sys
import ahl09_derivative_consistent as dc

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl11v2")
OUT.mkdir(parents=True,exist_ok=True)
HMAX,HMIN=-1.0,-1.0e6
K_VARIANTS={"k3":3e-3,"k1":1e-3,"k03":3e-4}

# Freeze retention/capacity at the admitted F-AHL09 Stage-1 settings.
dc.THETA_TOL=1e-5
dc.LOGC_TOL=1e-2
dc.LOGK_TOL=1e-2

def x(h): return math.log10(-h)
def hfrom(v): return -(10.0**v)

def logk(h,p):
    """Stable log of the authoritative unimodal B1.10/Mualem K relation.

    Compute Se directly from h rather than reconstructing it from theta, and
    use log1p/expm1 for the small Mualem bracket. This avoids cancellation in
    the very dry tail without changing the constitutive equation.
    """
    tr,ts,alpha,n,ksat,lam=p
    del tr,ts
    m=1.0-1.0/n
    ah=abs(alpha*h)
    log_one_plus=math.log1p(ah**n)
    log_se=-m*log_one_plus
    # u = Se**(1/m) = 1/(1 + |alpha h|**n)
    u=math.exp(-log_one_plus)
    # bracket = 1 - (1-u)**m, evaluated stably for u << 1.
    log_inner=math.log1p(-u)
    bracket=-math.expm1(m*log_inner)
    if bracket<=0.0:
        raise RuntimeError("non-positive stable Mualem bracket")
    return math.log(ksat)+lam*log_se+2.0*math.log(bracket)

def kerr(h0,h1,p):
    x0,x1=x(h0),x(h1); y0,y1=logk(h0,p),logk(h1,p)
    mx=0.0
    for f in (0.125,0.25,0.5,0.75,0.875):
        xv=x0+f*(x1-x0); h=hfrom(xv)
        yi=y0+f*(y1-y0)
        mx=max(mx,abs(yi-logk(h,p)))
    return mx

def build_k(p,tol):
    def refine(h0,h1,d=0):
        if kerr(h0,h1,p)<=tol: return [h0,h1]
        if d>=40: raise RuntimeError("K refinement depth")
        hm=hfrom(0.5*(x(h0)+x(h1)))
        l=refine(h0,hm,d+1); r=refine(hm,h1,d+1)
        return l[:-1]+r
    return refine(HMAX,HMIN)

def write_k(mid,name,p,heads):
    ordered=sorted(heads,key=x)
    with (OUT/f"{mid}_{name}_k.dat").open("w") as f:
        f.write(f"{len(ordered)}\n")
        for h in ordered:
            f.write(f"{x(h):.17e} {logk(h,p):.17e}\n")

for mid,p in dc.base.MATERIALS.items():
    rknots=dc.build(p)
    dc.OUT=OUT
    dc.write_table(f"{mid}_ret",p,rknots)
    print("AHL11_RET",mid,"points",len(rknots))
    for name,tol in K_VARIANTS.items():
        try:
            knots=build_k(p,tol)
        except RuntimeError as exc:
            print("AHL11_K_BUILD_FAIL",mid,name,"reason",str(exc))
            continue
        worst=max(kerr(a,b,p) for a,b in zip(knots[:-1],knots[1:]))
        write_k(mid,name,p,knots)
        print("AHL11_K",mid,name,"points",len(knots),"max_logK",f"{worst:.12e}","tol",tol)
