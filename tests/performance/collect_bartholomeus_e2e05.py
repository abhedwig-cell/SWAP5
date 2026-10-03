#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}; regimes={x["id"]:x for x in bank["regimes"]}; b=bank["baseline_policy"]
def cfg():
 dtmin=b["dtmin_day"];dtmax=b["dtmax_day"];dt0=math.sqrt(dtmin*dtmax)
 return dtmin,dtmax,dt0
rows=[]
for cid in bank["screening_cases"]:
 m_id,r_id=cid.split("/");m=materials[m_id];r=regimes[r_id];dtmin,dtmax,dt0=cfg()
 cmd=[str(exe),cid,"REF",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),
      str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),str(dtmin),str(dtmax),str(dt0),str(b["numbit_crit"]),
      str(b["maxit"]),str(b["max_backtracking"]),str(b["fact_inc"]),str(b["fact_dec"]),str(b["fact_fail_divisor"]),str(b["head_abs_tol"])]
 cp=subprocess.run(cmd,text=True,capture_output=True)
 if cp.returncode: raise SystemExit(f"{cid} failed\n{cp.stdout}\n{cp.stderr}")
 first=next((x for x in cp.stdout.splitlines() if x.startswith("E2E05_FIRST_STATE|")),None)
 line=next((x for x in cp.stdout.splitlines() if x.startswith("E2E05_GATE_SUMMARY|")),None)
 if not line: raise SystemExit(f"{cid}: missing gate summary")
 d={}
 for field in line.split("|")[1:]:
  k,v=field.split("=",1);d[k]=v
 fd={}
 if first:
  for field in first.split("|")[1:]:
   k,v=field.split("=",1);fd[k]=v
 rows.append({"case":cid,"regime":r_id,"material":m_id,"total":int(d["TOTAL"]),"hits":int(d["HITS"]),"fraction":float(d["FRACTION"]),
              "h1":float(fd["H1"]) if fd else None,"theta1":float(fd["THETA1"]) if fd else None,"theta_s":float(fd["TS"]) if fd else None,"n":float(fd["N"]) if fd else None})
print("E2E05_SCREENING="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("E2E05_SCREENING_TOTAL="+str(sum(x["total"] for x in rows)))
print("E2E05_SCREENING_HITS="+str(sum(x["hits"] for x in rows)))
print("E2E05_SCREENING_FRACTION="+str(sum(x["hits"] for x in rows)/sum(x["total"] for x in rows)))
print("PPA_WU05C3A_E2E05_SCREENING=PASS")
