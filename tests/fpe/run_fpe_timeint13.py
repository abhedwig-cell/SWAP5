#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
materials=("B01","O05")
rains=(1.0,4.0)
dts=(0.005,0.0025,0.00125,0.000625)
schemes=("BE_KLAG","BDF2_KPRED")

def run(mid,rain,dt,scheme):
    m=mats[mid]
    cmd=[str(exe),mid,scheme,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"rain":rain,"dt":dt,"scheme":scheme,"ok":cp.returncode==0,
         "stdout_tail":cp.stdout[-1200:],"stderr_tail":cp.stderr[-800:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_RESULT|")),None)
        if not line:
            out["ok"]=False
            out["stderr_tail"]="missing result"
            return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK"): d[k]=int(d[k])
        for k in ("RAIN","DT","TOP_H","MID_H","BOTTOM_H","STORAGE"): d[k]=float(d[k])
        out.update(d)
        out["work_per_step"]=d["WORK"]/d["STEPS"]
    return out

rows=[run(mid,rain,dt,scheme) for mid in materials for rain in rains for scheme in schemes for dt in dts]

def refined_order(rs):
    vals={r["dt"]:r["TOP_H"] for r in rs if r["ok"]}
    a,b,c=0.0025,0.00125,0.000625
    if not all(x in vals for x in (a,b,c)): return None
    e1=abs(vals[a]-vals[b]); e2=abs(vals[b]-vals[c])
    if e1<=0 or e2<=0: return None
    return math.log(e1/e2,2.0)

cases=[]
orders=[]
for mid in materials:
  for rain in rains:
    br=[r for r in rows if r["material"]==mid and r["rain"]==rain and r["scheme"]=="BDF2_KPRED"]
    order=refined_order(br)
    cases.append({"material":mid,"rain":rain,"order":order,"complete":sum(r["ok"] for r in br)})
    if order is not None: orders.append(order)

bdf=[r for r in rows if r["scheme"]=="BDF2_KPRED" and r["ok"]]
be=[r for r in rows if r["scheme"]=="BE_KLAG" and r["ok"]]
bdf_work=statistics.median([r["work_per_step"] for r in bdf]) if bdf else None
be_work=statistics.median([r["work_per_step"] for r in be]) if be else None
work_ratio=bdf_work/be_work if bdf_work is not None and be_work else None
alt_ok=all((not r["ok"]) or r.get("ALT",0)==0 for r in bdf)

complete_all=len(bdf)==16
median_order=statistics.median(orders) if orders else None
n15=sum(o>=1.50 for o in orders)
min_order=min(orders) if orders else None
advance=(complete_all and len(orders)==4 and median_order>=1.70 and n15>=3 and min_order>=1.25
         and work_ratio is not None and work_ratio<=1.15 and alt_ok)

summary={"cases":cases,"bdf_complete":len(bdf),"planned_bdf":16,
         "median_refined_order":median_order,"cases_order_ge_1p5":n15,"min_refined_order":min_order,
         "median_bdf_work_per_step":bdf_work,"median_be_work_per_step":be_work,
         "work_ratio":work_ratio,"alternative_solver_ok":alt_ok,"advance":advance}

print("F_PE_TIMEINT13_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13=PASS")
