#!/usr/bin/env python3
"""F-AHL04B one-factor constitutive tolerance attribution sweep."""
from __future__ import annotations
import json, math, pathlib, sys

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl04b")
OUT.mkdir(parents=True,exist_ok=True)
P=dict(theta_r=0.032,theta_s=0.423,ksat=4.75,alpha=0.0135,lam=0.365,n=1.455)
P["m"]=1.0-1.0/P["n"]
HMIN,HMAX=-1.0e6,-1.0
VARIANTS={
 "base":(1e-5,1e-2,1e-2),
 "theta3":(3e-6,1e-2,1e-2),
 "theta1":(1e-6,1e-2,1e-2),
 "c3":(1e-5,3e-3,1e-2),
 "c1":(1e-5,1e-3,1e-2),
 "k3":(1e-5,1e-2,3e-3),
 "k1":(1e-5,1e-2,1e-3),
}
def eval_core(h):
    tr,ts,a,n,m,ks,lam=P["theta_r"],P["theta_s"],P["alpha"],P["n"],P["m"],P["ksat"],P["lam"]
    span=ts-tr; ah=abs(a*h)
    th=tr+span/(1+ah**n)**m
    t1=ah**(n-1); cap=n*m*a*(span/(1+t1*ah)**(m+1))*t1
    rel=(th-tr)/span
    if rel>1-1e-6: k=ks
    else:
        term=(1-rel**(1/m))**m
        k=min(ks*rel**lam*(1-term)**2,ks)
    return th,max(cap,1e-300),max(k,1e-300)
def x(h): return math.log10(-h)
def hfrom(v): return -(10.0**v)
def vals(h):
    th,c,k=eval_core(h); span=P["theta_s"]-P["theta_r"]
    se=min(max((th-P["theta_r"])/span,1e-15),1-1e-15)
    return math.log(se/(1-se)),math.log(c),math.log(k)
def errors(h0,h1):
    x0,x1=x(h0),x(h1); y0,y1=vals(h0),vals(h1); span=P["theta_s"]-P["theta_r"]; mx=[0.,0.,0.]
    for f in (0.125,0.25,0.5,0.75,0.875):
        hh=hfrom(x0+f*(x1-x0)); th,c,k=eval_core(hh)
        yi=[y0[j]+f*(y1[j]-y0[j]) for j in range(3)]
        z=yi[0]; se=1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
        thi=P["theta_r"]+span*se
        ee=(abs(thi-th)/span,abs(yi[1]-math.log(c)),abs(yi[2]-math.log(k)))
        mx=[max(mx[j],ee[j]) for j in range(3)]
    return mx
def build(tols):
    def refine(h0,h1,d=0):
        e=errors(h0,h1)
        score=max(e[i]/tols[i] for i in range(3))
        if score<=1:return [h0,h1]
        if d>=40:raise RuntimeError("depth")
        hm=hfrom((x(h0)+x(h1))/2)
        l=refine(h0,hm,d+1);r=refine(hm,h1,d+1)
        return l[:-1]+r
    return refine(HMAX,HMIN)
def write(name,heads):
    heads=sorted(heads,key=x)
    with (OUT/f"{name}.dat").open("w") as f:
        f.write(f"{len(heads)}\n")
        for h in heads:
            z,lc,lk=vals(h);f.write(f"{x(h):.17e} {z:.17e} {lc:.17e} {lk:.17e}\n")
summary={}
for name,tols in VARIANTS.items():
    heads=build(tols);write(name,heads)
    summary[name]={"points":len(heads),"theta_tol":tols[0],"logC_tol":tols[1],"logK_tol":tols[2]}
print(json.dumps(summary,indent=2,sort_keys=True))
