#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}; b=bank["baseline_policy"]
def cfg():
 dtmin=b["dtmin_day"];dtmax=b["dtmax_day"];dt0=math.sqrt(dtmin*dtmax)
 return dtmin,dtmax,dt0
rows=[]
for scale in [0.001,0.01,0.1,1.0]:
 for cid in bank["screening_cases"]+bank["holdout_cases"]:
  case_set="holdout" if cid in bank["holdout_cases"] else "screening"
  m_id,r_id=cid.split("/");m=materials[m_id];r=regimes[r_id];dtmin,dtmax,dt0=cfg()
  cmd=[str(exe),cid,"REF",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),
      str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),str(dtmin),str(dtmax),str(dt0),str(b["numbit_crit"]),
      str(b["maxit"]),str(b["max_backtracking"]),str(b["fact_inc"]),str(b["fact_dec"]),str(b["fact_fail_divisor"]),str(b["head_abs_tol"]),str(scale)]
  cp=subprocess.run(cmd,text=True,capture_output=True)
  if cp.returncode: raise SystemExit(f"{cid} failed\n{cp.stdout}\n{cp.stderr}")
  first=next((x for x in cp.stdout.splitlines() if x.startswith("E2E05_FIRST_STATE|")),None)
  for diag in (x for x in cp.stdout.splitlines() if x.startswith("E2E05_GATE_DIAG|")):
   print(diag)
  line=next((x for x in cp.stdout.splitlines() if x.startswith("E2E05_GATE_SUMMARY|")),None)
  if not line: raise SystemExit(f"{cid}: missing gate summary")
  d={}
  for field in line.split("|")[1:]:
    k,v=field.split("=",1);d[k]=v
  fd={}
  if first:
   for field in first.split("|")[1:]:
    k,v=field.split("=",1);fd[k]=v
  rows.append({"scale":scale,"case":cid,"set":case_set,"regime":r_id,"material":m_id,"total":int(d["TOTAL"]),"hits":int(d["HITS"]),"fraction":float(d["FRACTION"]),
              "h1":float(fd["H1"]) if fd else None,"theta1":float(fd["THETA1"]) if fd else None,"theta_s":float(fd["TS"]) if fd else None,"n":float(fd["N"]) if fd else None})
print("E2E05_SCREENING="+json.dumps(rows,separators=(",",":"),sort_keys=True))
screen=[x for x in rows if x["set"]=="screening"]; hold=[x for x in rows if x["set"]=="holdout"]
print("E2E05_SCREENING_TOTAL="+str(sum(x["total"] for x in screen)))
print("E2E05_SCREENING_HITS="+str(sum(x["hits"] for x in screen)))
print("E2E05_SCREENING_FRACTION="+str(sum(x["hits"] for x in screen)/sum(x["total"] for x in screen)))
print("E2E05_HOLDOUT_TOTAL="+str(sum(x["total"] for x in hold)))
print("E2E05_HOLDOUT_HITS="+str(sum(x["hits"] for x in hold)))
print("E2E05_HOLDOUT_FRACTION="+str(sum(x["hits"] for x in hold)/sum(x["total"] for x in hold)))
print("PPA_WU05C3A_E2E05_SCREENING=PASS")
