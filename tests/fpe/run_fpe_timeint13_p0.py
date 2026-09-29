#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); comp=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]

def parse(line,prefix):
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=("NL","BACK","JAC","LIN","WORK","STEPS","CLAMPS")
    floats=("TOP_H","MID_H","BOTTOM_H","STORAGE")
    for k in ints:
        if k in d: d[k]=int(d[k])
    for k in floats:
        if k in d: d[k]=float(d[k])
    return d

def run_c(mid,rain,dt):
    m=mats[mid]
    cmd=[str(cand),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_ORDER_RESULT|")),None)
        if not line: row={"ok":False,"material":mid,"rain":rain,"dt":dt,"stderr":"missing result"}
        else: row.update(parse(line,"F_PE_TIMEINT13_ORDER_RESULT"))
    else:
        row["stdout"]=cp.stdout[-900:]; row["stderr"]=cp.stderr[-900:]
    return row

def run_kimpl(mid,rain,dt):
    m=mats[mid]
    cmd=[str(comp),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"R1","1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT05_RESULT|")),None)
        if not line: row={"ok":False,"material":mid,"rain":rain,"dt":dt,"stderr":"missing comparator"}
        else:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("NL","BACK","JAC","LIN","STEPS"): d[k]=int(d[k])
            for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE"): d[k]=float(d[k])
            d["WORK"]=d["NL"]+d["BACK"]+d["JAC"]+d["LIN"]
            row.update(d)
    else:
        row["stdout"]=cp.stdout[-900:]; row["stderr"]=cp.stderr[-900:]
    return row

def order(a,b,c):
    d1=abs(a["TOP_H"]-b["TOP_H"]); d2=abs(b["TOP_H"]-c["TOP_H"])
    scale=max(1.0,abs(a["TOP_H"]),abs(b["TOP_H"]),abs(c["TOP_H"]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

candidate=[]; comparator=[]
for mid,rain in cases:
    for dt in dts:
        candidate.append(run_c(mid,rain,dt))
        comparator.append(run_kimpl(mid,rain,dt))

case_summary=[]; refined_orders=[]; work_ratios=[]
for mid,rain in cases:
    cr=sorted([x for x in candidate if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    kr=sorted([x for x in comparator if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    complete=all(x["ok"] for x in cr)
    p_ref=order(cr[1],cr[2],cr[3]) if complete else None
    storage_spread=(max(x["STORAGE"] for x in cr)-min(x["STORAGE"] for x in cr)) if complete else None
    clamps=sum(x.get("CLAMPS",0) for x in cr if x["ok"])
    ratios=[]
    for x,y in zip(cr,kr):
        if x["ok"] and y["ok"] and y["WORK"]>0 and x["STEPS"]>0 and y["STEPS"]>0:
            ratios.append((x["WORK"]/x["STEPS"])/(y["WORK"]/y["STEPS"]))
            work_ratios.append(ratios[-1])
    if p_ref is not None and math.isfinite(p_ref): refined_orders.append(p_ref)
    case_summary.append({"material":mid,"rain":rain,"complete":complete,"refined_top_order":p_ref,
                         "storage_spread":storage_spread,"clamps":clamps,
                         "median_work_per_step_ratio":statistics.median(ratios) if ratios else None})

complete_cases=sum(x["complete"] for x in case_summary)
median_order=statistics.median(refined_orders) if refined_orders else None
individual_pass=sum(x is not None and x>=1.5 for x in refined_orders)
storage_ok=all(x["storage_spread"] is not None and x["storage_spread"]<=1e-10 for x in case_summary)
clamp_ok=all(x["clamps"]==0 for x in case_summary)
median_work=statistics.median(work_ratios) if work_ratios else None
summary={"complete_cases":complete_cases,"total_cases":4,"median_refined_top_order":median_order,
         "individual_orders_ge_1p5":individual_pass,"storage_ok":storage_ok,"clamp_ok":clamp_ok,
         "median_work_per_step_ratio_vs_kimpl":median_work,
         "advance":bool(complete_cases==4 and median_order is not None and median_order>=1.6 and
                        individual_pass>=3 and storage_ok and clamp_ok and median_work is not None and median_work<=1.0)}
print("F_PE_TIMEINT13_P0_CANDIDATE="+json.dumps(candidate,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0_COMPARATOR="+json.dumps(comparator,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0_CASES="+json.dumps(case_summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0=PASS")
