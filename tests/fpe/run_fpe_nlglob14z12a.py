#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dt=6.25e-5; horizon=140.0; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

h=-5.; p=.1
q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
rain=-q+(p-pmax)/rsro

cp=subprocess.run([str(exe),"O05","TG","RUNOFF",str(m["theta_r"]),str(m["theta_s"]),
    str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h),str(p),
    str(rain),str(dt),str(horizon)],text=True,capture_output=True)
lines=cp.stdout.splitlines()
fail=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z12A_FAILURE|")]
states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

events=[]
for i in range(0,len(states),16):
    xs=states[i:i+16]
    if len(xs)!=16: continue
    xs=sorted(xs,key=lambda z:int(z["NODE"]))
    sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
    events.append({"step":int(xs[0]["STEP"]),"time":int(xs[0]["STEP"])*dt,"sat":sat})

failure=fail[0] if fail else None
target=None
for a,b in zip(events[:-1],events[1:]):
    if a["sat"]==list(range(11,17)) and b["sat"]==list(range(12,17)):
        target=b; break

maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
mass_ok=maxledger<=5e-8 and cumledger<=5e-8
terminal=res["TERMINAL_REASON"] if res else None
transition_step=int(res["TRANSITION_STEP"]) if res else None
failure_time=(transition_step*dt if transition_step and terminal!="COMPLETE_SAME_ROUTE" else None)
last_event=events[-1] if events else None
failure_sat_count=int(failure["SAT_COUNT"]) if failure else None
retry=bool(failure and int(failure["RETRY"])==1)
status=int(failure["STATUS"]) if failure else (int(res["SOLVER_STATUS"]) if res else None)

if target is not None:
    cls="NLGLOB14Z12A_EVENT_REACHED_BEFORE_FAILURE"
elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and retry and failure_sat_count==6 and finite and mass_ok:
    cls="QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION"
elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and not retry and finite and mass_ok:
    cls="NLGLOB14Z12A_HARD_PRE_EVENT_SOLVE_FAILURE"
else:
    cls="NLGLOB14Z12A_STATE_OR_MASS_INCONSISTENT"

summary={"classification":cls,"process_ok":cp.returncode==0,"terminal_reason":terminal,
         "solver_status":status,"retry_advised":retry,"failure_step":transition_step,
         "failure_time":failure_time,"failure_sat_count":failure_sat_count,
         "last_event":last_event,"event_time":target["time"] if target else None,
         "finite":finite,"mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger}
print("F_PE_NLGLOB14Z12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z12A=PASS")
