#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); baseline=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

def run_c(mid,rain,dt):
    m=mats[mid]
    cmd=[str(cand),mid,"RANNACHER_KIMPL",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT15A_RESULT|")),None)
        if not line:
            out["ok"]=False; out["stderr"]="missing result"; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE","MAX_LEDGER","CUM_LEDGER"): out[k.lower()]=float(d[k])
        for k in ("STEPS","NL","BACK","JAC","LIN","WORK"): out[k.lower()]=int(d[k])
        out["work_per_nominal_interval"]=out["work"]/out["steps"]
    return out

def run_b(mid,rain,dt):
    m=mats[mid]
    cmd=[str(baseline),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"1","1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_RESULT|")),None)
        if line:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("NL","BACK","JAC","LIN"): out[k.lower()]=int(d[k])
            out["steps"]=round(0.04/dt)
            out["work"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
            out["work_per_nominal_interval"]=out["work"]/out["steps"]
        else:
            out["ok"]=False
    return out

def p3(a,b,c):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a["top_h"]-b["top_h"]); d2=abs(b["top_h"]-c["top_h"])
    scale=max(1.0,abs(a["top_h"]),abs(b["top_h"]),abs(c["top_h"]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; bases=[]
for mid,rain in cases:
    for dt in dts:
        rows.append(run_c(mid,rain,dt)); bases.append(run_b(mid,rain,dt))

case_s=[]; orders=[]; ratios=[]
for mid,rain in cases:
    rs=sorted([x for x in rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    p=p3(rs[1],rs[2],rs[3]) if len(rs)==4 else None
    if p is not None and math.isfinite(p): orders.append(p)
    case_s.append({"material":mid,"rain":rain,"complete":all(x["ok"] for x in rs),"p_top_refined":p,
                   "max_ledger":max((abs(x["max_ledger"]) for x in rs if x["ok"]),default=None),
                   "max_cum_ledger":max((abs(x["cum_ledger"]) for x in rs if x["ok"]),default=None)})
for x in rows:
    if not x["ok"]: continue
    b=next((q for q in bases if q["ok"] and q["material"]==x["material"] and q["rain"]==x["rain"] and q["dt"]==x["dt"]),None)
    if b: ratios.append(x["work_per_nominal_interval"]/b["work_per_nominal_interval"])

medp=statistics.median(orders) if orders else None
medr=statistics.median(ratios) if ratios else None
complete=all(x["complete"] for x in case_s)
count=sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in case_s)
ledger=all(x["max_ledger"] is not None and x["max_ledger"]<=5e-8 and
           x["max_cum_ledger"] is not None and x["max_cum_ledger"]<=5e-8 for x in case_s)
advance=bool(complete and medp is not None and medp>=1.6 and count>=3 and ledger and medr is not None and medr<=1.20)
summary={"complete":complete,"cases":case_s,"median_refined_top_order":medp,"cases_order_ge_1p5":count,
         "ledger_ok":ledger,"median_work_ratio_vs_be":medr,"advance":advance,
         "classification":("TRAPEZOIDAL_SECOND_ORDER_WITH_EVENT_STARTUP_CONFIRMED" if advance else
                           "TRAPEZOIDAL_ORDER_REDUCTION_NOT_RESCUED_BY_RANNACHER_STARTUP")}
print("F_PE_TIMEINT15A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15A=PASS")
