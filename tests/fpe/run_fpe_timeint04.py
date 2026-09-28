#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
cases=list(bank["screening_cases"])
arms={"A70":0.70,"A80":0.80,"A90":0.90}

def run(cid,mode,safety):
    mid,rid=cid.split("/"); m=materials[mid]; r=regimes[rid]
    cmd=[str(exe),cid,mode,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),str(safety)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT04|")),None)
    if line is None:
        return {"case":cid,"mode":mode,"ok":False,"stderr":cp.stderr[-1000:],"stdout":cp.stdout[-1000:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","SOLVER_REJECTED","TEMPORAL_REJECTED","WORK"]
    out={"case":cid,"mode":mode,"ok":d.get("OK")=="1"}
    out.update({k.lower():int(d[k]) for k in ints})
    if out["ok"]:
        for k in ["RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]:
            out[k.lower()]=float(d[k])
    return out

refs={cid:run(cid,"REFERENCE",0.8) for cid in cases}
rows=[]; summary=[]
for name,safety in arms.items():
    passed=0; wet_ok=True; reductions=[]; rejects=[]; temporal=0; reasons={}
    for cid in cases:
        c=run(cid,name,safety); q=refs[cid]
        why="PASS"; ok=c["ok"] and q["ok"]
        if not ok:
            why="FAIL"
        else:
            rd=abs(c["runoff"]-q["runoff"])
            runoff_ok=rd<=0.01 if abs(q["runoff"])<1.0 else rd<=0.01*abs(q["runoff"])
            sd=abs(c["storage"]-q["storage"])
            hd=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
            pd=abs(c["pond"]-q["pond"])
            retry_frac=c["rejected"]/c["attempts"] if c["attempts"] else 1.0
            if c["max_ledger"]>5e-8: ok=False; why="LEDGER"
            elif not runoff_ok: ok=False; why="RUNOFF"
            elif sd>max(0.01,0.005*abs(q["storage"])): ok=False; why="STORAGE"
            elif pd>0.02: ok=False; why="POND"
            elif hd>2.0: ok=False; why="HEAD"
            elif retry_frac>0.50: ok=False; why="RETRY"
        c["pc1_pass"]=ok;c["pc1_reason"]=why;rows.append(c);reasons[why]=reasons.get(why,0)+1
        if ok:
            passed+=1
            reductions.append(1-c["work"]/q["work"] if q["work"] else 0.0)
        if c.get("attempts",0): rejects.append(c["rejected"]/c["attempts"])
        temporal+=c.get("temporal_rejected",0)
        if ("/WET" in cid or "/POND" in cid) and not ok: wet_ok=False
    med=statistics.median(reductions) if reductions else None
    summary.append({"policy":name,"safety":safety,"pass":passed,"wetpond_ok":wet_ok,
                    "median_work_reduction":med,
                    "median_reject_fraction":statistics.median(rejects) if rejects else None,
                    "temporal_rejections":temporal,"reasons":reasons,
                    "advance":bool(passed>=15 and wet_ok and med is not None and med>=0.15 and
                                   all(x<=0.50 for x in rejects))})
print("F_PE_TIMEINT04_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04_REFERENCE="+json.dumps(list(refs.values()),separators=(",",":"),sort_keys=True))
if not all(x["ok"] for x in refs.values()): raise SystemExit("Reference baseline incomplete")
print("F_PE_TIMEINT04=PASS")
