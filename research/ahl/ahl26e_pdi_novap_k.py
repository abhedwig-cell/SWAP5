#!/usr/bin/env python3
from __future__ import annotations
import json,math
import ahl26b_pdi_transform_diagnosis as pdi

HMIN=-1.0e7;HMAX=-1.0
LIMITS=[1e-3,3e-4,1e-4]
DENSE=tuple(j/50 for j in range(1,50))

def xh(h):return math.log10(-h)
def hx(x):return -(10**x)

def gamma(ah,a,n,m):return (1+(a*ah)**n)**(-m)

def kliq(h,p):
    if h>=0:return p.get("ksat",50.0)
    ah=abs(h);ks=p.get("ksat",50.0);ok=p["omegaK"];ap=p["apar"]
    if p["model"]==8:
        g1=gamma(ah,p["a1"],p["n1"],p["m1"])
        kcap=g1**0.5*(1-(1-g1**(1/p["m1"]))**p["m1"])**2
    else:
        g1=gamma(ah,p["a1"],p["n1"],p["m1"]);g2=gamma(ah,p["a2"],p["n2"],p["m2"])
        w1=p["w1"];w2=p["w2"]
        t1=(w1*g1+w2*g2)**0.5
        t2=w1*p["a1"]*(1-g1**(1/p["m1"]))**p["m1"]+w2*p["a2"]*(1-g2**(1/p["m2"]))**p["m2"]
        t3=w1*p["a1"]+w2*p["a2"]
        kcap=t1*(1-t2/t3)**2
    kfilm=(p["h0"]/p["ha"])**(ap*(1-pdi.sad(ah,p)))
    return ks*((1-ok)*kcap+ok*kfilm)

def interp(h,a,b,p):
    f=(xh(h)-xh(a))/(xh(b)-xh(a))
    return math.exp(math.log(kliq(a,p))+f*(math.log(kliq(b,p))-math.log(kliq(a,p))))

def interval_err(a,b,p):
    return max(abs(math.log(interp(hx(xh(a)+f*(xh(b)-xh(a))),a,b,p))-math.log(kliq(hx(xh(a)+f*(xh(b)-xh(a))),p))) for f in DENSE)

def refine(a,b,p,tol,d=0):
    if interval_err(a,b,p)<=tol:return [a,b]
    if d>=40:raise RuntimeError("depth")
    m=hx(.5*(xh(a)+xh(b)))
    l=refine(a,m,p,tol,d+1);r=refine(m,b,p,tol,d+1)
    return l[:-1]+r

def validate(knots,p):
    return max(interval_err(a,b,p) for a,b in zip(knots[:-1],knots[1:]))

def main():
    sets={k:dict(v,ksat=50.0) for k,v in pdi.SETS.items()}
    attempts={}
    selected=None
    for tol in LIMITS:
        data={};ok=True
        for name,p in sets.items():
            knots=sorted(set(refine(HMAX,HMIN,p,tol)),key=xh)
            err=validate(knots,p)
            passed=err<=1e-3
            data[name]={"support_points":len(knots),"max_abs_logK_error":err,"pass":passed}
            ok &= passed
        attempts[str(tol)]=data
        if ok:
            selected=tol;break
    status="PASS" if selected is not None else "FAIL"
    print(json.dumps({"work_unit":"F-AHL26E","status":status,"selected_builder_abs_logK_limit":selected,"attempts":attempts},indent=2))
if __name__=="__main__":main()
