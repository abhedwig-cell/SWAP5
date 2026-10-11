#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
m=next(x for x in bank["materials"] if x["id"]=="B01")

def run(name,tmode):
    cmd=[str(exe),"B01",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),"4.0","0.00125",str(tmode),"1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    traces=[]
    result=None
    failure=None
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT04_") and "|" in line:
            tag=line.split("|",1)[0]
            d={"tag":tag}
            for field in line.split("|")[1:]:
                if "=" not in field: continue
                k,v=field.split("=",1)
                try:
                    d[k.lower()]=int(v)
                except ValueError:
                    try: d[k.lower()]=float(v)
                    except ValueError: d[k.lower()]=v
            if tag in ("F_PE_TIMEINT04_INIT","F_PE_TIMEINT04_PRE","F_PE_TIMEINT04_DELTA",
                       "F_PE_TIMEINT04_TRIAL","F_PE_TIMEINT04_CHECK"):
                traces.append(d)
            elif tag=="F_PE_TIMEINT04_RESULT":
                result=d
            elif tag=="F_PE_TIMEINT04_FAILURE":
                failure=d
    return {"variant":name,"returncode":cp.returncode,"result":result,"failure":failure,
            "traces":traces,"stdout_tail":cp.stdout[-1500:],"stderr_tail":cp.stderr[-1000:]}

runs=[run("BE_KIMPL",1),run("BDF2_KIMPL",2)]

def summarize(run):
    out={"variant":run["variant"],"complete":run["returncode"]==0,
         "failure":run["failure"],"steps":{}}
    for step in (24,25):
        rows=[x for x in run["traces"] if x.get("step")==step]
        trials=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_TRIAL"]
        pres=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_PRE"]
        checks=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_CHECK"]
        deltas=[x for x in rows if x["tag"]=="F_PE_TIMEINT04_DELTA"]
        out["steps"][str(step)]={
            "records":len(rows),
            "iterations":max([x.get("iter",0) for x in rows] or [0]),
            "trial_count":len(trials),
            "progress_trials":sum(x.get("progress",0)==1 for x in trials),
            "no_progress_trials":sum(x.get("progress",0)==0 for x in trials),
            "first_sumold":pres[0].get("sumold") if pres else None,
            "last_sumnew":checks[-1].get("sumnew") if checks else None,
            "first_finf":pres[0].get("finf") if pres else None,
            "last_finf":checks[-1].get("finf") if checks else None,
            "max_delta":max([x.get("dmax",0.0) for x in deltas] or [0.0]),
            "min_trial_factor":min([x.get("factor",1.0) for x in trials] or [1.0]),
            "final_nonconv":checks[-1].get("nonconv") if checks else None,
        }
    return out

summary=[summarize(x) for x in runs]
print("F_PE_TIMEINT04_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT04_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))

be=next(x for x in runs if x["variant"]=="BE_KIMPL")
bd=next(x for x in runs if x["variant"]=="BDF2_KIMPL")
if be["returncode"]!=0:
    raise SystemExit("BE_KIMPL trace authority unexpectedly failed")
if bd["failure"] is None or bd["failure"].get("step")!=25:
    raise SystemExit("BDF2_KIMPL did not reproduce expected step-25 failure")
if not any(x.get("step")==25 for x in bd["traces"]):
    raise SystemExit("missing BDF2 step-25 trace")
print("F_PE_TIMEINT04=PASS")
