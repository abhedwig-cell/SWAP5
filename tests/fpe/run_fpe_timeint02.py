#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]
variants=[
 ("BE_KLAG",1,0),
 ("BE_KIMPL",1,1),
 ("BDF2_KLAG",2,0),
 ("BDF2_KIMPL",2,1),
]

def run(mid,rain,dt,tmode,kimpl,name):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),str(tmode),str(kimpl)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"material":mid,"rain":rain,"dt":dt,"variant":name,
                "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT02_RESULT|")),None)
    if not line:
        return {"ok":False,"material":mid,"rain":rain,"dt":dt,"variant":name,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    out={"ok":True,"material":mid,"rain":rain,"dt":dt,"variant":name}
    for k in ["TOP_H","MID_H","BOTTOM_H","STORAGE"]:
        out[k.lower()]=float(d[k])
    for k in ["NL","BACK","JAC","LIN"]:
        out[k.lower()]=int(d[k])
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    out["steps"]=round(0.04/dt)
    out["work_per_step"]=out["work_index"]/out["steps"]
    return out

rows=[]
for name,tmode,kimpl in variants:
    for mid,rain in cases:
        for dt in dts:
            rows.append(run(mid,rain,dt,tmode,kimpl,name))

def ord3(a,b,c,key):
    if not (a["ok"] and b["ok"] and c["ok"]): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-11*scale or d2<=1e-11*scale: return None
    return math.log(d1/d2,2.0)

summ=[]
for name,_,_ in variants:
    orders=[]; per_case=[]; works=[]
    for mid,rain in cases:
        rs=sorted([r for r in rows if r["variant"]==name and r["material"]==mid and r["rain"]==rain],
                  key=lambda x:-x["dt"])
        complete=all(r["ok"] for r in rs)
        p=ord3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
        if p is not None and math.isfinite(p): orders.append(p)
        if complete: works.extend([r["work_per_step"] for r in rs])
        per_case.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p})
    med=statistics.median(orders) if orders else None
    summ.append({"variant":name,"complete_cases":sum(x["complete"] for x in per_case),"orders":per_case,
                 "median_refined_top_order":med,
                 "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in per_case),
                 "median_work_per_step":statistics.median(works) if works else None})

by={x["variant"]:x for x in summ}
for name in ["BDF2_KLAG","BDF2_KIMPL"]:
    match="BE_KLAG" if name.endswith("KLAG") else "BE_KIMPL"
    if by[name]["median_work_per_step"] is not None and by[match]["median_work_per_step"]:
        by[name]["work_ratio_vs_matching_be"]=by[name]["median_work_per_step"]/by[match]["median_work_per_step"]
        by[name]["advance"]=bool(by[name]["complete_cases"]==4 and
            by[name]["median_refined_top_order"] is not None and by[name]["median_refined_top_order"]>=1.6 and
            by[name]["cases_order_ge_1p5"]>=3 and by[name]["work_ratio_vs_matching_be"]<=1.5)
    else:
        by[name]["work_ratio_vs_matching_be"]=None
        by[name]["advance"]=False

print("F_PE_TIMEINT02_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02_SUMMARY="+json.dumps(summ,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02=PASS")
