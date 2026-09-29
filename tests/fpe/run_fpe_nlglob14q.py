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
    shadows=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Q_SHADOW|")]
    rollbacks=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Q_ROLLBACK|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    s=shadows[0] if len(shadows)==1 else None
    rb=rollbacks[0] if len(rollbacks)==1 else None
    rollback_ok=bool(rb and all(abs(float(rb[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")))

    if not s or not rb or not complete or not mass_ok:
      cls="SHADOW_TG_STATE_OR_MASS_INCONSISTENT"
    else:
      domain=int(s["DOMAIN"])==1
      eligible=int(s["ELIGIBLE"])==1
      finite=int(s["FINITE"])==1
      origin=int(s["ORIGIN_ROUTE"]); pred=int(s["PRED_ROUTE"]); endpoint=int(s["ENDPOINT_ROUTE"]); accept=int(s["ACCEPT_ROUTE"])
      route_ok=(origin>0 and pred==origin and endpoint==origin and accept==origin)
      shadow_mass=abs(float(s["SHADOW_LEDGER"]))<=5e-8
      if not rollback_ok or not finite:
        cls="SHADOW_TG_STATE_OR_MASS_INCONSISTENT"
      elif domain:
        cls="SHADOW_TG_IMMEDIATE_SATURATION_REENTRY"
      elif eligible and s["TERMINAL"]=="COMPLETE_SAME_ROUTE":
        if not shadow_mass:
          cls="SHADOW_TG_STATE_OR_MASS_INCONSISTENT"
        elif route_ok:
          cls="SHADOW_TG_INTERVAL_ADMISSIBLE"
        else:
          cls="SHADOW_TG_SOLVER_OR_ROUTE_FAILURE"
      else:
        cls="SHADOW_TG_SOLVER_OR_ROUTE_FAILURE"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
                 "process_ok":cp.returncode==0,"control_complete":complete,"control_mass_ok":mass_ok,
                 "shadow_count":len(shadows),"rollback_count":len(rollbacks),"rollback_ok":rollback_ok,
                 "shadow":s,"max_ledger":maxledger,"cum_ledger":cumledger})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["control_complete"] and x["control_mass_ok"] and x["shadow_count"]==1 and x["rollback_count"]==1 for x in rows)
if any(x=="SHADOW_TG_STATE_OR_MASS_INCONSISTENT" for x in classes):
    cls="NLGLOB14Q_SHADOW_TRANSACTION_INCONSISTENT"
elif coverage and all(x=="SHADOW_TG_INTERVAL_ADMISSIBLE" for x in classes):
    cls="NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE"
elif coverage and all(x=="SHADOW_TG_IMMEDIATE_SATURATION_REENTRY" for x in classes):
    cls="NLGLOB14Q_FIRST_RETREAT_CAUSES_IMMEDIATE_TG_REENTRY"
elif coverage and all(x=="SHADOW_TG_SOLVER_OR_ROUTE_FAILURE" for x in classes):
    cls="NLGLOB14Q_FULL_COLUMN_TG_SHADOW_SOLVE_NOT_ADMISSIBLE"
else:
    cls="NLGLOB14Q_MIXED_SHADOW_HANDOFF"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "admissible_cases":sum(x=="SHADOW_TG_INTERVAL_ADMISSIBLE" for x in classes),
         "immediate_reentry_cases":sum(x=="SHADOW_TG_IMMEDIATE_SATURATION_REENTRY" for x in classes),
         "solver_route_failure_cases":sum(x=="SHADOW_TG_SOLVER_OR_ROUTE_FAILURE" for x in classes),
         "state_mass_inconsistent_cases":sum(x=="SHADOW_TG_STATE_OR_MASS_INCONSISTENT" for x in classes),
         "all_rollback_ok":all(x["rollback_ok"] for x in rows),
         "max_control_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_control_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14Q_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Q_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Q=PASS")
