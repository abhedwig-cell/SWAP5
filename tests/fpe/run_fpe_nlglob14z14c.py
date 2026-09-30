#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
fixtures=[("HEAD",6.25e-5),("RUNOFF",1.25e-4),("RUNOFF",6.25e-5)]
horizon=280.0; dtop=10.; pmax=.05; rsro=.05
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
    nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z14B_NOMINAL_RETRY|")]
    rollback=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z14B_ROLLBACK|")]
    halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z14B_HALF|")]
    recurrent=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z14B_RECURRENT_RETRY|")]
    states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    events=[]; bad=False; reverse=False; skipped=False; prev_top=None; phase=False
    for i in range(0,len(states),16):
        xs=states[i:i+16]
        if len(xs)!=16: bad=True; continue
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
            if prev_top==11 and top==12: phase=True
            elif phase:
                if d<0: reverse=True
                if d>1: skipped=True
        events.append({"step":step,"time":t,"sat":sat}); prev_top=top
    target=None
    for a,b in zip(events[:-1],events[1:]):
        if a["sat"]==list(range(12,17)) and b["sat"]==list(range(13,17)):
            target={"pre":a,"post":b}; break
    nominal_ok=(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
    rollback_ok=(len(rollback)==1 and all(abs(float(rollback[0][k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")))
    hs=sorted(halves,key=lambda x:int(x["HALF"]))
    first=next((x for x in hs if int(x["HALF"])==1),None); second=next((x for x in hs if int(x["HALF"])==2),None)
    half_ok=bool(first and second and int(first["ELIGIBLE"])==1 and int(first["RETRY"])==0 and int(second["ELIGIBLE"])==1 and int(second["RETRY"])==0 and math.isclose(float(first["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15) and math.isclose(float(second["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    ma=abs(float(res["MAX_LEDGER"])) if res else math.inf; cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass=ma<=5e-8 and cu<=5e-8
    finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
    recurrent_time=(int(recurrent[0]["STEP"])*dt if recurrent else None); event_time=(target["post"]["time"] if target else None)
    if not nominal_ok or not rollback_ok or not half_ok or not mass or not finite or bad or reverse or skipped:
        cls="NLGLOB14Z14C_TRANSACTION_INCONSISTENT"
    elif recurrent and target is None:
        cls="NLGLOB14Z14C_RECURRENT_RETRY_BEFORE_EVENT"
    elif recurrent and target is not None:
        cls="NLGLOB14Z14C_POST_EVENT_RECURRENT_RETRY"
    elif complete and target is not None:
        cls="QUALIFIED_Z14C_REPAIRED_RETREAT_12_TO_13"
    elif complete:
        cls="NLGLOB14Z14C_EVENT_NOT_REACHED"
    else:
        cls="NLGLOB14Z14C_RECURRENT_RETRY_BEFORE_EVENT"
    rows.append({"route":route,"dt":dt,"classification":cls,"process_ok":cp.returncode==0,"complete":complete,"nominal_retry_count":len(nominal),"nominal_retry_step":int(nominal[0]["STEP"]) if nominal else None,"rollback_ok":rollback_ok,"half_ok":half_ok,"recurrent_retry_count":len(recurrent),"recurrent_time":recurrent_time,"event_time":event_time,"pre_set":target["pre"]["sat"] if target else None,"post_set":target["post"]["sat"] if target else None,"final_set":events[-1]["sat"] if events else None,"finite":finite,"mass_ok":mass,"state_bad":bad,"reverse":reverse,"skipped":skipped,"terminal_reason":res.get("TERMINAL_REASON") if res else None,"max_ledger":ma,"cum_ledger":cu})
agg="QUALIFIED_Z14C_THREE_REPAIRED_RETREAT_12_TO_13" if all(x["classification"]=="QUALIFIED_Z14C_REPAIRED_RETREAT_12_TO_13" for x in rows) else "NLGLOB14Z14C_MIXED_REPAIRED_CONTINUATION"
print("F_PE_NLGLOB14Z14C_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z14C_SUMMARY="+json.dumps({"classification":agg,"case_count":len(rows),"qualified_cases":sum(x["classification"]=="QUALIFIED_Z14C_REPAIRED_RETREAT_12_TO_13" for x in rows),"event_times":[{"route":x["route"],"dt":x["dt"],"time":x["event_time"]} for x in rows]},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z14C=PASS")
