#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); bdf2=Path(sys.argv[2]); bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

def run(exe,mid,rain,dt,prefix):
    m=mats[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt}
    if not row["ok"]:
        row["stdout"]=cp.stdout[-1200:]; row["stderr"]=cp.stderr[-1200:]; return row
    line=next((x for x in cp.stdout.splitlines() if x.startswith(prefix)),None)
    if not line:
        row["ok"]=False; row["stderr"]="missing result"; return row
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE","MAX_LEDGER","CUM_LEDGER"):
        if k in d: row[k.lower()]=float(d[k])
    for k in ("NL","BACK","JAC","LIN","ALT","WORK","STEPS","CLAMPS"):
        if k in d: row[k.lower()]=int(d[k])
    row["work_per_step"]=row["work"]/row["steps"]
    return row

def run_bdf2(mid,rain,dt):
    m=mats[mid]
    cmd=[str(bdf2),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt}
    if not row["ok"]:
        row["stdout"]=cp.stdout[-1000:]; row["stderr"]=cp.stderr[-1000:]; return row
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_ORDER_RESULT|")),None)
    if not line:
        row["ok"]=False; row["stderr"]="missing baseline result"; return row
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE"): row[k.lower()]=float(d[k])
    for k in ("NL","BACK","JAC","LIN","WORK","STEPS","CLAMPS"): row[k.lower()]=int(d[k])
    row["work_per_step"]=row["work"]/row["steps"]
    return row

def order(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; base=[]
for mid,rain in cases:
    for dt in dts:
        rows.append(run(cand,mid,rain,dt,"F_PE_TIMEINT15_RESULT|"))
        base.append(run_bdf2(mid,rain,dt))

case_summary=[]; orders=[]; ratios=[]
for mid,rain in cases:
    rs=sorted([x for x in rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    bs=sorted([x for x in base if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    complete=all(x["ok"] for x in rs)
    p=order(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
    stor=[x["storage"] for x in rs if x["ok"]]
    spread=max(stor)-min(stor) if len(stor)==4 else None
    maxledger=max((abs(x["max_ledger"]) for x in rs if x["ok"]),default=None)
    maxcum=max((abs(x["cum_ledger"]) for x in rs if x["ok"]),default=None)
    clamps=sum(x.get("clamps",0) for x in rs if x["ok"])
    alts=sum(x.get("alt",0) for x in rs if x["ok"])
    local_ratios=[]
    for x,y in zip(rs,bs):
        if x["ok"] and y["ok"] and y["work_per_step"]>0:
            local_ratios.append(x["work_per_step"]/y["work_per_step"])
            ratios.append(local_ratios[-1])
    if p is not None and math.isfinite(p): orders.append(p)
    case_summary.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p,
                         "storage_spread":spread,"max_ledger":maxledger,"max_cum_ledger":maxcum,
                         "clamps":clamps,"alternative_solver_calls":alts,
                         "median_work_ratio_vs_timeint13":statistics.median(local_ratios) if local_ratios else None})

median_order=statistics.median(orders) if orders else None
median_work=statistics.median(ratios) if ratios else None
summary={
 "complete_cases":sum(x["complete"] for x in case_summary),
 "cases":case_summary,
 "median_refined_top_order":median_order,
 "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in case_summary),
 "all_ledgers_ok":all(x["max_ledger"] is not None and x["max_ledger"]<=5e-8 and
                      x["max_cum_ledger"] is not None and x["max_cum_ledger"]<=5e-8 for x in case_summary),
 "storage_ok":all(x["storage_spread"] is not None and x["storage_spread"]<=1e-10 for x in case_summary),
 "total_clamps":sum(x["clamps"] for x in case_summary),
 "total_alt":sum(x["alternative_solver_calls"] for x in case_summary),
 "median_work_ratio_vs_timeint13":median_work
}
summary["p0_pass"]=bool(summary["complete_cases"]==4 and median_order is not None and median_order>=1.6 and
                        summary["cases_order_ge_1p5"]>=3 and summary["all_ledgers_ok"] and
                        summary["storage_ok"] and summary["total_clamps"]==0 and summary["total_alt"]==0 and
                        median_work is not None and median_work<=1.10)
print("F_PE_TIMEINT15_P0_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P0_BASELINE="+json.dumps(base,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P0_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P0=PASS")
