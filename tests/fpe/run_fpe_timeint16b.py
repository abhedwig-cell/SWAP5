#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); baseline=Path(sys.argv[2]); bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

def run_c(mid,rain,dt):
    m=mats[mid]
    cmd=[str(cand),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0,
         "stdout":cp.stdout[-1500:],"stderr":cp.stderr[-1000:]}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT16B_RESULT|")),None)
        if not line:
            row["ok"]=False; row["stderr"]="missing TIMEINT16B result"
        else:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("TOP_H","MID_H","BOTTOM_H","TOP_THETA","MID_THETA","BOTTOM_THETA","STORAGE",
                      "MAX_LEDGER","CUM_LEDGER","MAX_ROUNDTRIP","INIT_MASS_RATE",
                      "MAX_ORIGIN_RATE_ERR","MAX_PREDICTOR_RATE_RESIDUAL"):
                row[k.lower()]=float(d[k])
            for k in ("STEPS","NL","BACK","JAC","LIN","WORK"):
                row[k.lower()]=int(d[k])
            row["work_per_nominal_interval"]=row["work"]/row["steps"]
    return row

def run_b(mid,rain,dt):
    m=mats[mid]
    cmd=[str(baseline),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"1","1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_RESULT|")),None)
        if line:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("NL","BACK","JAC","LIN"): row[k.lower()]=int(d[k])
            row["steps"]=round(0.04/dt)
            row["work"]=row["nl"]+row["back"]+row["jac"]+row["lin"]
            row["work_per_nominal_interval"]=row["work"]/row["steps"]
        else:
            row["ok"]=False
    return row

def p3(rs,key):
    a,b,c=rs[1],rs[2],rs[3]
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-13*scale or d2<=1e-13*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; bases=[]
for mid,rain in cases:
    for dt in dts:
        rows.append(run_c(mid,rain,dt)); bases.append(run_b(mid,rain,dt))

case_s=[]; head_orders=[]; theta_orders=[]; work_ratios=[]
for mid,rain in cases:
    rs=sorted([x for x in rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    ph=p3(rs,"top_h") if len(rs)==4 else None
    pt=p3(rs,"top_theta") if len(rs)==4 else None
    if ph is not None and math.isfinite(ph): head_orders.append(ph)
    if pt is not None and math.isfinite(pt): theta_orders.append(pt)
    case_s.append({
        "material":mid,"rain":rain,"complete":all(x["ok"] for x in rs),
        "refined_top_head_order":ph,"refined_top_theta_order":pt,
        "max_ledger":max((abs(x["max_ledger"]) for x in rs if x["ok"]),default=None),
        "max_cumulative_ledger":max((abs(x["cum_ledger"]) for x in rs if x["ok"]),default=None),
        "max_roundtrip":max((x["max_roundtrip"] for x in rs if x["ok"]),default=None),
        "max_origin_rate_error":max((x["max_origin_rate_err"] for x in rs if x["ok"]),default=None),
        "max_predictor_rate_residual":max((x["max_predictor_rate_residual"] for x in rs if x["ok"]),default=None)
    })

for x in rows:
    if not x["ok"]: continue
    b=next((q for q in bases if q["ok"] and q["material"]==x["material"] and q["rain"]==x["rain"] and q["dt"]==x["dt"]),None)
    if b and b["work_per_nominal_interval"]>0:
        work_ratios.append(x["work_per_nominal_interval"]/b["work_per_nominal_interval"])

complete=all(x["complete"] for x in case_s)
med_h=statistics.median(head_orders) if head_orders else None
med_t=statistics.median(theta_orders) if theta_orders else None
head_count=sum(x["refined_top_head_order"] is not None and x["refined_top_head_order"]>=1.5 for x in case_s)
ledger=all(x["max_ledger"] is not None and x["max_ledger"]<=5e-8 and
           x["max_cumulative_ledger"] is not None and x["max_cumulative_ledger"]<=5e-8 for x in case_s)
roundtrip=all(x["max_roundtrip"] is not None and x["max_roundtrip"]<=1e-12 for x in case_s)
colloc=all(x["max_origin_rate_error"] is not None and x["max_origin_rate_error"]<=5e-8 and
           x["max_predictor_rate_residual"] is not None and x["max_predictor_rate_residual"]<=5e-8 for x in case_s)
medwork=statistics.median(work_ratios) if work_ratios else None

advance=bool(complete and med_t is not None and med_t>=1.6 and med_h is not None and med_h>=1.6 and
             head_count>=3 and ledger and roundtrip and colloc and medwork is not None and medwork<=1.25)

if not colloc:
    cls="TG_STAGE_COLLOCATION_IMPLEMENTATION_DEFECT"
elif advance:
    cls="TG_SECOND_ORDER_RESTORED_BY_EVENT_STARTUP"
else:
    cls="TG_ORDER_REDUCTION_PERSISTS_AFTER_STARTUP"

summary={"classification":cls,"advance":advance,"complete":complete,
         "median_refined_top_head_order":med_h,"median_refined_top_theta_order":med_t,
         "head_cases_order_ge_1p5":head_count,"ledger_ok":ledger,"roundtrip_ok":roundtrip,
         "collocation_ok":colloc,"median_work_ratio_vs_be":medwork,"cases":case_s}

print("F_PE_TIMEINT16B_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16B=PASS")
