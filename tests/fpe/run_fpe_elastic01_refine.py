#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

ref_exe=Path(sys.argv[1]); elastic_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=["B01/WET","B01/POND","B12/MOIST","B12/WET","O05/WET","O05/POND"]
coeffs=[2e-7,5e-7,7.5e-7,1e-6,1.5e-6,2e-6,5e-6]

def args(cid,label):
 m,r=cid.split("/"); m=materials[m]; r=regimes[r]
 dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]; dt0=math.sqrt(dtmin*dtmax)
 return [cid,label,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),
 str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),
 str(base["maxit"]),str(base["max_backtracking"]),str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),
 str(base["head_abs_tol"])]

def parse(cp,prefix,cid,label,ss=None):
 if cp.returncode:
  return {"case":cid,"candidate":label,"ss":ss,"ok":False,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
 line=next(x for x in cp.stdout.splitlines() if x.startswith(prefix))
 d={}
 for f in line[len(prefix):].split("|"):
  if f and "=" in f:
   k,v=f.split("=",1); d[k]=v
 out={"case":cid,"candidate":label,"ss":ss,"ok":True}
 for k in ["ATTEMPTS","ACCEPTED","REJECTED","NL","BACK","JAC","LIN"]: out[k.lower()]=int(d[k])
 for k in ["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]: out[k.lower()]=float(d[k])
 out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
 return out

rows=[]
for cid in cases:
 cp=subprocess.run([str(ref_exe),*args(cid,"REF")],text=True,capture_output=True)
 rows.append(parse(cp,"F_PE_BOFEK01_RESULT|",cid,"REF"))
 for ss in coeffs:
  label="E"+("{:.2e}".format(ss)).replace(".","P").replace("+","")
  cp=subprocess.run([str(elastic_exe),*args(cid,label),str(ss)],text=True,capture_output=True)
  rows.append(parse(cp,"F_PE_ELASTIC01_RESULT|",cid,label,ss))

refs={x["case"]:x for x in rows if x["candidate"]=="REF" and x["ok"]}
summary=[]
for cid in cases:
 q=refs[cid]
 for x in [r for r in rows if r["case"]==cid and r["candidate"]!="REF"]:
  summary.append({"case":cid,"ss":x["ss"],"ok":x["ok"],
    "work_reduction":(1-x["work_index"]/q["work_index"]) if x["ok"] else None,
    "d_runoff":(x["cum_runoff"]-q["cum_runoff"]) if x["ok"] else None,
    "d_pond":(x["pond"]-q["pond"]) if x["ok"] else None,
    "d_top_h":(x["top_h"]-q["top_h"]) if x["ok"] else None,
    "d_bottom_h":(x["bottom_h"]-q["bottom_h"]) if x["ok"] else None,
    "d_storage":(x["storage"]-q["storage"]) if x["ok"] else None})
print("F_PE_ELASTIC01R_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC01R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC01R=PASS")
