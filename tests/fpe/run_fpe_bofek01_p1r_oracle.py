#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]; cases=list(bank["screening_cases"])
arms={"O8":8,"O20":20,"O48":48}

def decode(cid):
    m,r=cid.split("/"); return materials[m],regimes[r]

def run(cid,arm,dt):
    m,r=decode(cid); maxit=arms[arm]
    cfg=dict(dtmin=dt,dtmax=dt,dt0=dt,numbit=base["numbit_crit"],maxit=maxit,
             maxback=8,inc=base["fact_inc"],dec=base["fact_dec"],fail=base["fact_fail_divisor"],
             headtol=base["head_abs_tol"])
    cmd=[str(exe),cid,f"{arm}_{dt}",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(cfg["dtmin"]),str(cfg["dtmax"]),str(cfg["dt0"]),str(cfg["numbit"]),str(cfg["maxit"]),
         str(cfg["maxback"]),str(cfg["inc"]),str(cfg["dec"]),str(cfg["fail"]),str(cfg["headtol"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"case":cid,"arm":arm,"dt":dt,"stdout":cp.stdout[-500:],"stderr":cp.stderr[-500:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line: return {"ok":False,"case":cid,"arm":arm,"dt":dt,"stdout":cp.stdout[-500:],"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"ok":True,"case":cid,"arm":arm,"dt":dt}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    return out

def delta(a,b):
    return {k:abs(a[k]-b[k]) for k in ["cum_runoff","pond","storage","top_h","mid_h","bottom_h"]}

def conv(d):
    return d["cum_runoff"]<=1e-4 and d["pond"]<=1e-4 and d["storage"]<=1e-4 and            d["top_h"]<=1e-3 and d["mid_h"]<=1e-3 and d["bottom_h"]<=1e-3

allr={}; summary=[]
for arm in arms:
    complete=0; resolved=0
    cases_out={}
    for cid in cases:
        coarse=run(cid,arm,0.0005); fine=run(cid,arm,0.00025)
        ok=coarse["ok"] and fine["ok"]
        if ok: complete+=1
        d=delta(coarse,fine) if ok else None
        resolved=resolved + int(ok and conv(d) and coarse["max_ledger"]<=5e-8 and fine["max_ledger"]<=5e-8 and coarse["rejected"]==0 and fine["rejected"]==0)
        cases_out[cid]={"coarse":coarse,"fine":fine,"delta":d}
    allr[arm]=cases_out
    summary.append({"arm":arm,"maxit":arms[arm],"complete_pairs":complete,"resolved_pairs":resolved})
print("F_PE_BOFEK01_P1R_RESULTS="+json.dumps(allr,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK01_P1R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK01_P1R=PASS")
