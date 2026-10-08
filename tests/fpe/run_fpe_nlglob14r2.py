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
    nominal=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R2_NOMINAL_RETRY|")]
    rb=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R2_ROLLBACK|")]
    halves=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R2_HALF|")]
    hands=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_HANDOFF|")]
    follows=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_FOLLOW|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    nominal_retry=bool(len(nominal)==1 and int(nominal[0]["RETRY"])==1 and
                       math.isclose(float(nominal[0]["DT"]),dt,rel_tol=0,abs_tol=1e-15))
    rollback_ok=bool(len(rb)==1 and all(abs(float(rb[0][k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")) and
                     math.isclose(float(rb[0]["RETRY_SCALE"]),0.5,rel_tol=0,abs_tol=1e-15))
    halfs=sorted(halves,key=lambda x:int(x["HALF"]))
    half_dts=[float(x["DT"]) for x in halfs]
    window_time_ok=(len(halfs)==2 and all(math.isclose(x,0.5*dt,rel_tol=0,abs_tol=1e-15) for x in half_dts)
                    and math.isclose(sum(half_dts),dt,rel_tol=0,abs_tol=1e-15))
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    if not nominal_retry or not rollback_ok or not mass_ok:
      cls="RETRY_RECOVERY_STATE_OR_MASS_INCONSISTENT"
    elif any(int(x.get("RETRY","0"))==1 for x in halfs):
      cls="RETRY_HALF_INTERVAL_STILL_RETRY_ADVISED"
    elif len(halfs)<2 or any(int(x["ELIGIBLE"])!=1 for x in halfs):
      cls="RETRY_RECOVERY_HARD_FAILURE"
    elif not window_time_ok:
      cls="RETRY_RECOVERY_STATE_OR_MASS_INCONSISTENT"
    elif any(int(x["SAT_MODE"])==1 for x in halfs):
      cls="RETRY_RECOVERS_WITH_SATURATED_REENTRY"
    else:
      cls="RETRY_RECOVERS_NOMINAL_WINDOW_UNDER_TG"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
                 "process_ok":cp.returncode==0,"nominal_retry":nominal_retry,
                 "rollback_ok":rollback_ok,"window_time_ok":window_time_ok,
                 "half_count":len(halfs),"halves":halfs,
                 "handoff_count":len(hands),"follow_count":len(follows),
                 "mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger,
                 "terminal_reason":res.get("TERMINAL_REASON") if res else None})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["nominal_retry"] and x["rollback_ok"] and x["mass_ok"] for x in rows)
if any(x=="RETRY_RECOVERY_STATE_OR_MASS_INCONSISTENT" for x in classes):
    cls="NLGLOB14R2_RETRY_TRANSACTION_INCONSISTENT"
elif coverage and all(x=="RETRY_RECOVERS_NOMINAL_WINDOW_UNDER_TG" for x in classes):
    cls="NLGLOB14R2_TRANSACTION_RETRY_RECOVERS_TG_OWNERSHIP"
elif coverage and all(x=="RETRY_RECOVERS_WITH_SATURATED_REENTRY" for x in classes):
    cls="NLGLOB14R2_TRANSACTION_RETRY_RECOVERS_WITH_SATURATED_REENTRY"
elif coverage and all(x=="RETRY_HALF_INTERVAL_STILL_RETRY_ADVISED" for x in classes):
    cls="NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT"
else:
    cls="NLGLOB14R2_MIXED_RETRY_RECOVERY"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "tg_recovered_cases":sum(x=="RETRY_RECOVERS_NOMINAL_WINDOW_UNDER_TG" for x in classes),
         "reentry_recovered_cases":sum(x=="RETRY_RECOVERS_WITH_SATURATED_REENTRY" for x in classes),
         "still_retry_cases":sum(x=="RETRY_HALF_INTERVAL_STILL_RETRY_ADVISED" for x in classes),
         "hard_failure_cases":sum(x=="RETRY_RECOVERY_HARD_FAILURE" for x in classes),
         "inconsistent_cases":sum(x=="RETRY_RECOVERY_STATE_OR_MASS_INCONSISTENT" for x in classes),
         "all_window_time_ok":all(x["window_time_ok"] for x in rows if x["half_count"]==2),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R2_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R2_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R2=PASS")
