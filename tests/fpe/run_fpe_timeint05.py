#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
base_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}

cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
base_dts=[0.01,0.005,0.0025,0.00125]
patterns=["R1","R1P5","R2","R3"]

def run_var(mid,rain,base_dt,pattern):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(base_dt),pattern,"1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT05_RESULT|")),None)
    if not line:
        return {"ok":False,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    out={"ok":True,"material":mid,"rain":rain,"base_dt":base_dt,"pattern":pattern}
    for k in ["TOP_H","MID_H","BOTTOM_H","STORAGE"]:
        out[k.lower()]=float(d[k])
    for k in ["NL","BACK","JAC","LIN","STEPS"]:
        out[k.lower()]=int(d[k])
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    out["work_per_step"]=out["work_index"]/out["steps"]
    return out

def run_const(mid,rain,dt):
    m=materials[mid]
    cmd=[str(base_exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"2","1","8","1"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"material":mid,"rain":rain,"dt":dt,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT04B_RESULT|")),None)
    if not line:
        return {"ok":False,"material":mid,"rain":rain,"dt":dt,"stderr":"missing baseline result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    out={"ok":True,"material":mid,"rain":rain,"dt":dt}
    for k in ["TOP_H","MID_H","BOTTOM_H","STORAGE"]:
        out[k.lower()]=float(d[k])
    for k in ["NL","BACK","JAC","LIN"]:
        out[k.lower()]=int(d[k])
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    out["steps"]=round(0.04/dt)
    out["work_per_step"]=out["work_index"]/out["steps"]
    return out

def order3(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-11*scale or d2<=1e-11*scale: return None
    return math.log(d1/d2,2.0)

rows=[]
for pattern in patterns:
    for mid,rain in cases:
        for dt in base_dts:
            rows.append(run_var(mid,rain,dt,pattern))

baseline=[]
for mid,rain in cases:
    for dt in base_dts:
        baseline.append(run_const(mid,rain,dt))

summaries=[]
for pattern in patterns:
    per=[]; orders=[]; works=[]
    for mid,rain in cases:
        rs=sorted([r for r in rows if r["pattern"]==pattern and r["material"]==mid and r["rain"]==rain],
                  key=lambda x:-x["base_dt"])
        complete=all(r["ok"] for r in rs)
        p=order3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
        if p is not None and math.isfinite(p): orders.append(p)
        if complete: works.extend(r["work_per_step"] for r in rs)
        stor=[r["storage"] for r in rs if r["ok"]]
        spread=max(stor)-min(stor) if stor else None
        per.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p,"storage_spread":spread})
    summaries.append({
        "pattern":pattern,
        "complete_cases":sum(x["complete"] for x in per),
        "orders":per,
        "median_refined_top_order":statistics.median(orders) if orders else None,
        "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in per),
        "median_work_per_step":statistics.median(works) if works else None
    })

base_map={(r["material"],r["rain"],r["dt"]):r for r in baseline}
r1_map={(r["material"],r["rain"],r["base_dt"]):r for r in rows if r["pattern"]=="R1"}
preserve=[]
for key,b in base_map.items():
    v=r1_map[key]
    if b["ok"] and v["ok"]:
        preserve.append({
            "material":key[0],"rain":key[1],"dt":key[2],
            "top_diff":abs(v["top_h"]-b["top_h"]),
            "mid_diff":abs(v["mid_h"]-b["mid_h"]),
            "bottom_diff":abs(v["bottom_h"]-b["bottom_h"]),
            "storage_diff":abs(v["storage"]-b["storage"]),
            "work_diff":v["work_index"]-b["work_index"]
        })

by={x["pattern"]:x for x in summaries}
r1_work=by["R1"]["median_work_per_step"]

def qualifies(name):
    s=by[name]
    storage_ok=all(x["storage_spread"] is not None and x["storage_spread"]<=1e-10 for x in s["orders"])
    wr=(s["median_work_per_step"]/r1_work) if s["median_work_per_step"] is not None and r1_work else None
    return {
      "pattern":name,
      "complete":s["complete_cases"]==4,
      "median_order":s["median_refined_top_order"],
      "orders_ge_1p5":s["cases_order_ge_1p5"],
      "storage_ok":storage_ok,
      "work_ratio_vs_r1":wr,
      "qualifies":bool(s["complete_cases"]==4 and s["median_refined_top_order"] is not None and
                       s["median_refined_top_order"]>=1.6 and s["cases_order_ge_1p5"]>=3 and
                       storage_ok and wr is not None and wr<=1.5)
    }

quals=[qualifies(x) for x in patterns]
preserve_ok=(len(preserve)==16 and all(x["top_diff"]<=1e-10 and x["mid_diff"]<=1e-10 and
                                      x["bottom_diff"]<=1e-10 and x["storage_diff"]<=1e-12 and
                                      x["work_diff"]==0 for x in preserve))

qmap={x["pattern"]:x for x in quals}
if qmap["R1"]["qualifies"] and qmap["R1P5"]["qualifies"] and qmap["R2"]["qualifies"] and preserve_ok:
    classification="VARIABLE_BDF2_RATIO2_MECHANISM_QUALIFIED"
elif qmap["R1"]["qualifies"] and qmap["R1P5"]["qualifies"] and preserve_ok:
    classification="VARIABLE_BDF2_RATIO1P5_MECHANISM_QUALIFIED"
else:
    classification="CLOSED_VARIABLE_BDF2_NOT_QUALIFIED"

summary={
  "patterns":summaries,
  "qualification":quals,
  "r1_preservation_points":len(preserve),
  "r1_preservation_pass":preserve_ok,
  "r1_max_diff":{
    "top":max([x["top_diff"] for x in preserve] or [None]),
    "mid":max([x["mid_diff"] for x in preserve] or [None]),
    "bottom":max([x["bottom_diff"] for x in preserve] or [None]),
    "storage":max([x["storage_diff"] for x in preserve] or [None]),
    "work":max([abs(x["work_diff"]) for x in preserve] or [None])
  },
  "classification":classification
}

print("F_PE_TIMEINT05_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_BASELINE="+json.dumps(baseline,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_PRESERVATION="+json.dumps(preserve,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05=PASS")
