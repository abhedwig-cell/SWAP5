#!/usr/bin/env python3
import json, math, statistics, subprocess, sys, time
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
screen=list(bank["screening_cases"])

candidates={
 "REF":{},
 "DTMAX_X2":{"dtmax":2.0},
 "DTMAX_X4":{"dtmax":4.0},
 "DT0_HALFMAX":{"dt0":"halfmax"},
 "DT0_MAX":{"dt0":"max"},
 "HEAD_X10":{"headmult":10.0},
 "HEAD_X100":{"headmult":100.0},
}

def decode(cid):
    m,r=cid.split("/")
    return materials[m],regimes[r]

def cfg(pid):
    p=candidates[pid]
    dtmin=base["dtmin_day"]
    dtmax=base["dtmax_day"]*p.get("dtmax",1.0)
    mode=p.get("dt0","geom")
    if mode=="halfmax": dt0=0.5*dtmax
    elif mode=="max": dt0=dtmax
    else: dt0=math.sqrt(dtmin*dtmax)
    return dict(dtmin=dtmin,dtmax=dtmax,dt0=dt0,
                numbit=base["numbit_crit"],maxit=base["maxit"],maxback=base["max_backtracking"],
                inc=base["fact_inc"],dec=base["fact_dec"],fail=base["fact_fail_divisor"],
                headtol=base["head_abs_tol"]*p.get("headmult",1.0))

def run(cid,pid):
    m,r=decode(cid); p=cfg(pid)
    cmd=[str(exe),cid,pid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(p["dtmin"]),str(p["dtmax"]),str(p["dt0"]),str(p["numbit"]),str(p["maxit"]),str(p["maxback"]),
         str(p["inc"]),str(p["dec"]),str(p["fail"]),str(p["headtol"])]
    t0=time.perf_counter()
    cp=subprocess.run(cmd,text=True,capture_output=True)
    sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":cid,"policy":pid,"ok":False,"seconds":sec,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line:
        return {"case":cid,"policy":pid,"ok":False,"seconds":sec,"stdout":cp.stdout[-1000:],"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"policy":pid,"ok":True,"seconds":sec}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

rows=[]
for cid in screen:
    for pid in candidates:
        rows.append(run(cid,pid))
refs={r["case"]:r for r in rows if r["policy"]=="REF" and r["ok"]}

def abs_or_rel(candidate, reference, abs_limit, rel_limit, rel_threshold):
    diff=abs(candidate-reference)
    if abs(reference)<rel_threshold:
        return diff<=abs_limit,diff
    return diff<=rel_limit*abs(reference),diff

def gate(r):
    if not r["ok"] or r["case"] not in refs:
        return False,"FAIL",{}
    q=refs[r["case"]]
    runoff_ok,dr=abs_or_rel(r["cum_runoff"],q["cum_runoff"],0.01,0.01,1.0)
    storage_diff=abs(r["storage"]-q["storage"])
    storage_ok=storage_diff<=max(0.01,0.005*abs(q["storage"]))
    head_diffs=[abs(r[k]-q[k]) for k in ("top_h","mid_h","bottom_h")]
    pond_diff=abs(r["pond"]-q["pond"])
    metrics={"runoff_diff":dr,"storage_diff":storage_diff,"max_head_diff":max(head_diffs),"pond_diff":pond_diff}
    if r["max_ledger"]>5e-8: return False,"LEDGER",metrics
    if not runoff_ok: return False,"RUNOFF",metrics
    if not storage_ok: return False,"STORAGE",metrics
    if pond_diff>0.02: return False,"POND",metrics
    if max(head_diffs)>2.0: return False,"HEAD",metrics
    if r["rejected"]>max(2*q["rejected"],math.ceil(0.25*r["attempts"])): return False,"RETRY",metrics
    return True,"PASS",metrics

summary=[]
for pid in candidates:
    rs=[r for r in rows if r["policy"]==pid]
    passed=[]; reductions=[]; reasons={}; wet_fail=False
    for r in rs:
        if pid=="REF":
            ok,why,metrics=(r["ok"],"REF",{})
        else:
            ok,why,metrics=gate(r)
        r["pc1_pass"]=ok; r["pc1_reason"]=why; r["pc1_metrics"]=metrics
        reasons[why]=reasons.get(why,0)+1
        if ok and r["case"] in refs:
            q=refs[r["case"]]
            reductions.append(1-r["work_index"]/q["work_index"] if q["work_index"] else 0.0)
            passed.append(r)
        if ("/WET" in r["case"] or "/POND" in r["case"]) and not ok and pid!="REF":
            wet_fail=True
    med=statistics.median(reductions) if reductions else None
    advance=(pid!="REF" and len(passed)>=15 and med is not None and med>=0.15 and not wet_fail)
    summary.append({"policy":pid,"pass":len(passed),"cases":len(rs),"median_work_reduction":med,
                    "wet_or_pond_failure":wet_fail,"advance":advance,"reasons":reasons})

print("F_PE_BOFEK_PRACTICAL01_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK_PRACTICAL01_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if len(refs)!=len(screen):
    raise SystemExit("incomplete Reference baseline")
print("F_PE_BOFEK_PRACTICAL01=PASS")
