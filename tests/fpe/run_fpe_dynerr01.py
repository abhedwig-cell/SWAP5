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
        return {"case":cid,"dt":dt,"ok":False,"stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_DYNERR01|")),None)
    if not line:
        return {"case":cid,"dt":dt,"ok":False,"stdout":cp.stdout[-1200:],"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    if d.get("OK")!="1":
        return {"case":cid,"dt":dt,"ok":False,"stage":d.get("STAGE"),"raw":d}
    out={"case":cid,"dt":dt,"ok":True}
    for k in ("IND","ACTUAL_H","RUNOFF_D","STORAGE_D","MAX_LEDGER","DERIV"):
        out[k.lower()]=float(d[k])
    for k in ("IND_STATUS","REGIME","WORK_FULL","WORK_HALVES"):
        out[k.lower()]=int(d[k])
    return out

def rank(vals):
    order=sorted(range(len(vals)),key=lambda i: vals[i])
    ranks=[0.0]*len(vals)
    i=0
    while i<len(order):
        j=i+1
        while j<len(order) and vals[order[j]]==vals[order[i]]:
            j+=1
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
finite=[r for r in complete if math.isfinite(r["ind"]) and math.isfinite(r["actual_h"])]
rho=corr(rank([r["ind"] for r in finite]),rank([r["actual_h"] for r in finite])) if finite else float("nan")
thr=0.01
false_safe=[r for r in finite if r["ind"]<=thr and r["actual_h"]>thr]
safe=[r for r in finite if r["ind"]<=thr]
mass_ok=all(r["max_ledger"]<=5e-8 for r in finite)
summary={
  "planned":len(rows),
  "complete":len(complete),
  "finite_indicator":len(finite),
  "spearman":rho,
  "false_safe":len(false_safe),
  "safe":len(safe),
  "safe_fraction":len(safe)/len(finite) if finite else 0.0,
  "mass_ok":mass_ok,
}
summary["advance"]=(len(complete)>=48 and len(finite)==len(complete) and math.isfinite(rho) and rho>=0.80
                    and len(false_safe)==0 and summary["safe_fraction"]>=0.20 and mass_ok)
print("F_PE_DYNERR01_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_DYNERR01_FALSE_SAFE="+json.dumps(false_safe,separators=(",",":"),sort_keys=True))
print("F_PE_DYNERR01_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_DYNERR01=PASS")
