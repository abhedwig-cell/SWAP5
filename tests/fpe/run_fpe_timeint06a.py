#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}

cases=[("B12",1.0),("B12",3.0),("B12",5.0),("O14",1.0),("O14",3.0),("O14",5.0)]
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
             "ratio":float(d["RATIO"]),"s1":float(d["S1"]),"ehead":float(d["EHEAD"]),
             "etheta":float(d["ETHETA"]),"estorage":float(d["ESTORAGE"])}
        rec["ehat"]=0.20*rec["s1"]
        rec["pred_safe"]=rec["ehat"]<=0.01
        rec["actual_safe"]=rec["ehead"]<=0.01
        pts.append(rec)
    ok="F_PE_TIMEINT06=PASS" in cp.stdout
    return {"ok":ok,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern,"points":len(pts)},pts

def ranks(vals):
    order=sorted(range(len(vals)),key=lambda i:vals[i])
    out=[0.0]*len(vals); i=0
    while i<len(order):
        j=i+1
        while j<len(order) and vals[order[j]]==vals[order[i]]: j+=1
        rank=0.5*(i+j-1)+1.0
        for k in range(i,j): out[order[k]]=rank
        i=j
    return out

def pearson(a,b):
    if len(a)<2:return None
    ma=sum(a)/len(a); mb=sum(b)/len(b)
    da=[x-ma for x in a]; db=[x-mb for x in b]
    va=sum(x*x for x in da); vb=sum(x*x for x in db)
    if va<=0 or vb<=0:return None
    return sum(x*y for x,y in zip(da,db))/math.sqrt(va*vb)

def spearman(a,b):
    return pearson(ranks(a),ranks(b))

runs=[]; points=[]
for pattern in patterns:
    for mid,rain in cases:
        for dt in base_dts:
            rr,pts=run(mid,rain,dt,pattern)
            runs.append(rr); points.extend(pts)

false_safe=[p for p in points if p["pred_safe"] and not p["actual_safe"]]
actual_safe=[p for p in points if p["actual_safe"]]
true_safe=[p for p in points if p["pred_safe"] and p["actual_safe"]]
coverage=len(true_safe)/len(actual_safe) if actual_safe else 0.0
overall=spearman([p["ehat"] for p in points],[p["ehead"] for p in points])
per={}
for pattern in patterns:
    ps=[p for p in points if p["pattern"]==pattern]
    per[pattern]=spearman([p["ehat"] for p in ps],[p["ehead"] for p in ps])

ratios=[p["ehead"]/p["ehat"] for p in points if p["ehat"]>0]
max_ratio=max(ratios) if ratios else None
all_runs_ok=all(r["ok"] for r in runs)
finite=all(math.isfinite(p["ehat"]) and math.isfinite(p["ehead"]) and math.isfinite(p["estorage"]) for p in points)
qualifies=(all_runs_ok and len(points)>=100 and len(false_safe)==0 and coverage>=0.20 and
           overall is not None and overall>=0.80 and all(per[x] is not None and per[x]>=0.70 for x in patterns) and
           max_ratio is not None and max_ratio<=1.0 and finite)

summary={
 "runs_ok":all_runs_ok,"trajectories":len(runs),"points":len(points),
 "false_safe":len(false_safe),"actual_safe":len(actual_safe),"true_safe":len(true_safe),
 "safe_coverage":coverage,"spearman_overall":overall,"spearman_by_pattern":per,
 "max_actual_over_estimate":max_ratio,"finite":finite,"qualifies":qualifies,
 "classification":"CALIBRATED_BDF2_HEAD_ESTIMATOR_HOLDOUT_QUALIFIED" if qualifies else "CLOSED_CALIBRATED_BDF2_HEAD_ESTIMATOR_FAILED"
}
print("F_PE_TIMEINT06A_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT06A_FALSE_SAFE="+json.dumps(false_safe,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT06A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not all_runs_ok:
    raise SystemExit("one or more holdout trajectories failed")
print("F_PE_TIMEINT06A=PASS")
