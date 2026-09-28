#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.005,0.00125]
maxits=[8,16,32]

rows=[]
for mid,rain in cases:
    m=materials[mid]
    for dt in dts:
        for maxit in maxits:
            cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                 str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"1","1",str(maxit)]
            cp=subprocess.run(cmd,text=True,capture_output=True)
            row={"material":mid,"rain":rain,"dt":dt,"maxit":maxit,"complete":cp.returncode==0}
            if cp.returncode==0:
                line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT02_RESULT|")),None)
                row["result"]=line
            else:
                line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT02_FAILURE|")),None)
                row["failure"]=line
                row["stdout"]=cp.stdout[-1000:]
                row["stderr"]=cp.stderr[-1000:]
            rows.append(row)

by_maxit=[]
for maxit in maxits:
    xs=[x for x in rows if x["maxit"]==maxit]
    by_maxit.append({"maxit":maxit,"complete":sum(x["complete"] for x in xs),"runs":len(xs)})
summary={"by_maxit":by_maxit,
         "complete_at_32":sum(x["complete"] for x in rows if x["maxit"]==32),
         "classification":"SWKIMPL1_PROVIDER_ROUTE_STRUCTURAL_BLOCKER" if not any(x["complete"] for x in rows if x["maxit"]==32) else "NONLINEAR_EFFORT_SENSITIVE"}

print("F_PE_TIMEINT02A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT02A=PASS")
