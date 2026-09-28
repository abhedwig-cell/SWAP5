#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
base_dts=[0.01,0.005]
patterns=["R1","R1P5","R2"]

def run(mid,rain,base_dt,pattern):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(base_dt),pattern]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern,
                "stdout":cp.stdout[-1500:],"stderr":cp.stderr[-1500:]},[]
    pts=[]
    for line in cp.stdout.splitlines():
        if not line.startswith("F_PE_TIMEINT06_POINT|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        rec={"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
             "step":int(d["STEP"]),"dt":float(d["DT"]),"prev_dt":float(d["PREV_DT"]),
             "ratio":float(d["RATIO"]),"s1":float(d["S1"]),"s2":float(d["S2"]),"s3":float(d["S3"]),
             "ehead":float(d["EHEAD"]),"etheta":float(d["ETHETA"]),"estorage":float(d["ESTORAGE"]),
             "full_work":int(d["FULL_WORK"]),"half_work":int(d["HALF_WORK"])}
        pts.append(rec)
    ok="F_PE_TIMEINT06=PASS" in cp.stdout
    return {"ok":ok,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern,"points":len(pts)},pts

def ranks(vals):
    order=sorted(range(len(vals)), key=lambda i: vals[i])
    out=[0.0]*len(vals)
    i=0
    while i<len(order):
        j=i+1
        while j<len(order) and vals[order[j]]==vals[order[i]]:
            j+=1
        rank=0.5*(i+j-1)+1.0
        for k in range(i,j):
            out[order[k]]=rank
        i=j
    return out

def pearson(a,b):
    if len(a)<2: return None
    ma=sum(a)/len(a); mb=sum(b)/len(b)
    da=[x-ma for x in a]; db=[x-mb for x in b]
    va=sum(x*x for x in da); vb=sum(x*x for x in db)
    if va<=0 or vb<=0: return None
    return sum(x*y for x,y in zip(da,db))/math.sqrt(va*vb)

def spearman(a,b):
    return pearson(ranks(a),ranks(b))

runs=[]; points=[]
for pattern in patterns:
    for mid,rain in cases:
        for dt in base_dts:
            rr,pts=run(mid,rain,dt,pattern)
            runs.append(rr); points.extend(pts)

signals=["s1","s2","s3"]
summary=[]
for sig in signals:
    overall=spearman([p[sig] for p in points],[p["ehead"] for p in points])
    per={}
    for pattern in patterns:
        ps=[p for p in points if p["pattern"]==pattern]
        per[pattern]=spearman([p[sig] for p in ps],[p["ehead"] for p in ps])
    finite=all(math.isfinite(p[sig]) for p in points)
    qualifies=(len(points)>=40 and overall is not None and overall>=0.85 and finite and
               all(per[x] is not None and per[x]>=0.75 for x in patterns))
    summary.append({"signal":sig,"points":len(points),"spearman_overall":overall,
                    "spearman_by_pattern":per,"finite":finite,"qualifies":qualifies})

all_runs_ok=all(r["ok"] for r in runs)
storage_finite=all(math.isfinite(p["estorage"]) and p["estorage"]>=0 for p in points)
classification="CHEAP_BDF2_ERROR_SIGNAL_PREDICTIVE" if all_runs_ok and storage_finite and any(x["qualifies"] for x in summary) else "CLOSED_CHEAP_BDF2_ERROR_SIGNAL_NOT_PREDICTIVE"

out={"runs_ok":all_runs_ok,"complete_points":len(points),"storage_finite":storage_finite,
     "signals":summary,"classification":classification}
print("F_PE_TIMEINT06_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT06_POINTS="+json.dumps(points,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT06_SUMMARY="+json.dumps(out,separators=(",",":"),sort_keys=True))
if not all_runs_ok:
    raise SystemExit("one or more estimator trajectories failed")
print("F_PE_TIMEINT06=PASS")
