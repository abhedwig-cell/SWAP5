#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
route="RUNOFF"; dt=6.25e-5; horizon=540.0
dtop=10.; pmax=.05; rsro=.05

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
nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_NOMINAL_RETRY|")]
rollbacks=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_ROLLBACK|")]
halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_HALF|")]
recovered=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_RECOVERED|")]
third=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_THIRD_RETRY|")]
states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

events=[]; bad=False; reverse=False; skipped=False; prev_top=None; late13=False
for i in range(0,len(states),16):
    xs=states[i:i+16]
    if len(xs)!=16:
        bad=True; continue
    xs=sorted(xs,key=lambda z:int(z["NODE"]))
    sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
    if any((int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1) for x in xs): bad=True
    if sat and sat!=list(range(min(sat),17)): bad=True
    vals=[float(x[k]) for x in xs for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
    if not all(math.isfinite(v) for v in vals): bad=True
    top=min(sat) if sat else None
    step=int(xs[0]["STEP"]); t=step*dt
    if prev_top is not None and top is not None and top!=prev_top:
        d=top-prev_top
        if prev_top==12 and top==13:
            late13=True
        elif late13:
            if d<0: reverse=True
            if d>1: skipped=True
    events.append({"step":step,"time":t,"sat":sat})
    prev_top=top

target=None
for a,b in zip(events[:-1],events[1:]):
    if a["sat"]==list(range(13,17)) and b["sat"]==list(range(14,17)) and a["time"]>200.0:
        target={"pre":a,"post":b}; break

nominal_ok=(len(nominal)==2 and [int(x["INDEX"]) for x in nominal]==[1,2] and
            all(int(x["RETRY"])==1 and math.isclose(float(x["DT"]),dt,rel_tol=0,abs_tol=1e-15) for x in nominal))
rollback_ok=(len(rollbacks)==2 and [int(x["INDEX"]) for x in rollbacks]==[1,2] and
             all(all(abs(float(x[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")) for x in rollbacks))
half_ok=(len(halves)==4 and
         sorted((int(x["INDEX"]),int(x["HALF"])) for x in halves)==[(1,1),(1,2),(2,1),(2,2)] and
         all(int(x["ELIGIBLE"])==1 and int(x["RETRY"])==0 and
             math.isclose(float(x["DT"]),0.5*dt,rel_tol=0,abs_tol=1e-15) for x in halves))
recovered_ok=(len(recovered)==2 and [int(x["COUNT"]) for x in recovered]==[1,2])
complete=bool(res and int(res["ELIGIBLE"])==1 and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE")
finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
ma=abs(float(res["MAX_LEDGER"])) if res else math.inf
cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
mass_ok=ma<=5e-8 and cu<=5e-8
event_time=target["post"]["time"] if target else None

if not nominal_ok or not rollback_ok or not half_ok or not recovered_ok or not finite or not mass_ok or bad or reverse or skipped:
    cls="Z17F_TRANSACTION_INCONSISTENT"
elif third and target is None:
    cls="Z17F_THIRD_RETRY_BEFORE_EVENT"
elif third and target is not None:
    cls="Z17F_POST_EVENT_THIRD_RETRY"
elif complete and target is not None:
    cls="QUALIFIED_Z17F_REPAIRED_FINE_RUNOFF_RETREAT_13_TO_14"
elif complete:
    cls="Z17F_EVENT_NOT_REACHED"
else:
    cls="Z17F_THIRD_RETRY_BEFORE_EVENT"

record={"classification":cls,"route":route,"dt":dt,"horizon":horizon,
        "process_ok":cp.returncode==0,"nominal_retry_count":len(nominal),
        "nominal_retry_steps":[int(x["STEP"]) for x in nominal],
        "rollback_ok":rollback_ok,"half_ok":half_ok,"recovered_ok":recovered_ok,
        "third_retry_count":len(third),"third_retry_time":int(third[0]["STEP"])*dt if third else None,
        "complete":complete,"event_time":event_time,
        "pre_set":target["pre"]["sat"] if target else None,
        "post_set":target["post"]["sat"] if target else None,
        "final_set":events[-1]["sat"] if events else None,
        "finite":finite,"mass_ok":mass_ok,"state_bad":bad,"reverse":reverse,"skipped":skipped,
        "terminal_reason":res.get("TERMINAL_REASON") if res else None,
        "max_ledger":ma,"cum_ledger":cu}
print("F_PE_NLGLOB14Z17F_RECORDS="+json.dumps([record],separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17F_SUMMARY="+json.dumps({"classification":cls,"case_count":1,"event_time":event_time},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17F=PASS")
