#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path

exe32,exe64,bank_path=sys.argv[1:4]
bank=json.loads(Path(bank_path).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("O14_N64_T49",exe64,"O14",49),
 ("B12_N64_T49",exe64,"B12",49),
 ("O05_N32_T25",exe32,"O05",25),
]
rows=[]
invalid=False
for cid,exe,mid,tail in cases:
    m=mats[mid]
    cmd=[exe,cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(tail)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr); invalid=True; break
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z43A_CASE|")),None)
    if line is None:
        invalid=True; break
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    rows.append({
      "case":cid,"complete":int(d["COMPLETE"])==1,"fail_step":int(d["FAIL_STEP"]),
      "last_accepted":int(d["LAST_ACCEPTED"]),"status":int(d["STATUS"]),
      "retry":int(d["RETRY"]),"nonlinear_iterations":int(d["NL"]),
      "jacobian_builds":int(d["JAC"]),"linear_solves":int(d["LINEAR"]),
      "backtracking_attempts":int(d["BACKTRACK"]),"internal_retries":int(d["INTERNAL_RETRIES"]),
      "route":d["ROUTE"],"max_ledger":float(d["MAX_LEDGER"]),"tail":int(d["TAIL"])
    })

if invalid:
    agg="Z43A_REFERENCE_EXECUTION_INVALID"
elif all(r["complete"] for r in rows):
    agg="QUALIFIED_Z43A_REFERENCE_TRAJECTORIES_SOLVABLE"
else:
    agg="QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED"
print("F_PE_NLGLOB14Z43A_RESULT="+json.dumps({"aggregate":agg,"rows":rows},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z43A=PASS")
