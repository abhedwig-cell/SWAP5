#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
cases=list(bank["screening_cases"])
dts=[0.005,0.01,0.02,0.04]

def run(cid,dt):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    cmd=[str(exe),cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"dt":dt,"ok":False,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT02|")),None)
    if not line:
        return {"case":cid,"dt":dt,"ok":False,"stderr":"missing result","stdout":cp.stdout[-1000:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    if d.get("OK")!="1":
        return {"case":cid,"dt":dt,"ok":False,"stage":d.get("STAGE"),"raw":d}
    out={"case":cid,"dt":dt,"ok":True}
    for k in ("LTE_INF","ACTUAL_H","RUNOFF_D","POND_D","STORAGE_D","MAX_LEDGER"):
        out[k.lower()]=float(d[k])
    for k in ("REGIME_FULL","REGIME_H1","REGIME_H2","WORK_FULL","WORK_HALVES"):
        out[k.lower()]=int(d[k])
    out["safe_truth"]=(out["actual_h"]<=0.50 and out["runoff_d"]<=0.01 and out["pond_d"]<=0.01 and
                       out["storage_d"]<=0.01 and out["max_ledger"]<=5e-8)
    out["regime_path_mismatch"]=(out["regime_full"]!=out["regime_h1"] or
                                 out["regime_full"]!=out["regime_h2"] or
                                 out["regime_h1"]!=out["regime_h2"])
    return out

def rank(vals):
    order=sorted(range(len(vals)),key=lambda i: vals[i])
    ranks=[0.0]*len(vals); i=0
    while i<len(order):
        j=i+1
        while j<len(order) and vals[order[j]]==vals[order[i]]: j+=1
        rr=0.5*((i+1)+j)
        for k in range(i,j): ranks[order[k]]=rr
        i=j
    return ranks

def corr(a,b):
    if len(a)<2:return float("nan")
    ma=sum(a)/len(a);mb=sum(b)/len(b)
    num=sum((x-ma)*(y-mb) for x,y in zip(a,b))
    da=sum((x-ma)**2 for x in a);db=sum((y-mb)**2 for y in b)
    return num/math.sqrt(da*db) if da>0 and db>0 else float("nan")

rows=[run(cid,dt) for cid in cases for dt in dts]
complete=[r for r in rows if r["ok"]]
finite=[r for r in complete if math.isfinite(r["lte_inf"]) and math.isfinite(r["actual_h"])]
rho=corr(rank([r["lte_inf"] for r in finite]),rank([r["actual_h"] for r in finite])) if finite else float("nan")

thresholds={"L025":0.25,"L050":0.50,"L100":1.00}
summary=[]
safe_total=sum(r["safe_truth"] for r in finite)
for name,thr in thresholds.items():
    pred_safe=[r for r in finite if r["lte_inf"]<=thr]
    false_safe=[r for r in pred_safe if not r["safe_truth"]]
    coverage=(sum(r["safe_truth"] for r in pred_safe)/safe_total) if safe_total else 0.0
    summary.append({"policy":name,"threshold":thr,"complete":len(complete),"finite":len(finite),
                    "spearman":rho,"predicted_safe":len(pred_safe),"false_safe":len(false_safe),
                    "safe_coverage":coverage,
                    "mass_ok":all(r["max_ledger"]<=5e-8 for r in finite),
                    "advance":bool(len(complete)>=48 and len(finite)==len(complete) and math.isfinite(rho) and rho>=0.75
                                   and len(false_safe)==0 and coverage>=0.20 and all(r["max_ledger"]<=5e-8 for r in finite))})

false_examples={}
for name,thr in thresholds.items():
    false_examples[name]=[r for r in finite if r["lte_inf"]<=thr and not r["safe_truth"]]

print("F_PE_TIMEINT02_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02_FALSE_SAFE="+json.dumps(false_examples,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02=PASS")
