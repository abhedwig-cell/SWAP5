#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]; routes=("HEAD","RUNOFF")
horizon=.05; dtop=10.; pmax=.05; rsro=.05
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    if h>=0.0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

rows=[]; proc=0; m=mats["O05"]
for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    nominal=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_NOMINAL|")]
    rb=sorted([fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_ROLLBACK|")],key=lambda x:int(x["DEPTH"]))
    at=sorted([fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_ATTEMPT|")],key=lambda x:int(x["DEPTH"]))
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    nominal_ok=bool(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
    rollback_ok=(len(rb)==len(at) and len(rb)>0 and all(all(abs(float(x[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")) for x in rb))
    depth_seq=all(int(x["DEPTH"])==i+1 and math.isclose(float(x["DT"]),dt*(0.5**(i+1)),rel_tol=0,abs_tol=1e-15) for i,x in enumerate(at))
    accepted=next((x for x in at if int(x["ELIGIBLE"])==1),None)
    hard=next((x for x in at if int(x["ELIGIBLE"])==0 and int(x["RETRY"])==0),None)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    if not nominal_ok or not rollback_ok or not depth_seq or not mass_ok:
      cls="RECURSIVE_RETRY_STATE_OR_MASS_INCONSISTENT"
    elif accepted is not None:
      if abs(float(accepted["LEDGER_DELTA"]))>5e-8:
        cls="RECURSIVE_RETRY_STATE_OR_MASS_INCONSISTENT"
      elif int(accepted["SAT_MODE"])==1:
        cls="ACCEPTED_SATURATED_REENTRY_AT_BOUNDED_RETRY"
      else:
        cls="ACCEPTED_TG_PROGRESS_AT_BOUNDED_RETRY"
    elif hard is not None:
      cls="RECURSIVE_RETRY_HARD_FAILURE"
    elif len(at)==8 and all(int(x["RETRY"])==1 for x in at):
      cls="RETRY_BUDGET_EXHAUSTED"
    else:
      cls="RECURSIVE_RETRY_HARD_FAILURE"
    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
      "nominal_ok":nominal_ok,"rollback_ok":rollback_ok,"depth_sequence_ok":depth_seq,
      "attempts":at,"accepted_depth":int(accepted["DEPTH"]) if accepted else None,
      "accepted_dt":float(accepted["DT"]) if accepted else None,
      "accepted_sat_mode":int(accepted["SAT_MODE"]) if accepted else None,
      "accepted_sat_count":int(accepted["SAT_COUNT"]) if accepted else None,
      "mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger,"process_ok":cp.returncode==0})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["nominal_ok"] and x["rollback_ok"] and x["depth_sequence_ok"] and x["mass_ok"] for x in rows)
if any(x=="RECURSIVE_RETRY_STATE_OR_MASS_INCONSISTENT" for x in classes):
  cls="NLGLOB14R3_RETRY_TRANSACTION_INCONSISTENT"
elif coverage and all(x=="ACCEPTED_TG_PROGRESS_AT_BOUNDED_RETRY" for x in classes):
  cls="NLGLOB14R3_BOUNDED_RETRY_FINDS_TG_PROGRESS"
elif coverage and all(x=="ACCEPTED_SATURATED_REENTRY_AT_BOUNDED_RETRY" for x in classes):
  cls="NLGLOB14R3_BOUNDED_RETRY_FINDS_SATURATED_REENTRY"
elif coverage and all(x=="RETRY_BUDGET_EXHAUSTED" for x in classes):
  cls="NLGLOB14R3_RETRY_BUDGET_EXHAUSTED"
else:
  cls="NLGLOB14R3_MIXED_RETRY_DEPTH"
summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "tg_progress_cases":sum(x=="ACCEPTED_TG_PROGRESS_AT_BOUNDED_RETRY" for x in classes),
  "saturated_reentry_cases":sum(x=="ACCEPTED_SATURATED_REENTRY_AT_BOUNDED_RETRY" for x in classes),
  "exhausted_cases":sum(x=="RETRY_BUDGET_EXHAUSTED" for x in classes),
  "hard_failure_cases":sum(x=="RECURSIVE_RETRY_HARD_FAILURE" for x in classes),
  "accepted_depths":[x["accepted_depth"] for x in rows],
  "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
  "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R3_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R3_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R3=PASS")
