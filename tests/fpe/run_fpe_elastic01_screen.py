#!/usr/bin/env python3
import json, math, statistics, subprocess, sys, time
from pathlib import Path

ref_exe=Path(sys.argv[1])
elastic_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["screening_cases"])
candidates=[
    ("ZERO",0.0),
    ("E8",1.0e-8),
    ("E7",1.0e-7),
    ("E6",1.0e-6),
    ("E5",1.0e-5),
]

def decode(cid):
    m,r=cid.split("/")
    return materials[m],regimes[r]

def args_for(cid,label):
    m,r=decode(cid)
    dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]
    dt0=math.sqrt(dtmin*dtmax)
    return [cid,label,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
            str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),str(base["maxit"]),
            str(base["max_backtracking"]),str(base["fact_inc"]),str(base["fact_dec"]),
            str(base["fact_fail_divisor"]),str(base["head_abs_tol"])]

def parse(line,prefix):
    d={}
    for field in line[len(prefix):].split("|"):
        if not field: continue
        k,v=field.split("=",1); d[k]=v
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={k.lower():int(d[k]) for k in ints}
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def run_ref(cid):
    cmd=[str(ref_exe),*args_for(cid,"REF")]
    t0=time.perf_counter(); cp=subprocess.run(cmd,text=True,capture_output=True); sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":cid,"candidate":"REF","ok":False,"seconds":sec,"stdout":cp.stdout[-2000:],"stderr":cp.stderr[-2000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if line is None: raise RuntimeError(cp.stdout)
    out={"case":cid,"candidate":"REF","ok":True,"seconds":sec}
    out.update(parse(line,"F_PE_BOFEK01_RESULT|"))
    return out

def run_candidate(cid,label,ss):
    cmd=[str(elastic_exe),*args_for(cid,label),str(ss)]
    t0=time.perf_counter(); cp=subprocess.run(cmd,text=True,capture_output=True); sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":cid,"candidate":label,"ss":ss,"ok":False,"seconds":sec,"stdout":cp.stdout[-2000:],"stderr":cp.stderr[-2000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_ELASTIC01_RESULT|")),None)
    if line is None: raise RuntimeError(cp.stdout)
    out={"case":cid,"candidate":label,"ss":ss,"ok":True,"seconds":sec}
    out.update(parse(line,"F_PE_ELASTIC01_RESULT|"))
    return out

refs={}
results=[]
for cid in cases:
    q=run_ref(cid); refs[cid]=q; results.append(q)
    if not q["ok"]: continue
    for label,ss in candidates:
        results.append(run_candidate(cid,label,ss))

def physical_gate(r,q):
    if not r["ok"]: return False,"FAIL"
    if r["max_ledger"]>5e-8: return False,"LEDGER"
    runoff_lim=min(1e-4,0.001*abs(q["cum_runoff"])) if abs(q["cum_runoff"])>0.1 else 1e-4
    if abs(r["cum_runoff"]-q["cum_runoff"])>runoff_lim: return False,"RUNOFF"
    if abs(r["pond"]-q["pond"])>1e-4: return False,"POND"
    for key in ("top_h","mid_h","bottom_h"):
        if abs(r[key]-q[key])>1e-3: return False,"HEAD"
    if abs(r["storage"]-q["storage"])>1e-5: return False,"STORAGE"
    if r["rejected"]>max(2*q["rejected"],math.ceil(0.25*r["attempts"])): return False,"RETRY"
    return True,"PASS"

def reproduction_gate(r,q):
    if not r["ok"]: return False,"FAIL"
    for key in ("attempts","accepted","rejected","growths","reductions","nl","back","jac","lin"):
        if r[key]!=q[key]: return False,"COUNTERS"
    for key in ("cum_runoff","top_h","mid_h","bottom_h","pond","storage","max_ledger"):
        if abs(r[key]-q[key])>1e-12: return False,"NUMERIC"
    return True,"PASS"

summaries=[]
for label,ss in candidates:
    rows=[r for r in results if r.get("candidate")==label]
    reasons={}; work=[]; ratios=[]; passed=0
    for r in rows:
        q=refs[r["case"]]
        ok,why=(reproduction_gate(r,q) if label=="E7" else physical_gate(r,q))
        reasons[why]=reasons.get(why,0)+1
        r["gate"]=why
        if ok:
            passed+=1
            if q["work_index"]:
                work.append(1-r["work_index"]/q["work_index"])
            if q["seconds"]:
                ratios.append(r["seconds"]/q["seconds"])
    summaries.append({
        "candidate":label,"ss":ss,"cases":len(rows),"pass":passed,"reasons":reasons,
        "median_work_reduction":statistics.median(work) if work else None,
        "median_wall_ratio":statistics.median(ratios) if ratios else None,
    })

if any(not q["ok"] for q in refs.values()):
    raise SystemExit("F_PE_ELASTIC01 baseline incomplete")
e7=next(x for x in summaries if x["candidate"]=="E7")
if e7["pass"]!=len(cases):
    print("F_PE_ELASTIC01_REPRODUCTION=FAIL")
else:
    print("F_PE_ELASTIC01_REPRODUCTION=PASS")
print("F_PE_ELASTIC01_RESULTS="+json.dumps(results,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC01_SUMMARY="+json.dumps(summaries,separators=(",",":"),sort_keys=True))
if e7["pass"]!=len(cases):
    raise SystemExit("parameterized 1e-7 did not reproduce current Reference")
print("F_PE_ELASTIC01_PHASE_A=PASS")
