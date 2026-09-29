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
    starts=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_START|")]
    hands=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_HANDOFF|")]
    follows=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_FOLLOW|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    h=hands[0] if len(hands)==1 else None
    f=follows[0] if len(follows)==1 else None
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    intentional=bool(res and res["TERMINAL_REASON"]=="NLGLOB14R_WINDOW_COMPLETE")
    first_ok=bool(h and int(h["ELIGIBLE"])==1 and int(h["SAT_MODE"])==0 and mass_ok)

    if not res or not h or not f or not mass_ok:
      cls="HANDOFF_STATE_OR_MASS_INCONSISTENT"
    elif not first_ok:
      cls="TG_HANDOFF_FIRST_INTERVAL_FAILURE"
    elif int(f["ELIGIBLE"])==1 and int(f["SAT_MODE"])==0:
      cls="STABLE_TG_OWNERSHIP_AFTER_HANDOFF"
    elif int(f["ELIGIBLE"])==1 and int(f["SAT_MODE"])==1:
      cls="IMMEDIATE_SATURATED_MODE_REENTRY"
    else:
      cls="OTHER_FOLLOWUP_FAILURE"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
                 "process_ok":cp.returncode==0,"start_count":len(starts),"handoff_count":len(hands),
                 "follow_count":len(follows),"handoff":h,"follow":f,
                 "intentional_window_stop":intentional,"mass_ok":mass_ok,
                 "max_ledger":maxledger,"cum_ledger":cumledger,
                 "final_terminal":res.get("TERMINAL_REASON") if res else None})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["start_count"]==1 and x["handoff_count"]==1 and x["follow_count"]==1 for x in rows)
if any(x=="HANDOFF_STATE_OR_MASS_INCONSISTENT" for x in classes):
    cls="NLGLOB14R_HANDOFF_STATE_OR_MASS_INCONSISTENT"
elif coverage and all(x=="STABLE_TG_OWNERSHIP_AFTER_HANDOFF" for x in classes):
    cls="NLGLOB14R_STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT"
elif coverage and all(x=="IMMEDIATE_SATURATED_MODE_REENTRY" for x in classes):
    cls="NLGLOB14R_FIRST_RETREAT_HANDOFF_CHATTERS_BACK_TO_SATURATED"
else:
    cls="NLGLOB14R_MIXED_HANDOFF_PERSISTENCE"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "stable_cases":sum(x=="STABLE_TG_OWNERSHIP_AFTER_HANDOFF" for x in classes),
         "immediate_reentry_cases":sum(x=="IMMEDIATE_SATURATED_MODE_REENTRY" for x in classes),
         "first_interval_failure_cases":sum(x=="TG_HANDOFF_FIRST_INTERVAL_FAILURE" for x in classes),
         "other_followup_failure_cases":sum(x=="OTHER_FOLLOWUP_FAILURE" for x in classes),
         "state_mass_inconsistent_cases":sum(x=="HANDOFF_STATE_OR_MASS_INCONSISTENT" for x in classes),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R=PASS")
