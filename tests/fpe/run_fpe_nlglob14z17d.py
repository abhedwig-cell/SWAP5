#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
route="RUNOFF"; dt=6.25e-5; horizon=360.0; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0:return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

h=-5.; p=.1
q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
rain=-q+(p-pmax)/rsro
cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
  str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h),str(p),
  str(rain),str(dt),str(horizon)],text=True,capture_output=True)

lines=cp.stdout.splitlines()
nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_NOMINAL_RETRY|")]
rollback=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_ROLLBACK|")]
halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_HALF|")]
recurrent=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_RECURRENT_RETRY|")]
states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

events=[]; bad=False
for i in range(0,len(states),16):
    xs=states[i:i+16]
    if len(xs)!=16: bad=True; continue
    xs=sorted(xs,key=lambda z:int(z["NODE"]))
    sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
    if any((int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1) for x in xs): bad=True
    if sat and sat!=list(range(min(sat),17)): bad=True
    events.append({"step":int(xs[0]["STEP"]),"sat":sat})

first_ok=(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and
          math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
rb_ok=(len(rollback)==1 and all(abs(float(rollback[0][k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")))
half_ok=(len(halves)==2 and all(int(x["ELIGIBLE"])==1 and int(x["RETRY"])==0 for x in halves))
second_ok=(len(recurrent)==1 and int(recurrent[0]["RETRY"])==1)
second_step=int(recurrent[0]["STEP"]) if second_ok else None
second_time=second_step*dt if second_step is not None else None
last_tail=events[-1]["sat"] if events else None
ma=abs(float(res["MAX_LEDGER"])) if res else math.inf
cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
mass_ok=ma<=5e-8 and cu<=5e-8
finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
target_seen=any(x["sat"]==list(range(14,17)) for x in events)

if first_ok and rb_ok and half_ok and second_ok and not target_seen and last_tail==list(range(13,17)) and mass_ok and finite and not bad:
    cls="QUALIFIED_Z17D_SECOND_RETRY_ATTRIBUTION"
elif target_seen:
    cls="Z17D_EVENT_REACHED_BEFORE_SECOND_RETRY"
elif second_ok:
    cls="Z17D_SECOND_RETRY_STATE_OR_MASS_INCONSISTENT"
else:
    cls="Z17D_HARD_SECOND_SOLVE_FAILURE"

record={"classification":cls,"route":route,"dt":dt,"horizon":horizon,
        "process_ok":cp.returncode==0,"first_retry_ok":first_ok,"rollback_ok":rb_ok,
        "half_ok":half_ok,"second_retry_count":len(recurrent),"second_retry_step":second_step,
        "second_retry_time":second_time,"second_solver_status":int(recurrent[0]["SOLVER_STATUS"]) if second_ok else None,
        "second_terminal":recurrent[0]["TERMINAL"] if second_ok else None,
        "accepted_tail_at_second_retry":last_tail,"target_seen":target_seen,
        "finite":finite,"mass_ok":mass_ok,"state_bad":bad,"max_ledger":ma,"cum_ledger":cu}
print("F_PE_NLGLOB14Z17D_RECORDS="+json.dumps([record],separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17D_SUMMARY="+json.dumps({"classification":cls,"case_count":1},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17D=PASS")
