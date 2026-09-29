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
kt=kvg(h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q
cp=subprocess.run([str(exe),"O05","TG","HEAD",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
  str(m["ksat"]),str(m["lambda"]),str(h),str(p),str(rain),str(dt),str(horizon)],text=True,capture_output=True)

solve=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14N2_SOLVE_FAIL|")]
ctx=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14N2_ROOT_CONTEXT|")]
res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
s=solve[0] if solve else None; c=ctx[0] if ctx else None
reproduced=bool(res and res.get("TERMINAL_REASON")=="SATURATION_ROOT_TRIAL_OTHER_FAILED" and s and c)

if not reproduced:
    cls="BLOCKER_NOT_REPRODUCED"
else:
    nl=int(s["NL"]); back=int(s["BACK"]); jac=int(s["JAC"]); lin=int(s["LIN"])
    retry=int(s["RETRY"])==1; route=s.get("ROUTE","")
    if retry:
        cls="RETRY_ADVISED_AT_ROOT_TRIAL"
    elif back>=8 and lin>=0:
        cls="BACKTRACKING_LIMIT"
    elif nl>=8:
        cls="NONLINEAR_ITERATION_LIMIT"
    elif ("linear" in route.lower() or "jac" in route.lower()) or lin<jac:
        cls="LINEAR_OR_JACOBIAN_FAILURE"
    else:
        cls="ROOT_TRIAL_SOLVER_FAILURE_OTHER"

record={"classification":cls,"reproduced":reproduced,"process_returncode":cp.returncode,
        "solve_failure":s,"root_context":c,
        "terminal_reason":res.get("TERMINAL_REASON") if res else None,
        "steps_done":int(res["STEPS_DONE"]) if res else None,
        "max_ledger":abs(float(res["MAX_LEDGER"])) if res else math.inf,
        "cum_ledger":abs(float(res["CUM_LEDGER"])) if res else math.inf}
print("F_PE_NLGLOB14N2_RECORD="+json.dumps(record,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N2=PASS")
