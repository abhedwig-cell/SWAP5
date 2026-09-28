#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

variants=[
    ("BE_BASE",1,0),
    ("BE_FLOOR_SWITCH",1,1),
    ("BDF2_BASE",2,0),
    ("BDF2_FLOOR",2,1),
]

def run(mid,rain,dt,name,tmode,floor_mode):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),str(tmode),"1","8",str(floor_mode)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"variant":name,"material":mid,"rain":rain,"dt":dt,
                "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT04B_RESULT|")),None)
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
for name,tmode,floor_mode in variants:
    for mid,rain in cases:
        for dt in dts:
            rows.append(run(mid,rain,dt,name,tmode,floor_mode))

def ord3(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-11*scale or d2<=1e-11*scale: return None
    return math.log(d1/d2,2.0)

summ=[]
for name,_,_ in variants:
    per=[]; orders=[]; works=[]
    for mid,rain in cases:
        rs=sorted([r for r in rows if r["variant"]==name and r["material"]==mid and r["rain"]==rain],
                  key=lambda x:-x["dt"])
        complete=all(r["ok"] for r in rs)
        p=ord3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
        if p is not None and math.isfinite(p): orders.append(p)
        if complete: works.extend(r["work_per_step"] for r in rs)
        storages=[r["storage"] for r in rs if r["ok"]]
        storage_spread=max(storages)-min(storages) if storages else None
        per.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p,
                    "storage_spread":storage_spread})
    summ.append({"variant":name,
                 "complete_cases":sum(x["complete"] for x in per),
                 "orders":per,
                 "median_refined_top_order":statistics.median(orders) if orders else None,
                 "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in per),
                 "median_work_per_step":statistics.median(works) if works else None})

by={x["variant"]:x for x in summ}
base_map={(r["material"],r["rain"],r["dt"]):r for r in rows if r["variant"]=="BDF2_BASE"}
cand_map={(r["material"],r["rain"],r["dt"]):r for r in rows if r["variant"]=="BDF2_FLOOR"}

common=[]
for key,q in base_map.items():
    c=cand_map[key]
    if q["ok"] and c["ok"]:
        common.append({
            "material":key[0],"rain":key[1],"dt":key[2],
            "top_diff":abs(c["top_h"]-q["top_h"]),
            "mid_diff":abs(c["mid_h"]-q["mid_h"]),
            "bottom_diff":abs(c["bottom_h"]-q["bottom_h"]),
            "storage_diff":abs(c["storage"]-q["storage"]),
        })

be_base={(r["material"],r["rain"],r["dt"]):r for r in rows if r["variant"]=="BE_BASE"}
be_floor={(r["material"],r["rain"],r["dt"]):r for r in rows if r["variant"]=="BE_FLOOR_SWITCH"}
be_preserve=True
be_max_diff=0.0
for key,a in be_base.items():
    b=be_floor[key]
    if a["ok"]!=b["ok"]:
        be_preserve=False
        continue
    if a["ok"]:
        diffs=[abs(a[k]-b[k]) for k in ("top_h","mid_h","bottom_h","storage")]
        be_max_diff=max(be_max_diff,*diffs)
        if any(d!=0.0 for d in diffs) or a["work_index"]!=b["work_index"]:
            be_preserve=False

cand=by["BDF2_FLOOR"]; be=by["BE_BASE"]
work_ratio=cand["median_work_per_step"]/be["median_work_per_step"] if cand["median_work_per_step"] is not None else None
common_ok=(len(common)==15 and all(x["top_diff"]<=1e-8 and x["mid_diff"]<=1e-8 and
                              x["bottom_diff"]<=1e-8 and x["storage_diff"]<=1e-10 for x in common))
storage_ok=all(x["storage_spread"] is not None and x["storage_spread"]<=1e-10 for x in cand["orders"])
restored=cand_map[("B01",4.0,0.00125)]["ok"]
p=cand["median_refined_top_order"]
advance=(cand["complete_cases"]==4 and p is not None and p>=1.6 and
         cand["cases_order_ge_1p5"]>=3 and storage_ok and
         work_ratio is not None and work_ratio<=1.5 and common_ok and restored and be_preserve)

summary={
    "variants":summ,
    "work_ratio_bdf2_floor_vs_be_kimpl":work_ratio,
    "common_baseline_complete_points":len(common),
    "common_endpoint_gate_pass":common_ok,
    "common_endpoint_max":{
        "top":max([x["top_diff"] for x in common] or [None]),
        "mid":max([x["mid_diff"] for x in common] or [None]),
        "bottom":max([x["bottom_diff"] for x in common] or [None]),
        "storage":max([x["storage_diff"] for x in common] or [None]),
    },
    "restored_b01_rain4_dt0p00125":restored,
    "be_preserved_exactly":be_preserve,
    "be_max_endpoint_diff":be_max_diff,
    "storage_gate_pass":storage_ok,
    "advance":advance,
}
print("F_PE_TIMEINT04B_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04B_COMMON="+json.dumps(common,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04B=PASS")
