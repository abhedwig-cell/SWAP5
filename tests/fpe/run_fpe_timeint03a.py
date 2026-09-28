#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
m=next(x for x in bank["materials"] if x["id"]=="B01")
rows=[]
for maxit in (8,12,16,24):
    cmd=[str(exe),"B01",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),"4.0","0.00125","2","1",str(maxit)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"maxit":maxit,"complete":cp.returncode==0}
    if cp.returncode==0:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_RESULT|")),None)
        row["result"]=line
        if line:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ["TOP_H","MID_H","BOTTOM_H","STORAGE"]:
                row[k.lower()]=float(d[k])
            for k in ["NL","BACK","JAC","LIN"]:
                row[k.lower()]=int(d[k])
            row["work_index"]=row["nl"]+row["back"]+row["jac"]+row["lin"]
    else:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT03_FAILURE|")),None)
        row["failure"]=line
        row["stdout"]=cp.stdout[-1000:]
        row["stderr"]=cp.stderr[-1000:]
    rows.append(row)

first=next((x["maxit"] for x in rows if x["complete"]),None)
if first is None:
    classification="BDF2_NONLINEAR_PATHOLOGY"
elif first<=16:
    classification="NONLINEAR_ITERATION_CAP_SENSITIVITY"
else:
    classification="MATERIAL_NONLINEAR_EFFORT"
summary={"first_completing_maxit":first,"classification":classification,
         "complete_arms":sum(x["complete"] for x in rows)}
print("F_PE_TIMEINT03A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT03A=PASS")
