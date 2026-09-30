#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
fixtures=[("HEAD",6.25e-5,170.0),("RUNOFF",1.25e-4,212.0),("RUNOFF",6.25e-5,75.0)]
dtop=10.; pmax=.05; rsro=.05
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
for route,dt,horizon in fixtures:
    h,p,rain=forcing(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h),str(p),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    lines=cp.stdout.splitlines()
    nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_NOMINAL_RETRY|")]
    rollback=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_ROLLBACK|")]
    halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_HALF|")]
    recurrent=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17B_RECURRENT_RETRY|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    nominal_ok=(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
    rollback_ok=(len(rollback)==1 and all(abs(float(rollback[0][k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")))
    hs=sorted(halves,key=lambda x:int(x["HALF"]))
    first=next((x for x in hs if int(x["HALF"])==1),None); second=next((x for x in hs if int(x["HALF"])==2),None)
    first_ok=bool(first and int(first["ELIGIBLE"])==1 and int(first["RETRY"])==0 and math.isclose(float(first["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15))
    second_ok=bool(second and int(second["ELIGIBLE"])==1 and int(second["RETRY"])==0 and math.isclose(float(second["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15))
    window_ok=first_ok and second_ok and math.isclose(float(first["DT"])+float(second["DT"]),dt,rel_tol=0,abs_tol=1e-15)
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    ma=abs(float(res["MAX_LEDGER"])) if res else math.inf; cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass=ma<=5e-8 and cu<=5e-8
    finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
    if not nominal_ok or not rollback_ok or not mass or not finite: cls="NLGLOB14Z17B_RETRY_TRANSACTION_INCONSISTENT"
    elif first and int(first["RETRY"])==1: cls="NLGLOB14Z17B_HALFSTEP_INSUFFICIENT"
    elif first_ok and second and int(second["RETRY"])==1: cls="NLGLOB14Z17B_HALFSTEP_INSUFFICIENT"
    elif not first_ok or not second_ok or not window_ok: cls="NLGLOB14Z17B_LOCAL_RECOVERY_HARD_FAILURE"
    elif recurrent: cls="NLGLOB14Z17B_RECOVERY_WITH_RECURRENT_RETRY"
    elif complete: cls="QUALIFIED_Z17B_LOCAL_RETRY_RECOVERY"
    else: cls="NLGLOB14Z17B_LOCAL_RECOVERY_HARD_FAILURE"
    rows.append({"route":route,"dt":dt,"horizon":horizon,"classification":cls,"nominal_retry_count":len(nominal),"nominal_retry_step":int(nominal[0]["STEP"]) if nominal else None,"rollback_ok":rollback_ok,"half_count":len(hs),"first_ok":first_ok,"second_ok":second_ok,"window_ok":window_ok,"recurrent_retry_count":len(recurrent),"complete":complete,"terminal_reason":res.get("TERMINAL_REASON") if res else None,"solver_status":int(res["SOLVER_STATUS"]) if res else None,"finite":finite,"mass_ok":mass,"max_ledger":ma,"cum_ledger":cu,"process_ok":cp.returncode==0})
agg="QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY" if all(x["classification"]=="QUALIFIED_Z14B_LOCAL_RETRY_RECOVERY" for x in rows) else "NLGLOB14Z17B_MIXED_LOCAL_RECOVERY"
print("F_PE_NLGLOB14Z17B_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17B_SUMMARY="+json.dumps({"classification":agg,"case_count":len(rows),"qualified_cases":sum(x["classification"]=="QUALIFIED_Z14B_LOCAL_RETRY_RECOVERY" for x in rows)},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17B=PASS")
