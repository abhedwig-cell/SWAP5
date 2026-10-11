#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]; cases=list(bank["screening_cases"])
candidates=[("RH_ONLY",x) for x in (0.025,0.05,0.10,0.20,0.40)]+[("RH_SURF",x) for x in (0.025,0.05,0.10,0.20,0.40)]

def run(cid,mode,target):
    mid,rid=cid.split("/"); m=materials[mid]; r=regimes[rid]
    dtmin=base["dtmin_day"]; dtmax=4.0*base["dtmax_day"]; dt0=math.sqrt(base["dtmin_day"]*base["dtmax_day"])
    if mode=="REFERENCE": dtmax=base["dtmax_day"]
    cmd=[str(exe),cid,f"{mode}_{target}",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"]),mode,str(target)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"mode":mode,"target":target,"ok":False,"stdout":cp.stdout[-500:],"stderr":cp.stderr[-500:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line: return {"case":cid,"mode":mode,"target":target,"ok":False,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"mode":mode,"target":target,"ok":True}
    out.update({k.lower():int(d[k]) for k in ints}); out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def gate(c,q):
    if not c["ok"] or not q["ok"]: return False
    rd=abs(c["cum_runoff"]-q["cum_runoff"])
    runoff_ok=rd<=0.01 if abs(q["cum_runoff"])<1 else rd<=0.01*abs(q["cum_runoff"])
    sd=abs(c["storage"]-q["storage"])
    hd=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
    pd=abs(c["pond"]-q["pond"])
    return runoff_ok and sd<=max(0.01,0.005*abs(q["storage"])) and hd<=2.0 and pd<=0.02 and c["max_ledger"]<=5e-8 and c["rejected"]<=max(2*q["rejected"],math.ceil(0.25*c["attempts"]))

refs={cid:run(cid,"REFERENCE",0.1) for cid in cases}
rows=[]; summary=[]
for mode,target in candidates:
    reductions=[]; passed=0; wet_ok=True
    for cid in cases:
        c=run(cid,mode,target); q=refs[cid]; p=gate(c,q)
        c["pass"]=p; rows.append(c)
        if p:
            passed+=1; reductions.append(1-c["work_index"]/q["work_index"])
        if ("/WET" in cid or "/POND" in cid) and not p: wet_ok=False
    med=statistics.median(reductions) if reductions else None
    summary.append({"mode":mode,"target":target,"pass":passed,"wetpond_ok":wet_ok,
                    "median_work_reduction":med,"advance":bool(passed>=15 and wet_ok and med is not None and med>=0.15)})
print("F_PE_STATESTEP02_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_STATESTEP02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_STATESTEP02=PASS")
