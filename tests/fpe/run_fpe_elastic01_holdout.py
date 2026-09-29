#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

ref_exe=Path(sys.argv[1]); elastic_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["holdout_cases"])
ss=1.0e-6

def args(cid,label):
 m,r=cid.split("/"); m=materials[m]; r=regimes[r]
 dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]; dt0=math.sqrt(dtmin*dtmax)
 return [cid,label,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),
 str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),
 str(base["maxit"]),str(base["max_backtracking"]),str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),
 str(base["head_abs_tol"])]

def parse(cp,prefix,cid,label,ssv=None):
 if cp.returncode:
  return {"case":cid,"candidate":label,"ss":ssv,"ok":False,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
 line=next(x for x in cp.stdout.splitlines() if x.startswith(prefix))
 d={}
 for f in line[len(prefix):].split("|"):
  if f and "=" in f:
   k,v=f.split("=",1); d[k]=v
 out={"case":cid,"candidate":label,"ss":ssv,"ok":True}
 for k in ["ATTEMPTS","ACCEPTED","REJECTED","NL","BACK","JAC","LIN"]: out[k.lower()]=int(d[k])
 for k in ["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]: out[k.lower()]=float(d[k])
 out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
 return out

rows=[]
for cid in cases:
 cp=subprocess.run([str(ref_exe),*args(cid,"REF")],text=True,capture_output=True)
 ref=parse(cp,"F_PE_BOFEK01_RESULT|",cid,"REF")
 rows.append(ref)
 cp=subprocess.run([str(elastic_exe),*args(cid,"E6_HOLDOUT"),str(ss)],text=True,capture_output=True)
 cand=parse(cp,"F_PE_ELASTIC01_RESULT|",cid,"E6_HOLDOUT",ss)
 rows.append(cand)

refs={x["case"]:x for x in rows if x["candidate"]=="REF" and x["ok"]}
summary=[]
for x in [r for r in rows if r["candidate"]=="E6_HOLDOUT"]:
 q=refs.get(x["case"])
 summary.append({
  "case":x["case"],"ok":x["ok"],
  "work_reduction":(1-x["work_index"]/q["work_index"]) if x["ok"] and q else None,
  "d_runoff":(x["cum_runoff"]-q["cum_runoff"]) if x["ok"] and q else None,
  "d_pond":(x["pond"]-q["pond"]) if x["ok"] and q else None,
  "d_top_h":(x["top_h"]-q["top_h"]) if x["ok"] and q else None,
  "d_mid_h":(x["mid_h"]-q["mid_h"]) if x["ok"] and q else None,
  "d_bottom_h":(x["bottom_h"]-q["bottom_h"]) if x["ok"] and q else None,
  "d_storage":(x["storage"]-q["storage"]) if x["ok"] and q else None
 })
print("F_PE_ELASTIC01H_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC01H_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC01H=PASS")
