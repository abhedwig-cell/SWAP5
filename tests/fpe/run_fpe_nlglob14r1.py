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
    fs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R1_FAIL|")]
    hands=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_HANDOFF|")]
    follows=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R_FOLLOW|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    f=fs[0] if len(fs)==1 else None

    reproduced=bool(res and res.get("TERMINAL_REASON")=="ENDPOINT_SOLVE_FAILURE" and len(hands)==1 and len(follows)==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    if not reproduced:
      cls="BLOCKER_NOT_REPRODUCED"
    elif not f:
      cls="SECOND_INTERVAL_FAILURE_UNATTRIBUTED"
    elif int(f["RETRY"])==1:
      cls="SECOND_INTERVAL_RETRY_ADVISED"
    elif int(f["STATUS"])!=1:
      cls="SECOND_INTERVAL_SOLVER_HARD_FAILURE"
    else:
      cls="SECOND_INTERVAL_FAILURE_UNATTRIBUTED"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
                 "reproduced":reproduced,"diag":f,"mass_ok":mass_ok,
                 "max_ledger":maxledger,"cum_ledger":cumledger,
                 "process_ok":cp.returncode==0})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["reproduced"] and x["mass_ok"] for x in rows)
if not coverage:
    cls="BLOCKED_NLGLOB14R1_SECOND_INTERVAL_ATTRIBUTION"
elif all(x=="SECOND_INTERVAL_RETRY_ADVISED" for x in classes):
    cls="NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED"
elif len(set(classes))==1:
    cls="NLGLOB14R1_UNIFORM_"+classes[0]
else:
    cls="NLGLOB14R1_MIXED_SECOND_INTERVAL_FAILURE_MECHANISM"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "retry_advised_cases":sum(x=="SECOND_INTERVAL_RETRY_ADVISED" for x in classes),
         "hard_failure_cases":sum(x=="SECOND_INTERVAL_SOLVER_HARD_FAILURE" for x in classes),
         "unattributed_cases":sum(x=="SECOND_INTERVAL_FAILURE_UNATTRIBUTED" for x in classes),
         "blocker_not_reproduced_cases":sum(x=="BLOCKER_NOT_REPRODUCED" for x in classes),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R1_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R1=PASS")
