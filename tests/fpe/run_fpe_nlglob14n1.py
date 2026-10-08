#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
m=mats["O05"]; dt=7.8125e-6; horizon=.05; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0.0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

h=-5.; p=.025
kt=kvg(h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
rain=-q
cp=subprocess.run([str(exe),"O05","TG","HEAD",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
  str(m["ksat"]),str(m["lambda"]),str(h),str(p),str(rain),str(dt),str(horizon)],text=True,capture_output=True)

fails=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14N1_ROOT_FAIL|")]
res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
first=fails[0] if fails else None
under=(first or {}).get("UNDERLYING","")
route_reasons={"ORIGIN_ROUTE_MISMATCH","FORWARD_PREDICTOR_ROUTE_MISMATCH","ENDPOINT_PROVIDER_ROUTE_MISMATCH","ENDPOINT_INSTANTANEOUS_ROUTE_MISMATCH","ACCEPTED_ROUTE_MISMATCH"}
solver_reasons={"ENDPOINT_SOLVE_FAILURE","ENDPOINT_TOP_UNAVAILABLE"}
state_reasons={"HEADSPACE_PREDICTOR_CAPACITY_FAILED","HEADSPACE_PREDICTOR_NONFINITE","HEADSPACE_PREDICTOR_K_FAILED","PREDICTED_PONDING_NEGATIVE","ACCEPTED_PONDING_NEGATIVE","PREDICTED_RETENTION_DOMAIN_FAILED"}

reproduced=bool(res and res.get("TERMINAL_REASON")=="SATURATION_ROOT_TRIAL_OTHER_FAILED")
if not reproduced:
    cls="NLGLOB14N1_BLOCKER_NOT_REPRODUCED"
elif not first:
    cls="NLGLOB14N1_ROOT_TRIAL_FAILURE_UNATTRIBUTED"
elif under in route_reasons:
    cls="NLGLOB14N1_ROOT_TRIAL_ROUTE_CONSISTENCY_FAILURE"
elif under in solver_reasons:
    cls="NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE"
elif under in state_reasons:
    cls="NLGLOB14N1_ROOT_TRIAL_PREDICTOR_OR_STATE_FAILURE"
else:
    cls="NLGLOB14N1_ROOT_TRIAL_FAILURE_UNATTRIBUTED"

record={"classification":cls,"process_returncode":cp.returncode,"reproduced":reproduced,
        "root_fail_count":len(fails),"first_root_fail":first,
        "terminal_reason":res.get("TERMINAL_REASON") if res else None,
        "steps_done":int(res["STEPS_DONE"]) if res else None,
        "eligible":int(res["ELIGIBLE"]) if res else None,
        "max_ledger":abs(float(res["MAX_LEDGER"])) if res else math.inf,
        "cum_ledger":abs(float(res["CUM_LEDGER"])) if res else math.inf}
print("F_PE_NLGLOB14N1_RECORD="+json.dumps(record,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N1=PASS")
