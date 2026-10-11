#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("B01",-20.0,12.0),("O14",-20.0,12.0)]
def run(mid,mode,h0,rain):
    m=mats[mid]
    cmd=[str(exe),mid,mode,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    traces=[]; failure=None
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT04_") and "|" in line:
            tag=line.split("|",1)[0]; d={"tag":tag}
            for f in line.split("|")[1:]:
                if "=" not in f: continue
                k,v=f.split("=",1)
                try: d[k.lower()]=int(v)
                except ValueError:
                    try: d[k.lower()]=float(v)
                    except ValueError: d[k.lower()]=v
            traces.append(d)
        if line.startswith("F_PE_KIMPL_DYNTOP01_FAILURE|"):
            d={}
            for f in line.split("|")[1:]:
                k,v=f.split("=",1)
                try:d[k.lower()]=int(v)
                except ValueError:d[k.lower()]=v
            failure=d
    return {"material":mid,"mode":mode,"returncode":cp.returncode,"failure":failure,
            "traces":traces,"stdout_tail":cp.stdout[-1800:],"stderr_tail":cp.stderr[-800:]}
runs=[]
for mid,h0,rain in cases:
    runs.append(run(mid,"KLAG",h0,rain))
    runs.append(run(mid,"KIMPL",h0,rain))
summary=[]
for r in runs:
    fail_step=r["failure"]["step"] if r["failure"] else None
    selected={}
    if fail_step:
        for st in (fail_step-1,fail_step):
            rows=[x for x in r["traces"] if x.get("step")==st]
            pres=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_PRE"]
            checks=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_CHECK"]
            trials=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_TRIAL"]
            deltas=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_DELTA"]
            selected[str(st)]={
                "iterations":max([x.get("iter",0) for x in rows] or [0]),
                "first_finf":pres[0].get("finf") if pres else None,
                "last_finf":checks[-1].get("finf") if checks else None,
                "last_sumres":checks[-1].get("sumres") if checks else None,
                "max_delta":max([x.get("dmax",0.0) for x in deltas] or [0.0]),
                "min_factor":min([x.get("factor",1.0) for x in trials] or [1.0]),
                "no_progress_trials":sum(x.get("progress",0)==0 for x in trials),
                "last_nonconv":checks[-1].get("nonconv") if checks else None,
            }
    summary.append({"material":r["material"],"mode":r["mode"],"complete":r["returncode"]==0,
                    "failure":r["failure"],"steps":selected})
print("F_PE_KIMPL_DYNTOP01_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_KIMPL_DYNTOP01_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
klag=[r for r in runs if r["mode"]=="KLAG"]
kimpl=[r for r in runs if r["mode"]=="KIMPL"]
if not all(r["returncode"]==0 for r in klag): raise SystemExit("KLAG authority failed")
if not all(r["returncode"]!=0 and r["failure"] for r in kimpl): raise SystemExit("KIMPL failure not reproduced")
print("F_PE_KIMPL_DYNTOP01=PASS")
