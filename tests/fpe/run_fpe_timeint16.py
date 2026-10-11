#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); baseline=Path(sys.argv[2]); bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

def parse_tg(line):
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    for k in ("STEPS","NL","BACK","JAC","LIN","WORK"): d[k]=int(d[k])
    for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE","MAX_LEDGER","CUM_LEDGER","MAX_ROUNDTRIP","INIT_MASS_RATE"):
        d[k]=float(d[k])
    return d

def run_tg(mid,rain,dt):
    m=mats[mid]
    cmd=[str(cand),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT16_RESULT|")),None)
        if line: row.update(parse_tg(line))
        else: row.update(ok=False,stderr="missing TG result")
    else:
        row["stdout"]=cp.stdout[-1500:]; row["stderr"]=cp.stderr[-1000:]
    return row

def run_be(mid,rain,dt):
    m=mats[mid]
    cmd=[str(baseline),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"1","1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"rain":rain,"dt":dt,"ok":cp.returncode==0}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_RESULT|")),None)
        if line:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("NL","BACK","JAC","LIN"): row[k]=int(d[k])
            row["STEPS"]=round(0.04/dt)
            row["WORK"]=row["NL"]+row["BACK"]+row["JAC"]+row["LIN"]
        else: row.update(ok=False,stderr="missing BE result")
    return row

def refined_order(rs):
    a,b,c=rs[1],rs[2],rs[3]
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a["TOP_H"]-b["TOP_H"]); d2=abs(b["TOP_H"]-c["TOP_H"])
    scale=max(1.0,abs(a["TOP_H"]),abs(b["TOP_H"]),abs(c["TOP_H"]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; bases=[]
for mid,rain in cases:
    for dt in dts:
        rows.append(run_tg(mid,rain,dt))
        bases.append(run_be(mid,rain,dt))

case_summary=[]; orders=[]; work_ratios=[]
all_ledger=True; all_cum=True; all_rt=True; all_storage=True; all_init=True
for mid,rain in cases:
    rs=sorted([x for x in rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    complete=all(x["ok"] for x in rs)
    p=refined_order(rs) if len(rs)==4 else None
    if p is not None and math.isfinite(p): orders.append(p)
    spread=(max(x["STORAGE"] for x in rs)-min(x["STORAGE"] for x in rs)) if complete else None
    maxledger=max((abs(x["MAX_LEDGER"]) for x in rs if x["ok"]),default=None)
    maxcum=max((abs(x["CUM_LEDGER"]) for x in rs if x["ok"]),default=None)
    maxrt=max((abs(x["MAX_ROUNDTRIP"]) for x in rs if x["ok"]),default=None)
    initerr=max((abs(x["INIT_MASS_RATE"]-rain) for x in rs if x["ok"]),default=None)
    case_summary.append({"material":mid,"rain":rain,"complete":complete,"refined_top_order":p,
                         "storage_spread":spread,"max_ledger":maxledger,"max_cumulative_ledger":maxcum,
                         "max_roundtrip":maxrt,"max_initial_mass_rate_error":initerr})
    all_ledger=all_ledger and complete and maxledger is not None and maxledger<=5e-8
    all_cum=all_cum and complete and maxcum is not None and maxcum<=5e-8
    all_rt=all_rt and complete and maxrt is not None and maxrt<=1e-12
    all_storage=all_storage and complete and spread is not None and spread<=1e-10
    all_init=all_init and complete and initerr is not None and initerr<=5e-8

for x in rows:
    if not x["ok"]: continue
    b=next((q for q in bases if q["ok"] and q["material"]==x["material"] and q["rain"]==x["rain"] and q["dt"]==x["dt"]),None)
    if b and b["WORK"]>0 and b["STEPS"]>0:
        work_ratios.append((x["WORK"]/x["STEPS"])/(b["WORK"]/b["STEPS"]))

complete_cases=sum(x["complete"] for x in case_summary)
medp=statistics.median(orders) if orders else None
nge=sum(x["refined_top_order"] is not None and x["refined_top_order"]>=1.5 for x in case_summary)
medwork=statistics.median(work_ratios) if work_ratios else None
advance=bool(complete_cases==4 and medp is not None and medp>=1.6 and nge>=3 and
             all_ledger and all_cum and all_rt and all_storage and all_init and
             medwork is not None and medwork<=1.50)
if advance:
    cls="QUALIFIED_MOISTURE_THOMAS_GLADWELL_SMOOTH_MECHANISM"
elif not all_rt:
    cls="CLOSED_TG_CONSTITUTIVE_STATE_INCOMPATIBLE_WITH_SWAP_ENDPOINT_CONTRACT"
elif not all_ledger or not all_cum or not all_init:
    cls="CLOSED_TG_PHYSICAL_INTERVAL_CONSERVATION_FAILED"
elif medp is None or medp<1.6 or nge<3:
    cls="CLOSED_TG_SECOND_ORDER_NOT_REPRODUCED"
elif medwork is not None and medwork>1.50:
    cls="TG_MECHANISM_QUALIFIED_COST_BLOCKED"
else:
    cls="BLOCKED_TIMEINT16_UNCLASSIFIED"

summary={"classification":cls,"advance":advance,"complete_cases":complete_cases,
         "median_refined_top_order":medp,"cases_order_ge_1p5":nge,
         "physical_interval_ledger_ok":all_ledger,"cumulative_ledger_ok":all_cum,
         "constitutive_roundtrip_ok":all_rt,"storage_ok":all_storage,
         "initial_derivative_mass_ok":all_init,"median_work_ratio_vs_be":medwork,
         "cases":case_summary}
print("F_PE_TIMEINT16_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16_BASELINES="+json.dumps(bases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16=PASS")
