#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dts=[1.25e-4,6.25e-5]; routes=("HEAD","RUNOFF"); stages=(51.2,102.4)
dtop=10.; pmax=.05; rsro=.05
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(route):
    h=-5.; p=.025 if route=="HEAD" else .1
    q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
    rain=-q if route=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain
def one(route,dt,horizon):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    lines=cp.stdout.splitlines()
    states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    events=[]; bad=False; reverse=False; skipped=False; prev_top=None; late_phase=False
    for i in range(0,len(states),16):
        xs=states[i:i+16]
        if len(xs)!=16:
            bad=True; continue
        xs=sorted(xs,key=lambda x:int(x["NODE"]))
        sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
        if any((int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1) for x in xs): bad=True
        if sat and sat!=list(range(min(sat),17)): bad=True
        vals=[float(x[k]) for x in xs for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
        if not all(math.isfinite(v) for v in vals): bad=True
        top=min(sat) if sat else None
        step=int(xs[0]["STEP"]); t=step*dt
        if prev_top is not None and top is not None and top!=prev_top:
            d=top-prev_top
            if prev_top==9 and top==10:
                late_phase=True
            elif late_phase:
                if d<0: reverse=True
                if d>1: skipped=True
        events.append({"step":step,"time":t,"sat":sat,"top":top})
        prev_top=top
    target=None
    for a,b in zip(events[:-1],events[1:]):
        if a["sat"]==list(range(10,17)) and b["sat"]==list(range(11,17)):
            target={"pre":a,"post":b}; break
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    valid=cp.returncode==0 and complete and not bad and not reverse and not skipped and mass_ok
    return {"route":route,"dt":dt,"horizon":horizon,"valid":valid,"complete":complete,
            "process_ok":cp.returncode==0,"terminal_reason":res.get("TERMINAL_REASON") if res else None,
            "max_ledger":maxledger,"cum_ledger":cumledger,"mass_ok":mass_ok,
            "state_bad":bad,"reverse":reverse,"skipped":skipped,
            "target_time":target["post"]["time"] if target else None,
            "pre_set":target["pre"]["sat"] if target else None,
            "post_set":target["post"]["sat"] if target else None,
            "final_set":events[-1]["sat"] if events else None,
            "event_count":len(events)}
selected={}
for horizon in stages:
    rows=[one(r,dt,horizon) for r in routes for dt in dts]
    for x in rows: selected[(x["route"],x["dt"])]=x
    if all(x["valid"] and x["target_time"] is not None for x in rows): break
rows=[selected[(r,dt)] for r in routes for dt in dts]
coverage=len(rows)==4 and all(x["valid"] for x in rows)
event_all=coverage and all(x["target_time"] is not None for x in rows)
if any(x["state_bad"] or x["reverse"] or x["skipped"] for x in rows):
    agg="NLGLOB14Z9_DEEP_RETREAT_STATE_INCONSISTENT"
elif not coverage:
    agg="BLOCKED_NLGLOB14Z9_CONTROL_EXPOSURE"
elif event_all:
    agg="QUALIFIED_DEEP_LATE_RETREAT_CONTROL_EXPOSURE"
elif not any(x["target_time"] is not None for x in rows):
    agg="NLGLOB14Z9_NO_DEEP_RETREAT_WITHIN_102P4D"
else:
    agg="NLGLOB14Z9_MIXED_DEEP_RETREAT_EXPOSURE"
summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),
         "selected_horizon":max(x["horizon"] for x in rows),
         "event_cases":sum(x["target_time"] is not None for x in rows),
         "max_ledger":max(x["max_ledger"] for x in rows),
         "max_cum_ledger":max(x["cum_ledger"] for x in rows),
         "event_times":[{"route":x["route"],"dt":x["dt"],"time":x["target_time"]} for x in rows]}
print("F_PE_NLGLOB14Z9_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z9_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z9=PASS")
