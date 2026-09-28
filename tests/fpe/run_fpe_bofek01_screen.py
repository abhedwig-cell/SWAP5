#!/usr/bin/env python3
import json, math, statistics, subprocess, sys, time
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]

policies={
"REF":{},
"DTMAX_X0P5":{"dtmax":0.5},
"DTMAX_X2":{"dtmax":2.0},
"DTMAX_X4":{"dtmax":4.0},
"DTMIN_X0P5":{"dtmin":0.5},
"DTMIN_X2":{"dtmin":2.0},
"DT0_MIN":{"dt0":"min"},
"DT0_HALFMAX":{"dt0":"halfmax"},
"DT0_MAX":{"dt0":"max"},
"NUMBIT_2":{"numbit":2},
"NUMBIT_3":{"numbit":3},
"NUMBIT_5":{"numbit":5},
"NUMBIT_6":{"numbit":6},
"INC_1P25":{"inc":1.25},
"INC_1P5":{"inc":1.5},
"INC_3":{"inc":3.0},
"DEC_0P25":{"dec":0.25},
"DEC_0P75":{"dec":0.75},
"FAIL_1P5":{"fail":1.5},
"FAIL_3":{"fail":3.0},
"FAIL_4":{"fail":4.0},
"MAXIT_5":{"maxit":5},
"MAXIT_6":{"maxit":6},
"MAXIT_10":{"maxit":10},
"MAXIT_12":{"maxit":12},
"BACK_2":{"maxback":2},
"BACK_4":{"maxback":4},
"BACK_6":{"maxback":6},
"HEAD_X10":{"headmult":10.0},
"HEAD_X100":{"headmult":100.0},
}
cases=[x for x in bank["screening_cases"]]
def decode(cid):
    m,r=cid.split("/")
    return materials[m],regimes[r]
def cfg(pid):
    p=policies[pid]
    dtmin=base["dtmin_day"]*p.get("dtmin",1.0)
    dtmax=base["dtmax_day"]*p.get("dtmax",1.0)
    mode=p.get("dt0","geom")
    if mode=="min": dt0=dtmin
    elif mode=="halfmax": dt0=0.5*dtmax
    elif mode=="max": dt0=dtmax
    else: dt0=math.sqrt(dtmin*dtmax)
    return (dtmin,dtmax,dt0,p.get("numbit",base["numbit_crit"]),p.get("inc",base["fact_inc"]),
p.get("dec",base["fact_dec"]),p.get("fail",base["fact_fail_divisor"]),
p.get("maxit",base["maxit"]),p.get("maxback",base["max_backtracking"]),
base["head_abs_tol"]*p.get("headmult",1.0))
def run(cid,pid):
    m,r=decode(cid)
    dtmin,dtmax,dt0,numbit,inc,dec,fail,maxit,maxback,headtol=cfg(pid)
    cmd=[str(exe),cid,pid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(dtmin),str(dtmax),str(dt0),str(numbit),str(maxit),str(maxback),
str(inc),str(dec),str(fail),str(headtol)]
    t0=time.perf_counter()
    cp=subprocess.run(cmd,text=True,capture_output=True)
    sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":cid,"policy":pid,"ok":False,"seconds":sec,"stderr":cp.stderr[-2000:],"stdout":cp.stdout[-2000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line: raise RuntimeError(cp.stdout)
    d={}
    for field in line.split("|")[1:]:
        k,v=field.split("=",1); d[k]=v
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"policy":pid,"ok":True,"seconds":sec}
    out.update({k.lower():int(d[k]) for k in ints}); out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

results=[]
for cid in cases:
    ref=run(cid,"REF"); results.append(ref)
    if not ref["ok"]: continue
    for pid in policies:
        if pid=="REF": continue
        results.append(run(cid,pid))

refs={r["case"]:r for r in results if r["policy"]=="REF" and r["ok"]}
def gate(r):
    if not r["ok"] or r["case"] not in refs: return False,"FAIL"
    q=refs[r["case"]]
    if r["max_ledger"]>5e-8: return False,"LEDGER"
    runoff_lim=min(1e-4,0.001*abs(q["cum_runoff"])) if abs(q["cum_runoff"])>0.1 else 1e-4
    if abs(r["cum_runoff"]-q["cum_runoff"])>runoff_lim: return False,"RUNOFF"
    if abs(r["pond"]-q["pond"])>1e-4: return False,"POND"
    if abs(r["top_h"]-q["top_h"])>1e-3: return False,"HEAD"
    if r["rejected"]>max(2*q["rejected"], math.ceil(0.25*r["attempts"])): return False,"RETRY"
    return True,"PASS"
summ=[]
for pid in policies:
    rows=[r for r in results if r["policy"]==pid]
    passed=[]; reductions=[]; ratios=[]; reasons={}
    for r in rows:
        ok,why=(True,"REF") if pid=="REF" and r["ok"] else gate(r)
        reasons[why]=reasons.get(why,0)+1
        if ok and r["case"] in refs:
            passed.append(r)
            q=refs[r["case"]]
            reductions.append(1-r["work_index"]/q["work_index"] if q["work_index"] else 0.0)
            ratios.append(r["seconds"]/q["seconds"] if q["seconds"] else 1.0)
    summ.append({"policy":pid,"cases":len(rows),"pass":len(passed),
                 "median_work_reduction":statistics.median(reductions) if reductions else None,
                 "median_wall_ratio":statistics.median(ratios) if ratios else None,
                 "reasons":reasons})
print("F_PE_BOFEK01_SCREEN_RESULTS="+json.dumps(results,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK01_SCREEN_SUMMARY="+json.dumps(summ,separators=(",",":"),sort_keys=True))
if len(refs)!=len(cases):
    raise SystemExit("baseline incomplete")
print("F_PE_BOFEK01_SCREEN=PASS")
