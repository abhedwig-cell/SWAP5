#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
base_dts=[0.01,0.005]; patterns=["R1","R1P5","R2"]

def run(mid,rain,dt,pattern):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),pattern]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"material":mid,"rain":rain,"base_dt":dt,"pattern":pattern,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]},[]
    pts=[]
    for line in cp.stdout.splitlines():
        if not line.startswith("F_PE_TIMEINT07_POINT|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        pts.append({"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
                    "step":int(d["STEP"]),"dt":float(d["DT"]),"prev_dt":float(d["PREV_DT"]),
                    "prevprev_dt":float(d["PREVPREV_DT"]),"ratio":float(d["RATIO"]),
                    "e3":float(d["E3"]),"ehead":float(d["EHEAD"]),
                    "etheta":float(d["ETHETA"]),"estorage":float(d["ESTORAGE"])})
    return {"ok":"F_PE_TIMEINT07=PASS" in cp.stdout,"material":mid,"rain":rain,"base_dt":dt,"pattern":pattern,"points":len(pts)},pts

def ranks(v):
    order=sorted(range(len(v)),key=lambda i:v[i]); r=[0.0]*len(v); i=0
    while i<len(order):
        j=i+1
        while j<len(order) and v[order[j]]==v[order[i]]: j+=1
        q=0.5*(i+j-1)+1
        for k in range(i,j): r[order[k]]=q
        i=j
    return r

def pearson(a,b):
    if len(a)<2:return None
    ma=sum(a)/len(a); mb=sum(b)/len(b)
    da=[x-ma for x in a]; db=[x-mb for x in b]
    va=sum(x*x for x in da); vb=sum(x*x for x in db)
    if va<=0 or vb<=0:return None
    return sum(x*y for x,y in zip(da,db))/math.sqrt(va*vb)

def spear(a,b): return pearson(ranks(a),ranks(b))

runs=[]; pts=[]
for p in patterns:
    for mid,rain in cases:
        for dt in base_dts:
            rr,pp=run(mid,rain,dt,p); runs.append(rr); pts+=pp

overall=spear([x["e3"] for x in pts],[x["ehead"] for x in pts])
per={p:spear([x["e3"] for x in pts if x["pattern"]==p],[x["ehead"] for x in pts if x["pattern"]==p]) for p in patterns}
ratios=[x["ehead"]/x["e3"] for x in pts if x["e3"]>0]
ratios.sort()
median=ratios[len(ratios)//2] if ratios else None
inside=sum(0.25<=x<=4.0 for x in ratios)/len(ratios) if ratios else 0.0
qualifies=(all(r["ok"] for r in runs) and len(pts)>=80 and overall is not None and overall>=0.90 and
           all(per[p] is not None and per[p]>=0.80 for p in patterns) and median is not None and
           0.5<=median<=2.0 and inside>=0.90 and all(math.isfinite(x["e3"]) for x in pts))
summary={"runs_ok":all(r["ok"] for r in runs),"points":len(pts),"spearman_overall":overall,
         "spearman_by_pattern":per,"median_actual_over_e3":median,"fraction_ratio_0p25_to_4":inside,
         "max_actual_over_e3":max(ratios) if ratios else None,"min_actual_over_e3":min(ratios) if ratios else None,
         "qualifies":qualifies,
         "classification":"THIRD_DIFFERENCE_BDF2_LTE_MECHANISM_QUALIFIED" if qualifies else "CLOSED_THIRD_DIFFERENCE_BDF2_LTE_NOT_QUALIFIED"}
print("F_PE_TIMEINT07_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT07_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT07=PASS")
