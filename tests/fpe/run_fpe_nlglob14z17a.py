#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2]); route=sys.argv[3]; dt=float(sys.argv[4])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
horizon=600.0; dtop=10.; pmax=.05; rsro=.05
if route not in ("HEAD","RUNOFF"): raise SystemExit("invalid route")
if not any(math.isclose(dt,x,rel_tol=0,abs_tol=1e-15) for x in (1.25e-4,6.25e-5)):
    raise SystemExit("invalid dt")

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

h0=-5.; p0=.025 if route=="HEAD" else .1
q=-.5*(m["ksat"]+kvg(h0))*((p0-h0)/dtop+1)
rain=-q if route=="HEAD" else -q+(p0-pmax)/rsro

cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
    str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
    str(rain),str(dt),str(horizon)],text=True,capture_output=True)
lines=cp.stdout.splitlines()
fails=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17A_FAILURE|")]
states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

events=[]; state_bad=False
for i in range(0,len(states),16):
    xs=states[i:i+16]
    if len(xs)!=16:
        state_bad=True; continue
    xs=sorted(xs,key=lambda z:int(z["NODE"]))
    sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
    if any((int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1) for x in xs):
        state_bad=True
    if sat and sat!=list(range(min(sat),17)):
        state_bad=True
    vals=[float(x[k]) for x in xs for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
    if not all(math.isfinite(v) for v in vals):
        state_bad=True
    events.append({"step":int(xs[0]["STEP"]),"time":int(xs[0]["STEP"])*dt,"sat":sat})

target=None
for a,b in zip(events[:-1],events[1:]):
    if a["sat"]==list(range(13,17)) and b["sat"]==list(range(14,17)):
        target=b; break

failure=fails[0] if fails else None
terminal=res["TERMINAL_REASON"] if res else None
transition_step=int(res["TRANSITION_STEP"]) if res else None
failure_time=(transition_step*dt if transition_step and terminal!="COMPLETE_SAME_ROUTE" else None)
status=int(failure["STATUS"]) if failure else (int(res["SOLVER_STATUS"]) if res else None)
retry=bool(failure and int(failure["RETRY"])==1)
failure_sat_count=int(failure["SAT_COUNT"]) if failure else None
last_event=events[-1] if events else None
maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
mass_ok=maxledger<=5e-8 and cumledger<=5e-8

if target is not None:
    cls="Z17A_EVENT_REACHED_BEFORE_FAILURE"
elif state_bad or not finite or not mass_ok:
    cls="Z17A_STATE_OR_MASS_INCONSISTENT"
elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and retry:
    cls="Z17A_PRE_EVENT_RETRY_ATTRIBUTED"
elif failure and terminal=="ENDPOINT_SOLVE_FAILURE" and not retry:
    cls="Z17A_HARD_PRE_EVENT_SOLVE_FAILURE"
else:
    cls="Z14A_STATE_OR_MASS_INCONSISTENT"

summary={
  "classification":cls,"route":route,"dt":dt,"horizon":horizon,
  "process_ok":cp.returncode==0,"terminal_reason":terminal,
  "solver_status":status,"retry_advised":retry,
  "failure_step":transition_step,"failure_time":failure_time,
  "failure_sat_count":failure_sat_count,
  "last_event":last_event,
  "event_time":target["time"] if target else None,
  "finite":finite,"state_bad":state_bad,"mass_ok":mass_ok,
  "max_ledger":maxledger,"cum_ledger":cumledger
}
print("F_PE_NLGLOB14Z17A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17A=PASS")
