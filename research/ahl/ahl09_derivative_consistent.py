#!/usr/bin/env python3
"""F-AHL09 derivative-consistent adaptive retention preflight.

Builds an adaptive cubic-Hermite interpolant for z=logit(Se) over x=log10(-h).
The same interpolant supplies theta and C=dtheta/dh by differentiation. K is
represented separately as linear log(K) on the same support.
"""
from __future__ import annotations
import json, math, pathlib, sys
import ahl01_adaptive_lookup as base

HMIN=-1.0e6
HMAX=-1.0
THETA_TOL=1e-5
LOGC_TOL=1e-2
LOGK_TOL=1e-2
LN10=math.log(10.0)
OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl09")
OUT.mkdir(parents=True,exist_ok=True)

def x_from_h(h): return math.log10(-h)
def h_from_x(x): return -(10.0**x)

def node_values(h,p):
    theta,c,k=base.evaluate_core(h,p)
    tr,ts,*_=p
    span=ts-tr
    se=min(max((theta-tr)/span,1e-15),1-1e-15)
    z=math.log(se/(1-se))
    dzdh=(c/span)/(se*(1-se))
    dzdx=dzdh*h*LN10
    return z,dzdx,math.log(k)

def hermite(x,x0,x1,y0,y1,m0,m1):
    dx=x1-x0
    t=(x-x0)/dx
    h00=2*t**3-3*t**2+1
    h10=t**3-2*t**2+t
    h01=-2*t**3+3*t**2
    h11=t**3-t**2
    y=h00*y0+h10*dx*m0+h01*y1+h11*dx*m1
    dh00=6*t*t-6*t
    dh10=3*t*t-4*t+1
    dh01=-6*t*t+6*t
    dh11=3*t*t-2*t
    dydx=(dh00*y0+dh10*dx*m0+dh01*y1+dh11*dx*m1)/dx
    return y,dydx

def interp(h,h0,h1,p):
    x=x_from_h(h);x0=x_from_h(h0);x1=x_from_h(h1)
    z0,m0,k0=node_values(h0,p);z1,m1,k1=node_values(h1,p)
    z,dzdx=hermite(x,x0,x1,z0,z1,m0,m1)
    se=1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
    tr,ts,*_=p;span=ts-tr
    theta=tr+span*se
    dthetadx=span*se*(1-se)*dzdx
    c=dthetadx/(h*LN10)
    f=(x-x0)/(x1-x0)
    logk=k0+f*(k1-k0)
    return theta,max(c,1e-300),math.exp(logk)

def interval_error(h0,h1,p):
    span=p[1]-p[0]
    mx=[0.0,0.0,0.0]
    for f in (0.125,0.25,0.5,0.75,0.875):
        x=x_from_h(h0)+f*(x_from_h(h1)-x_from_h(h0))
        h=h_from_x(x)
        th,c,k=base.evaluate_core(h,p)
        thi,ci,ki=interp(h,h0,h1,p)
        e=(abs(thi-th)/span,abs(math.log(ci)-math.log(c)),abs(math.log(ki)-math.log(k)))
        mx=[max(mx[j],e[j]) for j in range(3)]
    score=max(mx[0]/THETA_TOL,mx[1]/LOGC_TOL,mx[2]/LOGK_TOL)
    return score,mx

def refine(h0,h1,p,depth=0):
    score,_=interval_error(h0,h1,p)
    if score<=1:return [h0,h1]
    if depth>=40:raise RuntimeError("refinement depth")
    hm=h_from_x(0.5*(x_from_h(h0)+x_from_h(h1)))
    l=refine(h0,hm,p,depth+1);r=refine(hm,h1,p,depth+1)
    return l[:-1]+r

def build(p):
    return refine(HMAX,HMIN,p)

def validate(knots,p):
    mx=[0.0,0.0,0.0]
    for a,b in zip(knots[:-1],knots[1:]):
        _,e=interval_error(a,b,p)
        mx=[max(mx[j],e[j]) for j in range(3)]
    return mx

def write_table(mid,p,knots):
    ordered=sorted(knots,key=x_from_h)
    with (OUT/f"{mid}_dc.dat").open("w") as f:
        f.write(" ".join(f"{v:.17e}" for v in p)+"\n")
        f.write(f"{len(ordered)}\n")
        for h in ordered:
            z,m,lk=node_values(h,p)
            f.write(f"{x_from_h(h):.17e} {z:.17e} {m:.17e} {lk:.17e}\n")

summary={"work_unit":"F-AHL09","materials":{}}
for mid,p in base.MATERIALS.items():
    knots=build(p)
    e=validate(knots,p)
    write_table(mid,p,knots)
    summary["materials"][mid]={
        "points":len(knots),
        "theta_span_error":e[0],
        "log_capacity_error":e[1],
        "log_conductivity_error":e[2],
        "pass":e[0]<=THETA_TOL and e[1]<=LOGC_TOL and e[2]<=LOGK_TOL
    }
print(json.dumps(summary,indent=2,sort_keys=True))
