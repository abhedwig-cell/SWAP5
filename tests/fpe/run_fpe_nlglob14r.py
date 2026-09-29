#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

cand=Path(sys.argv[1]); control=Path(sys.argv[2]); bank=Path(sys.argv[3])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]
routes=("HEAD","RUNOFF"); horizon=.05; dtop=10.; pmax=.05; rsro=.05
m=mats["O05"]

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0.0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain
def invoke(exe,route,dt):
    h,p,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h),str(p),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    return cp
def result(out):
    x=next((fields(line) for line in out.splitlines() if line.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    return x
def complete_mass(r):
    if not r: return False,False
    complete=r["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(r["ELIGIBLE"])==1
    mass=abs(float(r["MAX_LEDGER"]))<=5e-8 and abs(float(r["CUM_LEDGER"]))<=5e-8
    return complete,mass
def finite_result(r):
    if not r: return False
    keys=("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")
    return all(math.isfinite(float(r[k])) for k in keys)

rows=[]; proc=0
for route in routes:
  for dt in dts:
    cc=invoke(control,route,dt); ce=invoke(cand,route,dt)
    proc += int(cc.returncode!=0)+int(ce.returncode!=0)
    rc=result(cc.stdout); re=result(ce.stdout)
    ccomplete,cmass=complete_mass(rc); ecomplete,emass=complete_mass(re)
    retreats=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_RETREAT|")]
    handoffs=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_HANDOFF|")]
    reentries=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_REENTRY|")]
    tgowned=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_TG_OWNED|")]
    finals=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_FINAL|")]
    modes=[fields(x) for x in ce.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    h=handoffs[0] if len(handoffs)==1 else None
    fin=finals[0] if len(finals)==1 else None
    handoff_ok=bool(h and int(h.get("OK","0"))==1)
    handoff_mass=bool(handoff_ok and abs(float(h.get("LEDGER","inf")))<=5e-8)
    handoff_routes=bool(handoff_ok and all(int(h.get(k,"0"))==1 for k in ("ORIGIN_ROUTE","PRED_ROUTE","ENDPOINT_ROUTE","ACCEPT_ROUTE")))
    first_delay=int(reentries[0]["DELAY"]) if reentries else None
    post_reentry_klag=0
    if reentries:
      rs=int(reentries[0]["STEP"])
      post_reentry_klag=sum(int(x.get("STEP","0"))>=rs and int(x.get("ENTRY","0"))==0 for x in modes)
    state_ok=finite_result(re) and bool(fin)
    final_sat=int(fin["SAT"]) if fin else None

    if (not ccomplete) or (not cmass) or (ecomplete and not emass) or (handoff_ok and not handoff_mass) or not state_ok:
      cls="HANDOFF_STATE_OR_MASS_INCONSISTENT"
    elif not handoff_ok:
      cls="HANDOFF_TG_INTERVAL_FAILED"
    elif reentries and first_delay==1 and ecomplete and emass:
      cls="IMMEDIATE_SATURATED_MODE_REENTRY"
    elif reentries and first_delay is not None and first_delay>1 and ecomplete and emass:
      cls="DELAYED_SATURATED_MODE_REENTRY"
    elif not reentries and ecomplete and emass and handoff_routes:
      cls="STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT"
    else:
      cls="HANDOFF_TG_INTERVAL_FAILED"

    diffs={}
    if rc and re:
      for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","STORAGE"):
        diffs[k.lower()+"_diff"]=float(re[k])-float(rc[k])
    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
      "control_complete":ccomplete,"control_mass_ok":cmass,
      "experiment_complete":ecomplete,"experiment_mass_ok":emass,
      "retreat_count":len(retreats),"handoff_count":len(handoffs),"handoff_ok":handoff_ok,
      "handoff_mass_ok":handoff_mass,"handoff_route_ok":handoff_routes,
      "handoff_step":int(h["STEP"]) if h else None,
      "handoff_sat":int(h["SAT"]) if h and "SAT" in h else None,
      "handoff_ledger":float(h["LEDGER"]) if h and "LEDGER" in h else None,
      "reentry_count":len(reentries),"first_reentry_delay":first_delay,
      "tg_owned_intervals":len(tgowned)+int(handoff_ok),
      "post_reentry_klag_intervals":post_reentry_klag,
      "final_sat_count":final_sat,
      "max_ledger":abs(float(re["MAX_LEDGER"])) if re else math.inf,
      "cum_ledger":abs(float(re["CUM_LEDGER"])) if re else math.inf,
      "terminal_reason":re["TERMINAL_REASON"] if re else "MISSING_RESULT",
      "control_differences":diffs})

classes=[x["classification"] for x in rows]
coverage=(len(rows)==12 and proc==0 and all(x["control_complete"] and x["control_mass_ok"] and x["retreat_count"]==1 and x["handoff_count"]==1 for x in rows))
if any(x=="HANDOFF_STATE_OR_MASS_INCONSISTENT" for x in classes):
    cls="NLGLOB14R_HANDOFF_STATE_OR_MASS_INCONSISTENT"
elif coverage and all(x=="STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT" for x in classes):
    cls="NLGLOB14R_STABLE_FULL_COLUMN_TG_RELEASE_SIGNAL"
elif coverage and all(x=="IMMEDIATE_SATURATED_MODE_REENTRY" for x in classes):
    cls="NLGLOB14R_FIRST_RETREAT_RELEASE_CHATTERS_IMMEDIATELY"
elif coverage and all(x in ("IMMEDIATE_SATURATED_MODE_REENTRY","DELAYED_SATURATED_MODE_REENTRY") for x in classes):
    cls="NLGLOB14R_FIRST_RETREAT_RELEASE_REENTERS_SATURATED_MODE"
elif coverage and all(x=="HANDOFF_TG_INTERVAL_FAILED" for x in classes):
    cls="NLGLOB14R_ACCEPTED_TG_HANDOFF_NOT_ADMISSIBLE"
else:
    cls="NLGLOB14R_MIXED_HANDOFF_REENTRY"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "stable_cases":sum(x=="STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT" for x in classes),
  "immediate_reentry_cases":sum(x=="IMMEDIATE_SATURATED_MODE_REENTRY" for x in classes),
  "delayed_reentry_cases":sum(x=="DELAYED_SATURATED_MODE_REENTRY" for x in classes),
  "handoff_failed_cases":sum(x=="HANDOFF_TG_INTERVAL_FAILED" for x in classes),
  "state_mass_inconsistent_cases":sum(x=="HANDOFF_STATE_OR_MASS_INCONSISTENT" for x in classes),
  "all_experiment_mass_ok":all(x["experiment_mass_ok"] for x in rows if x["experiment_complete"]),
  "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
  "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R=PASS")
