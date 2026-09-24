#!/usr/bin/env python3
from __future__ import annotations
import json, math, pathlib, subprocess, tempfile
import ahl01_adaptive_lookup as base

LN10=math.log(10.0)
CASES=[]
for material in ("B01","B12","O05","O14"):
    for regime,h0 in (("wet",-10.0),("mid",-75.0),("dry",-500.0)):
        CASES.append({
            "id":f"{material}:{regime}",
            "material":material,
            "regime":regime,
            "head_cm":h0,
            "dt_day":0.0625,
            "qbot_over_K":0.99,
            "known_path":"FAIL" if material=="O05" and regime=="dry" else "PASS"
        })
CASES.append({
    "id":"B01:wet:qbot1e-6_dt0.01",
    "material":"B01","regime":"wet","head_cm":-10.0,
    "dt_day":0.01,
    "qbot_over_K":None,
    "qbot_cm_per_day":1.0e-6,
    "known_path":"FAIL"
})

def load_table(path):
    lines=path.read_text().strip().splitlines()
    params=[float(v) for v in lines[0].split()]
    n=int(lines[1])
    rows=[[float(v) for v in line.split()] for line in lines[2:2+n]]
    return params,rows

def locate(rows,x):
    if x<=rows[0][0]: return 0,0.0
    if x>=rows[-1][0]: return len(rows)-2,1.0
    lo,hi=0,len(rows)-1
    while hi-lo>1:
        mid=(lo+hi)//2
        if rows[mid][0]<=x: lo=mid
        else: hi=mid
    f=(x-rows[lo][0])/(rows[lo+1][0]-rows[lo][0])
    return lo,f

def interp_retention(head,params,rows):
    x=math.log10(-head)
    i,f=locate(rows,x)
    x0,z0,m0,_=rows[i]
    x1,z1,m1,_=rows[i+1]
    dx=x1-x0; t=f
    h00=2*t**3-3*t**2+1; h10=t**3-2*t**2+t
    h01=-2*t**3+3*t**2; h11=t**3-t**2
    z=h00*z0+h10*dx*m0+h01*z1+h11*dx*m1
    dh00=6*t*t-6*t; dh10=3*t*t-4*t+1
    dh01=-6*t*t+6*t; dh11=3*t*t-2*t
    dzdx=(dh00*z0+dh10*dx*m0+dh01*z1+dh11*dx*m1)/dx
    if z>=0:
        se=1.0/(1.0+math.exp(-z))
    else:
        ez=math.exp(z); se=ez/(1.0+ez)
    tr,ts,*_=params
    span=ts-tr
    theta=tr+span*se
    capacity=(span*se*(1.0-se)*dzdx)/(head*LN10)
    return theta,max(capacity,1e-300),x1-x0

def main():
    with tempfile.TemporaryDirectory(prefix="ahl22-") as td:
        subprocess.run(
            ["python3","research/ahl/ahl15_wet_local_k.py",td],
            check=True,stdout=subprocess.DEVNULL
        )
        out=[]
        for case in CASES:
            p=base.MATERIALS[case["material"]]
            _,rows=load_table(pathlib.Path(td)/f'{case["material"]}_dc.dat')
            h=case["head_cm"]
            th,c,k=base.evaluate_core(h,p)
            thi,ci,width=interp_retention(h,p,rows)
            dz_values=(0.5,0.5,1.0,1.0)
            max_storage=max(abs(ci-c)*dz/case["dt_day"] for dz in dz_values)
            if case.get("qbot_over_K") is None:
                qratio=abs(case["qbot_cm_per_day"])/max(k,1e-300)
            else:
                qratio=case["qbot_over_K"]
            out.append({
                **case,
                "authoritative_C":c,
                "authoritative_K":k,
                "abs_logC_error":abs(math.log(ci)-math.log(c)),
                "theta_span_normalized_error":abs(thi-th)/(p[1]-p[0]),
                "relative_C_error":abs(ci-c)/max(abs(c),1e-300),
                "max_storage_jacobian_perturbation_per_day":max_storage,
                "support_interval_width_log10h":width,
                "boundary_flux_over_K_initial":qratio
            })
        print(json.dumps({
            "work_unit":"F-AHL22",
            "classification":"diagnostic_not_qualification",
            "cases":out
        },indent=2,sort_keys=True))
if __name__=="__main__":
    main()
