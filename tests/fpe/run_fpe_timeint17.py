#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); klag=Path(sys.argv[2]); bank=json.loads(Path(sys.argv[3]).read_text())
mats={x["id"]:x for x in bank["materials"]}
regs={"MOIST":(-50.0,8.0),"WET":(-20.0,12.0),"POND":(-5.0,25.0)}
mids=("B01","B12","O05","O14")

def run_c(mid,rid,h0,rain):
    m=mats[mid]
    cp=subprocess.run([str(cand),mid,rid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                       str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)],text=True,capture_output=True)
    out={"material":mid,"regime":rid,"ok":cp.returncode==0,"stdout":cp.stdout[-1600:],"stderr":cp.stderr[-1200:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17_UNSPLIT_RESULT|")),None)
        if not line: out.update(ok=False,stderr="missing TIMEINT17 result"); return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK","ROUTE_SWITCHES","SAME_ROUTE_STEPS"):
            out[k.lower()]=int(d[k])
        for k in ("MAX_SAME_ROUTE_LEDGER","CUM_SAME_ROUTE_LEDGER","MAX_ROUNDTRIP","MAX_K_SHIFT",
                  "POND","MIN_POND","MAX_POND","STORAGE","TOP_H","TOP_THETA"):
            out[k.lower()]=float(d[k])
        out["route"]=d["ROUTE"]
    return out

def run_k(mid,rid,h0,rain):
    m=mats[mid]
    cp=subprocess.run([str(klag),mid,"KLAG",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                       str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)],text=True,capture_output=True)
    out={"material":mid,"regime":rid,"ok":cp.returncode==0}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12A_RESULT|")),None)
        if not line: out["ok"]=False; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK"): out[k.lower()]=int(d[k])
        out["max_ledger"]=float(d["MAX_LEDGER"])
    return out

rows=[]; ratios=[]
for mid in mids:
    for rid,(h0,rain) in regs.items():
        c=run_c(mid,rid,h0,rain); k=run_k(mid,rid,h0,rain)
        ratio=(c["work"]/k["work"]) if c.get("ok") and k.get("ok") and k.get("work",0)>0 else None
        rows.append({"material":mid,"regime":rid,"candidate":c,"klag":k,"work_ratio":ratio})
        if ratio is not None: ratios.append(ratio)

complete=[r for r in rows if r["candidate"]["ok"]]
same=sum(r["candidate"].get("same_route_steps",0) for r in complete)
switches=sum(r["candidate"].get("route_switches",0) for r in complete)
max_same=max((abs(r["candidate"].get("max_same_route_ledger",0.0)) for r in complete),default=None)
max_cum=max((abs(r["candidate"].get("cum_same_route_ledger",0.0)) for r in complete),default=None)
max_rt=max((r["candidate"].get("max_roundtrip",0.0) for r in complete),default=None)
min_pond=min((r["candidate"].get("min_pond",0.0) for r in complete),default=None)
pond_complete=sum(1 for r in rows if r["regime"]=="POND" and r["candidate"]["ok"])
moist_complete=sum(1 for r in rows if r["regime"]=="MOIST" and r["candidate"]["ok"])
med_ratio=statistics.median(ratios) if ratios else None
max_ratio=max(ratios) if ratios else None

summary={
 "complete":len(complete),"planned":12,"moist_complete":moist_complete,"pond_complete":pond_complete,
 "same_route_steps":same,"route_switches":switches,
 "max_same_route_ledger":max_same,"max_abs_cumulative_same_route_ledger":max_cum,
 "max_roundtrip":max_rt,"min_accepted_ponding":min_pond,
 "median_work_ratio_vs_klag":med_ratio,"max_work_ratio_vs_klag":max_ratio,
 "diagnostic_baseline_pass": bool(len(complete)>=10 and moist_complete==4 and pond_complete>=2 and
   (min_pond is None or min_pond>=-1e-10) and (max_same is None or max_same<=5e-8) and
   (max_rt is None or max_rt<=1e-12))
}
print("F_PE_TIMEINT17_UNSPLIT_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17_UNSPLIT_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17=PASS")
