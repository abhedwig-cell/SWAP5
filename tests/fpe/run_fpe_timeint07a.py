#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B12",1.0),("B12",3.0),("B12",5.0),("O14",1.0),("O14",3.0),("O14",5.0)]
base_dts=[0.01,0.005]; patterns=["R1","R1P5","R2"]

def run(mid,rain,dt,pattern):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),pattern]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    pts=[]; unavailable=[]
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT07_POINT|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            e3=float(d["E3"]); eh=float(d["EHEAD"])
            pts.append({"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
                        "step":int(d["STEP"]),"dt":float(d["DT"]),"prev_dt":float(d["PREV_DT"]),
                        "prevprev_dt":float(d["PREVPREV_DT"]),"ratio":float(d["RATIO"]),
                        "e3":e3,"ehead":eh,"etheta":float(d["ETHETA"]),"estorage":float(d["ESTORAGE"]),
                        "pred_safe":e3<=0.01,"actual_safe":eh<=0.01})
        elif line.startswith("F_PE_TIMEINT07_LABEL_UNAVAILABLE|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            unavailable.append({"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
                                "step":int(d["STEP"]),"dt":float(d["DT"]),"ratio":float(d["RATIO"]),
                                "e3":float(d["E3"]),"half1_ok":int(d["HALF1_OK"]),"half2_ok":int(d["HALF2_OK"])})
    ok=cp.returncode==0 and "F_PE_TIMEINT07=PASS" in cp.stdout
    return {"ok":ok,"material":mid,"rain":rain,"base_dt":dt,"pattern":pattern,
            "points":len(pts),"unavailable":len(unavailable),
            "stdout_tail":cp.stdout[-800:] if not ok else "","stderr_tail":cp.stderr[-800:] if not ok else ""},pts,unavailable

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

runs=[]; pts=[]; unavailable=[]
for p in patterns:
    for mid,rain in cases:
        for dt in base_dts:
            rr,pp,uu=run(mid,rain,dt,p); runs.append(rr); pts+=pp; unavailable+=uu

overall=spear([x["e3"] for x in pts],[x["ehead"] for x in pts])
per={p:spear([x["e3"] for x in pts if x["pattern"]==p],[x["ehead"] for x in pts if x["pattern"]==p]) for p in patterns}
ratios=sorted([x["ehead"]/x["e3"] for x in pts if x["e3"]>0])
median=ratios[len(ratios)//2] if ratios else None
inside=sum(0.25<=x<=4.0 for x in ratios)/len(ratios) if ratios else 0.0
false_safe=[x for x in pts if x["pred_safe"] and not x["actual_safe"]]
actual_safe=[x for x in pts if x["actual_safe"]]
true_safe=[x for x in pts if x["pred_safe"] and x["actual_safe"]]
coverage=len(true_safe)/len(actual_safe) if actual_safe else 0.0
incomplete_trajectories=sum(r["unavailable"]>0 for r in runs)
runs_ok=all(r["ok"] for r in runs)
qualifies=(runs_ok and len(pts)>=240 and incomplete_trajectories<=2 and overall is not None and overall>=0.90 and
           all(per[p] is not None and per[p]>=0.85 for p in patterns) and median is not None and 0.5<=median<=2.0 and
           inside>=0.90 and max(ratios)<=2.0 and len(false_safe)==0 and coverage>=0.20)
summary={"runs_ok":runs_ok,"trajectories":len(runs),"points":len(pts),"unavailable_labels":len(unavailable),
         "incomplete_label_trajectories":incomplete_trajectories,"spearman_overall":overall,"spearman_by_pattern":per,
         "median_actual_over_e3":median,"fraction_ratio_0p25_to_4":inside,"max_actual_over_e3":max(ratios) if ratios else None,
         "false_safe":len(false_safe),"actual_safe":len(actual_safe),"true_safe":len(true_safe),"safe_coverage":coverage,
         "qualifies":qualifies,
         "classification":"ANALYTICAL_BDF2_LTE_HOLDOUT_QUALIFIED" if qualifies else "CLOSED_ANALYTICAL_BDF2_LTE_HOLDOUT_FAILED"}
print("F_PE_TIMEINT07A_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT07A_UNAVAILABLE="+json.dumps(unavailable,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT07A_FALSE_SAFE="+json.dumps(false_safe,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT07A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not runs_ok:
    raise SystemExit("one or more full BDF2 holdout trajectories failed")
print("F_PE_TIMEINT07A=PASS")
