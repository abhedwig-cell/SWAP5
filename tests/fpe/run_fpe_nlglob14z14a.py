#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
fixtures=[("HEAD",6.25e-5),("RUNOFF",1.25e-4),("RUNOFF",6.25e-5)]
horizon=300.0; dtop=10.; pmax=.05; rsro=.05
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0:return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def forcing(route):
    h=-5.; p=.025 if route=="HEAD" else .1
    q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
    rain=-q if route=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain
rows=[]
for route,dt in fixtures:
    h,p,rain=forcing(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h),str(p),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    lines=cp.stdout.splitlines()
    fail=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z14A_FAILURE|")]
    states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    events=[]
    for i in range(0,len(states),16):
        xs=states[i:i+16]
        if len(xs)!=16: continue
        xs=sorted(xs,key=lambda z:int(z["NODE"]))
        sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
        events.append({"step":int(xs[0]["STEP"]),"time":int(xs[0]["STEP"])*dt,"sat":sat})
    target=None
    for a,b in zip(events[:-1],events[1:]):
        if a["sat"]==list(range(12,17)) and b["sat"]==list(range(13,17)): target=b; break
    failure=fail[0] if fail else None
    terminal=res["TERMINAL_REASON"] if res else None
    step=int(res["TRANSITION_STEP"]) if res else None
    ma=abs(float(res["MAX_LEDGER"])) if res else math.inf; cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
    finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
    mass=ma<=5e-8 and cu<=5e-8
    retry=bool(failure and int(failure["RETRY"])==1)
    status=int(failure["STATUS"]) if failure else (int(res["SOLVER_STATUS"]) if res else None)
    if target is not None: cls="NLGLOB14Z14A_EVENT_REACHED_BEFORE_FAILURE"
    elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and retry and finite and mass: cls="QUALIFIED_Z14A_PRE_EVENT_RETRY_ATTRIBUTION"
    elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and not retry and finite and mass: cls="NLGLOB14Z14A_HARD_PRE_EVENT_SOLVE_FAILURE"
    else: cls="NLGLOB14Z14A_STATE_OR_MASS_INCONSISTENT"
    rows.append({"route":route,"dt":dt,"classification":cls,"terminal_reason":terminal,"solver_status":status,"retry_advised":retry,"failure_step":step,"failure_time":step*dt if step else None,"failure_sat_count":int(failure["SAT_COUNT"]) if failure else None,"last_event":events[-1] if events else None,"event_time":target["time"] if target else None,"finite":finite,"mass_ok":mass,"max_ledger":ma,"cum_ledger":cu,"process_ok":cp.returncode==0})
agg="QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION" if all(x["classification"]=="QUALIFIED_Z14A_PRE_EVENT_RETRY_ATTRIBUTION" for x in rows) else "NLGLOB14Z14A_MIXED_ATTRIBUTION"
print("F_PE_NLGLOB14Z14A_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z14A_SUMMARY="+json.dumps({"classification":agg,"case_count":len(rows),"retry_cases":sum(x["retry_advised"] for x in rows)},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z14A=PASS")
