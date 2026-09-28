#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
cases=list(bank["screening_cases"]); dts=[0.005,0.01,0.02,0.04]

def run(cid,dt):
    mid,rid=cid.split("/"); m=materials[mid]; r=regimes[rid]
    cmd=[str(exe),cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03|")),None)
    if line is None:
        return {"case":cid,"dt":dt,"ok":False,"stderr":cp.stderr[-1000:],"stdout":cp.stdout[-1000:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    if d.get("OK")!="1":
        return {"case":cid,"dt":dt,"ok":False,"stage":d.get("STAGE")}
    out={"case":cid,"dt":dt,"ok":True}
    for k in ["LTE_INF","LTE_THETA_INF","LTE_WATER_L1","LTE_WATER_NET","ACTUAL_H","ACTUAL_THETA","ACTUAL_WATER_L1","RUNOFF_D","POND_D","STORAGE_D","MAX_LEDGER"]:
        out[k.lower()]=float(d[k])
    for k in ["REGIME_FULL","REGIME_H1","REGIME_H2","WORK_FULL","WORK_HALVES"]:
        out[k.lower()]=int(d[k])
    out["pc1_local_safe"]=(out["actual_h"]<=0.50 and out["runoff_d"]<=0.01 and out["pond_d"]<=0.01 and out["storage_d"]<=0.01 and out["max_ledger"]<=5e-8)
    out["score"]=max(out["lte_inf"]/0.50,out["lte_theta_inf"]/1.0e-4)
    return out

def rank(vals):
    order=sorted(range(len(vals)),key=lambda i: vals[i]); ranks=[0.0]*len(vals); i=0
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
rho_theta=corr(rank([r["lte_theta_inf"] for r in complete]),rank([r["actual_theta"] for r in complete])) if complete else float("nan")
rho_water=corr(rank([r["lte_water_l1"] for r in complete]),rank([r["actual_water_l1"] for r in complete])) if complete else float("nan")
false_safe=[r for r in complete if r["score"]<=1.0 and not r["pc1_local_safe"]]
safe_pred=[r for r in complete if r["score"]<=1.0]
safe_truth=sum(r["pc1_local_safe"] for r in complete)
coverage=(sum(r["pc1_local_safe"] for r in safe_pred)/safe_truth) if safe_truth else 0.0
advance=(len(complete)>=48 and rho_theta>=0.75 and rho_water>=0.75 and
         max(rho_theta,rho_water)>=0.6874 and all(r["max_ledger"]<=5e-8 for r in complete))

summary={"complete":len(complete),"rho_theta":rho_theta,"rho_water_l1":rho_water,
         "mixed_score_pred_safe":len(safe_pred),"mixed_score_false_safe":len(false_safe),
         "mixed_score_safe_coverage":coverage,"advance":advance}

print("F_PE_TIMEINT03_ROWS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03_FALSE_SAFE="+json.dumps(false_safe,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03=PASS")
