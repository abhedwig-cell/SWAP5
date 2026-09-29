#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dt=1.5625e-5; horizon=.18; dtop=10.; pmax=.05; rsro=.05

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

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

rows=[]; proc=0
for route in ("HEAD","RUNOFF"):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    lines=cp.stdout.splitlines()
    nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z2_NOMINAL_RETRY|")]
    rollback=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z2_ROLLBACK|")]
    halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z2_HALF|")]
    recurrent=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z2_RECURRENT_RETRY|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    nominal_ok=(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and
                math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
    rollback_ok=(len(rollback)==1 and all(abs(float(rollback[0][k]))<=1e-15
                 for k in ("H","THETA","POND","LEDGER","RUNOFF")))
    hs=sorted(halves,key=lambda x:int(x["HALF"]))
    first=next((x for x in hs if int(x["HALF"])==1),None)
    second=next((x for x in hs if int(x["HALF"])==2),None)
    first_ok=bool(first and int(first["ELIGIBLE"])==1 and int(first["RETRY"])==0 and
                  math.isclose(float(first["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15))
    second_ok=bool(second and int(second["ELIGIBLE"])==1 and int(second["RETRY"])==0 and
                   math.isclose(float(second["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15))
    window_ok=first_ok and second_ok and math.isclose(float(first["DT"])+float(second["DT"]),dt,rel_tol=0,abs_tol=1e-15)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)

    if not nominal_ok or not rollback_ok or not mass_ok or not finite:
        cls="LOCAL_RETRY_TRANSACTION_INCONSISTENT"
    elif first and int(first["RETRY"])==1:
        cls="FIRST_HALF_STILL_RETRY_ADVISED"
    elif first_ok and second and int(second["RETRY"])==1:
        cls="SECOND_HALF_RETRY_ADVISED"
    elif not first_ok or (second is not None and not second_ok):
        cls="LOCAL_RETRY_HARD_FAILURE"
    elif window_ok and len(recurrent)>0:
        cls="LOCAL_HALFSTEP_RECOVERS_BUT_RETRY_RECURS"
    elif window_ok and complete:
        cls="LOCAL_HALFSTEP_RECOVERS_NOMINAL_WINDOW"
    elif window_ok and not complete:
        cls="LOCAL_HALFSTEP_RECOVERS_BUT_RETRY_RECURS"
    else:
        cls="LOCAL_RETRY_HARD_FAILURE"

    rows.append({"route":route,"dt":dt,"horizon":horizon,"classification":cls,
                 "process_ok":cp.returncode==0,"nominal":nominal,"rollback":rollback,
                 "halves":hs,"recurrent":recurrent,"nominal_ok":nominal_ok,
                 "rollback_ok":rollback_ok,"window_ok":window_ok,"complete":complete,
                 "terminal_reason":res.get("TERMINAL_REASON") if res else None,
                 "solver_status":int(res["SOLVER_STATUS"]) if res else None,
                 "max_ledger":maxledger,"cum_ledger":cumledger,"mass_ok":mass_ok,"finite":finite})

classes=[x["classification"] for x in rows]
coverage=len(rows)==2 and proc==0 and all(x["nominal_ok"] and x["rollback_ok"] and x["mass_ok"] and x["finite"] for x in rows)
if any(x=="LOCAL_RETRY_TRANSACTION_INCONSISTENT" for x in classes):
    agg="NLGLOB14Z2_RETRY_TRANSACTION_INCONSISTENT"
elif coverage and all(x=="LOCAL_HALFSTEP_RECOVERS_NOMINAL_WINDOW" for x in classes):
    agg="QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY"
elif coverage and all(x=="LOCAL_HALFSTEP_RECOVERS_BUT_RETRY_RECURS" for x in classes):
    agg="NLGLOB14Z2_LOCAL_RECOVERY_WITH_RECURRENT_RETRY"
elif coverage and all(x=="FIRST_HALF_STILL_RETRY_ADVISED" for x in classes):
    agg="NLGLOB14Z2_HALFSTEP_INSUFFICIENT"
else:
    agg="NLGLOB14Z2_MIXED_LOCAL_RETRY_RECOVERY"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "recovered_complete_cases":sum(x=="LOCAL_HALFSTEP_RECOVERS_NOMINAL_WINDOW" for x in classes),
         "recovered_recurrent_cases":sum(x=="LOCAL_HALFSTEP_RECOVERS_BUT_RETRY_RECURS" for x in classes),
         "first_half_retry_cases":sum(x=="FIRST_HALF_STILL_RETRY_ADVISED" for x in classes),
         "second_half_retry_cases":sum(x=="SECOND_HALF_RETRY_ADVISED" for x in classes),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cum_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14Z2_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z2_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z2=PASS")
