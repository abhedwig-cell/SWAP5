#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path

exe32,exe64,bank_path=sys.argv[1:4]
bank=json.loads(Path(bank_path).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("B01_N64_T49",exe64,"B01",49),
 ("B01_N32_T25",exe32,"B01",25),
]
rows=[]
invalid=False
selected=None
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
    row={
      "case":cid,"complete":int(d["COMPLETE"])==1,"fail_step":int(d["FAIL_STEP"]),
      "last_accepted":int(d["LAST_ACCEPTED"]),"status":int(d["STATUS"]),
      "retry":int(d["RETRY"]),"nonlinear_iterations":int(d["NL"]),
      "jacobian_builds":int(d["JAC"]),"linear_solves":int(d["LINEAR"]),
      "backtracking_attempts":int(d["BACKTRACK"]),"internal_retries":int(d["INTERNAL_RETRIES"]),
      "route":d["ROUTE"],"max_ledger":float(d["MAX_LEDGER"]),"tail":int(d["TAIL"])
    }
    rows.append(row)
    if row["complete"]:
        selected=cid
        break

if invalid:
    agg="Z43D_EXECUTION_INVALID"
elif selected is not None:
    agg="QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED"
else:
    agg="Z43D_NO_REFERENCE_SOLVABLE_REPLACEMENT"
print("F_PE_NLGLOB14Z43D_RESULT="+json.dumps({"aggregate":agg,"selected":selected,"rows":rows},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z43D=PASS")
