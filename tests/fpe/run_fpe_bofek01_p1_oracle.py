#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["screening_cases"])

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

def policy_cfg(pid):
    p=candidates[pid]
    dtmin=base["dtmin_day"]
    dtmax=base["dtmax_day"]*p.get("dtmax",1.0)
    mode=p.get("dt0","geom")
    if mode=="halfmax": dt0=0.5*dtmax
    elif mode=="max": dt0=dtmax
    else: dt0=math.sqrt(dtmin*dtmax)
    return dict(dtmin=dtmin,dtmax=dtmax,dt0=dt0,
                numbit=base["numbit_crit"],maxit=base["maxit"],
                maxback=base["max_backtracking"],inc=base["fact_inc"],
                dec=base["fact_dec"],fail=base["fact_fail_divisor"],
                headtol=base["head_abs_tol"]*p.get("headmult",1.0))

def fixed_cfg(dt):
    return dict(dtmin=dt,dtmax=dt,dt0=dt,
                numbit=base["numbit_crit"],maxit=base["maxit"],
                maxback=base["max_backtracking"],inc=base["fact_inc"],
                dec=base["fact_dec"],fail=base["fact_fail_divisor"],
                headtol=base["head_abs_tol"])

def run(cid,pid,cfg):
    m,r=decode(cid)
    cmd=[str(exe),cid,pid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(cfg["dtmin"]),str(cfg["dtmax"]),str(cfg["dt0"]),str(cfg["numbit"]),str(cfg["maxit"]),
         str(cfg["maxback"]),str(cfg["inc"]),str(cfg["dec"]),str(cfg["fail"]),str(cfg["headtol"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"policy":pid,"ok":False,"stderr":cp.stderr[-2000:],"stdout":cp.stdout[-2000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line:
        return {"case":cid,"policy":pid,"ok":False,"stdout":cp.stdout[-2000:],"stderr":"missing result"}
    d={}
    for field in line.split("|")[1:]:
        k,v=field.split("=",1); d[k]=v
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"policy":pid,"ok":True}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def phys_delta(a,b):
    return {
      "runoff":abs(a["cum_runoff"]-b["cum_runoff"]),
      "pond":abs(a["pond"]-b["pond"]),
      "storage":abs(a["storage"]-b["storage"]),
      "top_h":abs(a["top_h"]-b["top_h"]),
      "mid_h":abs(a["mid_h"]-b["mid_h"]),
      "bottom_h":abs(a["bottom_h"]-b["bottom_h"]),
    }

def within(d):
    return (d["runoff"]<=1e-4 and d["pond"]<=1e-4 and d["storage"]<=1e-4 and
            d["top_h"]<=1e-3 and d["mid_h"]<=1e-3 and d["bottom_h"]<=1e-3)

oracles={}
results=[]
for cid in cases:
    coarse=run(cid,"ORACLE_0P0005",fixed_cfg(0.0005))
    fine=run(cid,"ORACLE_0P00025",fixed_cfg(0.00025))
    conv=False; delta=None
    if coarse["ok"] and fine["ok"]:
        delta=phys_delta(coarse,fine)
        conv=(within(delta) and coarse["max_ledger"]<=5e-8 and fine["max_ledger"]<=5e-8 and
              coarse["rejected"]==0 and fine["rejected"]==0)
    oracles[cid]={"coarse":coarse,"fine":fine,"delta":delta,"converged":conv}
    if not conv:
        continue
    for pid in candidates:
        r=run(cid,pid,policy_cfg(pid))
        if r["ok"]:
            d=phys_delta(r,fine)
            gate=(within(d) and r["max_ledger"]<=5e-8 and
                  r["rejected"]<=max(2*run(cid,"REF_RETRY_BASE",policy_cfg("REF"))["rejected"],
                                     math.ceil(0.25*r["attempts"])))
            r["oracle_delta"]=d
            r["oracle_pass"]=gate
        else:
            r["oracle_pass"]=False
        results.append(r)

ref_by_case={r["case"]:r for r in results if r["policy"]=="REF" and r["ok"]}
summary=[]
for pid in candidates:
    rows=[r for r in results if r["policy"]==pid]
    passed=[r for r in rows if r.get("oracle_pass")]
    reductions=[]
    for r in passed:
        q=ref_by_case.get(r["case"])
        if q and q["work_index"]:
            reductions.append(1-r["work_index"]/q["work_index"])
    summary.append({
      "policy":pid,
      "oracle_converged_cases":len(rows),
      "pass":len(passed),
      "median_work_reduction":statistics.median(reductions) if reductions else None,
      "advance":len(rows)==len(cases) and len(passed)==len(cases) and bool(reductions) and statistics.median(reductions)>=0.08
    })

print("F_PE_BOFEK01_P1_ORACLES="+json.dumps(oracles,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK01_P1_RESULTS="+json.dumps(results,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK01_P1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
nconv=sum(1 for x in oracles.values() if x["converged"])
print(f"F_PE_BOFEK01_P1_ORACLE_CONVERGED={nconv}/{len(cases)}")
print("F_PE_BOFEK01_P1=PASS")
