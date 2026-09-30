#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
m=next(x for x in bank["materials"] if x["id"]=="O05")
cmd=[str(exe),str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
     str(m["ksat"]),str(m["lambda"])]
cp=subprocess.run(cmd,text=True,capture_output=True)
print(cp.stdout,end="")
if cp.returncode:
    print(cp.stderr,file=sys.stderr)
    print('F_PE_NLGLOB14Z42_RESULT={"aggregate":"Z42_TRAJECTORY_EXECUTION_INVALID"}')
    print("F_PE_NLGLOB14Z42=PASS")
    raise SystemExit

already=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z42_RESULT=")),None)
if already:
    raise SystemExit

line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z42_METRICS|")),None)
if not line:
    print('F_PE_NLGLOB14Z42_RESULT={"aggregate":"Z42_TRAJECTORY_EXECUTION_INVALID"}')
    print("F_PE_NLGLOB14Z42=PASS")
    raise SystemExit

d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
wall=float(d["WALL_RATIO"])
work=float(d["WORK_RATIO"])
red=int(d["REDUCED_COUNT"])
fb=int(d["FALLBACK_COUNT"])
bp=int(d["BYPASS_COUNT"])
total=red+fb+bp
reduced_fraction=red/total if total else 0.0

if wall>1.05:
    agg="Z42_TRAJECTORY_TIMING_REGRESSION"
elif reduced_fraction>=0.95 and wall<0.95 and work<0.90 and (fb+bp)<=0.05*total:
    agg="QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN"
else:
    agg="QUALIFIED_Z42_TRAJECTORY_PHYSICAL_ONLY"

out={
  "aggregate":agg,
  "wall_ratio":wall,
  "work_ratio":work,
  "reduced_fraction":reduced_fraction,
  "fallback_count":fb,
  "bypass_count":bp,
  "mean_active":float(d["MEAN_ACTIVE"]),
  "full_final_tail":int(d["FULL_FINAL_TAIL"]),
  "adaptive_final_tail":int(d["ADAPTIVE_FINAL_TAIL"]),
  "full_events":int(d["FULL_EVENTS"]),
  "adaptive_events":int(d["ADAPTIVE_EVENTS"]),
  "max_hdiff":float(d["MAX_HDIFF"]),
  "max_tdiff":float(d["MAX_TDIFF"]),
  "max_full_ledger":float(d["MAX_FULL_LEDGER"]),
  "max_adaptive_ledger":float(d["MAX_ADAPTIVE_LEDGER"]),
  "origin_leak":float(d["ORIGIN_LEAK"]),
  "request_reallocs":int(d["REQUEST_REALLOCS"]),
  "candidate_reallocs":int(d["CANDIDATE_REALLOCS"]),
  "last_nonreduced_reason":d["LAST_NONREDUCED_REASON"]
}
print("F_PE_NLGLOB14Z42_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z42=PASS")
