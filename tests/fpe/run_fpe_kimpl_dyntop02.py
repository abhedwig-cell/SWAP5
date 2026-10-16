#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("B01","WET",-20.0,12.0),("B01","POND",-5.0,25.0),
 ("B12","POND",-5.0,25.0),("O05","POND",-5.0,25.0),
 ("O14","MOIST",-50.0,8.0),("O14","WET",-20.0,12.0)
]
arms=(8,12,16,24)
rows=[]
for mid,rid,h0,rain in cases:
    m=mats[mid]
    for maxit in arms:
        cmd=[str(exe),mid,"KIMPL",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(rain),str(maxit)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        row={"material":mid,"regime":rid,"maxit":maxit,"ok":cp.returncode==0,
             "stdout":cp.stdout[-1400:],"stderr":cp.stderr[-800:]}
        if row["ok"]:
            line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_KIMPL_DYNTOP02_RESULT|")),None)
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("MAXIT","STEPS","NL","BACK","JAC","LIN","ALT","WORK"): d[k]=int(d[k])
            for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER"): d[k]=float(d[k])
            row.update(d)
        else:
            fline=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_KIMPL_DYNTOP02_FAILURE|")),None)
            if fline:
                fd={k:v for k,v in (f.split("=",1) for f in fline.split("|")[1:])}
                for k in ("STEP","MAXIT","STATUS","NL","BACK","JAC","LIN"): fd[k]=int(fd[k])
                row["failure"]=fd
        rows.append(row)

case_summary=[]
for mid,rid,_,_ in cases:
    rr=[x for x in rows if x["material"]==mid and x["regime"]==rid]
    first=next((x["maxit"] for x in rr if x["ok"]),None)
    case_summary.append({"material":mid,"regime":rid,"first_complete_maxit":first,
                         "completes_12":any(x["maxit"]==12 and x["ok"] for x in rr),
                         "completes_16":any(x["maxit"]==16 and x["ok"] for x in rr),
                         "completes_24":any(x["maxit"]==24 and x["ok"] for x in rr)})

all16=all(x["first_complete_maxit"] is not None and x["first_complete_maxit"]<=16 for x in case_summary)
any24fail=any(not x["completes_24"] for x in case_summary)
only24=(not all16) and (not any24fail) and all(x["first_complete_maxit"] is not None for x in case_summary)
if all16: classification="ITERATION_CAP_RECOVERABLE"
elif any24fail: classification="NOT_SIMPLE_ITERATION_CAP"
elif only24: classification="RECOVERABLE_BUT_TOO_DEEP_FOR_DEFAULT"
else: classification="MIXED"

summary={"cases":case_summary,"classification":classification,
         "all_complete_by_16":all16,"any_fail_at_24":any24fail}
print("F_PE_KIMPL_DYNTOP02_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_KIMPL_DYNTOP02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_KIMPL_DYNTOP02=PASS")
