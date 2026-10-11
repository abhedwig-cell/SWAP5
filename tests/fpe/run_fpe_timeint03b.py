#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]
variants=[("BASE_GUESS",0),("LINEAR_EXTRAP",1)]

def run(mid,rain,dt,name,predictor):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"2","1","8",str(predictor)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"variant":name,"material":mid,"rain":rain,"dt":dt,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03B_RESULT|")),None)
    if not line:
        return {"ok":False,"variant":name,"material":mid,"rain":rain,"dt":dt,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    out={"ok":True,"variant":name,"material":mid,"rain":rain,"dt":dt}
    for k in ["TOP_H","MID_H","BOTTOM_H","STORAGE"]:
        out[k.lower()]=float(d[k])
    for k in ["NL","BACK","JAC","LIN"]:
        out[k.lower()]=int(d[k])
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    out["steps"]=round(0.04/dt)
    out["work_per_step"]=out["work_index"]/out["steps"]
    return out

rows=[]
for name,pred in variants:
    for mid,rain in cases:
        for dt in dts:
            rows.append(run(mid,rain,dt,name,pred))

def ord3(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-11*scale or d2<=1e-11*scale: return None
    return math.log(d1/d2,2.0)

summ=[]
for name,_ in variants:
    per=[]; orders=[]; works=[]
    for mid,rain in cases:
        rs=sorted([r for r in rows if r["variant"]==name and r["material"]==mid and r["rain"]==rain],
                  key=lambda x:-x["dt"])
        complete=all(r["ok"] for r in rs)
        p=ord3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
        if p is not None and math.isfinite(p): orders.append(p)
        if complete: works.extend(r["work_per_step"] for r in rs)
        per.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p})
    summ.append({"variant":name,
                 "complete_cases":sum(x["complete"] for x in per),
                 "orders":per,
                 "median_refined_top_order":statistics.median(orders) if orders else None,
                 "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in per),
                 "median_work_per_step":statistics.median(works) if works else None})

by={x["variant"]:x for x in summ}
base=by["BASE_GUESS"]; cand=by["LINEAR_EXTRAP"]
be_work=16.1875
ratio_be=cand["median_work_per_step"]/be_work if cand["median_work_per_step"] is not None else None
common_ratios=[]
for mid,rain in cases:
    a=[r for r in rows if r["variant"]=="BASE_GUESS" and r["material"]==mid and r["rain"]==rain]
    b=[r for r in rows if r["variant"]=="LINEAR_EXTRAP" and r["material"]==mid and r["rain"]==rain]
    if all(r["ok"] for r in a) and all(r["ok"] for r in b):
        wa=statistics.median(r["work_per_step"] for r in a)
        wb=statistics.median(r["work_per_step"] for r in b)
        if wa: common_ratios.append(wb/wa)
common_ratio=statistics.median(common_ratios) if common_ratios else None
p=cand["median_refined_top_order"]
advance=(cand["complete_cases"]==4 and p is not None and p>=1.6 and
         cand["cases_order_ge_1p5"]>=3 and ratio_be is not None and ratio_be<=1.5 and
         common_ratio is not None and common_ratio<=1.10)
summary={"variants":summ,"work_ratio_vs_be_kimpl":ratio_be,
         "median_common_case_work_ratio_predictor_vs_base":common_ratio,
         "advance":advance}
print("F_PE_TIMEINT03B_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03B=PASS")
