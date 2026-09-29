#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("B01","WET",-20.0,12.0),
 ("B01","POND",-5.0,25.0),
 ("B12","POND",-5.0,25.0),
 ("O05","POND",-5.0,25.0),
 ("O14","MOIST",-50.0,8.0),
 ("O14","WET",-20.0,12.0),
]
arms=(8,12,16,24)

def run(mid,rid,h0,rain,maxit):
    m=mats[mid]
    cmd=[str(exe),mid,"KIMPL",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(rain),str(maxit)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"material":mid,"regime":rid,"maxit":maxit,"ok":cp.returncode==0,
         "stdout_tail":cp.stdout[-1500:],"stderr_tail":cp.stderr[-800:]}
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT12A_RESULT|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("STEPS","MAXIT","NL","BACK","JAC","LIN","ALT","WORK"): d[k]=int(d[k])
            for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER"): d[k]=float(d[k])
            out["result"]=d
        elif line.startswith("F_PE_KIMPL_DYNTOP02_FAILURE|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("MAXIT","STEP","STATUS","NL_TOTAL","BACK_TOTAL","JAC_TOTAL","LIN_TOTAL","ALT_TOTAL"): d[k]=int(d[k])
            out["failure"]=d
    return out

rows=[run(*case,maxit) for case in cases for maxit in arms]

case_summary={}
for mid,rid,_,_ in cases:
    key=f"{mid}/{rid}"
    rs=[r for r in rows if r["material"]==mid and r["regime"]==rid]
    complete=[r["maxit"] for r in rs if r["ok"]]
    case_summary[key]={
        "smallest_completing_maxit":min(complete) if complete else None,
        "complete_arms":complete,
        "failures":{str(r["maxit"]):r.get("failure") for r in rs if not r["ok"]},
    }

all16=all(v["smallest_completing_maxit"] is not None and v["smallest_completing_maxit"]<=16 for v in case_summary.values())
any24fail=any(v["smallest_completing_maxit"] is None for v in case_summary.values())
all_only24=all(v["smallest_completing_maxit"]==24 for v in case_summary.values())
alts_ok=all((not r["ok"]) or r["result"]["ALT"]==0 for r in rows)
ledger_ok=all((not r["ok"]) or r["result"]["MAX_LEDGER"]<=5e-8 for r in rows)

if any24fail:
    classification="NOT_SIMPLE_ITERATION_CAP"
elif all16 and alts_ok and ledger_ok:
    classification="ITERATION_CAP_RECOVERABLE"
elif all_only24:
    classification="RECOVERABLE_BUT_TOO_DEEP_FOR_DEFAULT"
else:
    classification="MIXED_ITERATION_CAP_SENSITIVITY"

summary={"cases":case_summary,"all_complete_by_16":all16,"any_fail_at_24":any24fail,
         "alternative_solver_ok":alts_ok,"ledger_ok":ledger_ok,"classification":classification}

print("F_PE_KIMPL_DYNTOP02_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_KIMPL_DYNTOP02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_KIMPL_DYNTOP02=PASS")
