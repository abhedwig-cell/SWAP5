#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1])
baseline=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}

cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]
arms=["TR_KIMPL","TR_KPRED"]

def run_candidate(mid,rain,dt,arm):
    m=mats[mid]
    cmd=[str(cand),mid,arm,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"rain":rain,"dt":dt,"arm":arm,"ok":cp.returncode==0,
         "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT15_RESULT|")),None)
        if not line:
            out["ok"]=False; out["stderr"]="missing result"; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE","MAX_LEDGER","CUM_LEDGER"):
            out[k.lower()]=float(d[k])
        for k in ("STEPS","NL","BACK","JAC","LIN","WORK","CLAMPS"):
            out[k.lower()]=int(d[k])
        out["work_per_step"]=out["work"]/out["steps"]
    return out

def run_baseline(mid,rain,dt,kimpl):
    m=mats[mid]
    cmd=[str(baseline),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"1",str(kimpl),"8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"rain":rain,"dt":dt,"kimpl":kimpl,"ok":cp.returncode==0,
         "stdout":cp.stdout[-800:],"stderr":cp.stderr[-800:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_RESULT|")),None)
        if not line:
            out["ok"]=False; out["stderr"]="missing baseline result"; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE"): out[k.lower()]=float(d[k])
        for k in ("NL","BACK","JAC","LIN"): out[k.lower()]=int(d[k])
        out["steps"]=round(0.04/dt)
        out["work"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
        out["work_per_step"]=out["work"]/out["steps"]
    return out

def order3(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

rows=[]
baselines=[]
for mid,rain in cases:
    for dt in dts:
        for arm in arms:
            rows.append(run_candidate(mid,rain,dt,arm))
        baselines.append(run_baseline(mid,rain,dt,1))
        baselines.append(run_baseline(mid,rain,dt,0))

summaries=[]
for arm in arms:
    case_summary=[]; orders=[]; ratios=[]; all_rows=[x for x in rows if x["arm"]==arm]
    for mid,rain in cases:
        rs=sorted([x for x in all_rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
        p=order3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
        if p is not None and math.isfinite(p): orders.append(p)
        case_summary.append({"material":mid,"rain":rain,"complete":all(x["ok"] for x in rs),
                             "p_top_refined":p,
                             "max_ledger":max((abs(x["max_ledger"]) for x in rs if x["ok"]),default=None),
                             "max_cum_ledger":max((abs(x["cum_ledger"]) for x in rs if x["ok"]),default=None),
                             "clamps":sum(x.get("clamps",0) for x in rs if x["ok"])})
    kimpl=1 if arm=="TR_KIMPL" else 0
    for x in all_rows:
        if not x["ok"]: continue
        b=next((q for q in baselines if q["material"]==x["material"] and q["rain"]==x["rain"] and
                q["dt"]==x["dt"] and q["kimpl"]==kimpl and q["ok"]),None)
        if b and b["work_per_step"]>0: ratios.append(x["work_per_step"]/b["work_per_step"])
    med_order=statistics.median(orders) if orders else None
    med_ratio=statistics.median(ratios) if ratios else None
    complete=all(x["complete"] for x in case_summary)
    order_count=sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in case_summary)
    ledger_ok=all(x["max_ledger"] is not None and x["max_ledger"]<=5e-8 and
                  x["max_cum_ledger"] is not None and x["max_cum_ledger"]<=5e-8 for x in case_summary)
    clamp_ok=(arm!="TR_KPRED" or sum(x["clamps"] for x in case_summary)==0)
    work_gate=1.25 if arm=="TR_KIMPL" else 1.10
    advance=bool(complete and med_order is not None and med_order>=1.6 and order_count>=3 and
                 ledger_ok and clamp_ok and med_ratio is not None and med_ratio<=work_gate)
    summaries.append({"arm":arm,"complete":complete,"cases":case_summary,
                      "median_refined_top_order":med_order,"cases_order_ge_1p5":order_count,
                      "ledger_ok":ledger_ok,"clamp_ok":clamp_ok,
                      "median_work_ratio_vs_be":med_ratio,"work_gate":work_gate,"advance":advance})

primary=next(x for x in summaries if x["arm"]=="TR_KPRED")
kim=next(x for x in summaries if x["arm"]=="TR_KIMPL")
classification=("CONSERVATIVE_TRAPEZOIDAL_KPRED_MECHANISM_QUALIFIED" if primary["advance"] else
                "CONSERVATIVE_TRAPEZOIDAL_KIMPL_ONLY" if kim["advance"] else
                "CLOSED_CONSERVATIVE_TRAPEZOIDAL_NOT_QUALIFIED")

print("F_PE_TIMEINT15_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_BASELINES="+json.dumps(baselines,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_SUMMARY="+json.dumps(summaries,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_CLASSIFICATION="+classification)
print("F_PE_TIMEINT15=PASS")
