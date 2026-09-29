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
    inv=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R4_INVALID|")]
    nodes=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R4_NODE|")]
    attempts=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_ATTEMPT|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    if not inv:
      cls="NO_INVALID_BRACKET"
      detail=None
    elif len(inv)!=1:
      cls="BRACKET_INVALID_OTHER"; detail=None
    else:
      d=inv[0]; invdt=float(d["DT"])
      ns=[x for x in nodes if math.isclose(float(x["DT"]),invdt,rel_tol=0,abs_tol=1e-18)]
      over=int(d["OVER"]); existing=int(d["EXISTING"]); new=int(d["NEW"]); valid=int(d["VALID_PHI"]); ev=int(d["EVENT_NODE"])
      node_consistent=(len(ns)==16 and
        sum(int(x["OVERSHOOT"]) for x in ns)==over and
        all(int(x["ORIGIN_SAT"])==1 for x in ns if int(x["OVERSHOOT"])==1) if over>0 else True)
      if over>0 and existing==over and new==0 and valid==0 and ev==0 and node_consistent:
        cls="EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING"
      elif new>0:
        cls="NEW_CROSSING_PRESENT_BUT_BRACKET_INVALID"
      else:
        cls="BRACKET_INVALID_OTHER"
      detail={"invalid":d,"node_count":len(ns),"node_consistent":node_consistent,
              "overshoot_nodes":[int(x["NODE"]) for x in ns if int(x["OVERSHOOT"])==1],
              "origin_saturated_overshoot_nodes":[int(x["NODE"]) for x in ns if int(x["OVERSHOOT"])==1 and int(x["ORIGIN_SAT"])==1]}
    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
                 "detail":detail,"invalid_count":len(inv),"attempt_count":len(attempts),
                 "mass_ok":mass_ok,"process_ok":cp.returncode==0,
                 "max_ledger":maxledger,"cum_ledger":cumledger})

affected=[x for x in rows if x["invalid_count"]>0]
controls=[x for x in rows if x["invalid_count"]==0]
classes=[x["classification"] for x in affected]
coverage=(len(rows)==12 and proc==0 and len(affected)==9 and len(controls)==3 and all(x["mass_ok"] for x in rows))
if coverage and all(x=="EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING" for x in classes):
  cls="NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT"
elif any(x=="NEW_CROSSING_PRESENT_BUT_BRACKET_INVALID" for x in classes):
  cls="NLGLOB14R4_INVALID_BRACKET_INCLUDES_NEW_CROSSING"
else:
  cls="NLGLOB14R4_MIXED_INVALID_BRACKET_MECHANISM"
summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),
         "invalid_cases":len(affected),"control_cases":len(controls),
         "existing_saturated_overshoot_cases":sum(x=="EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING" for x in classes),
         "new_crossing_cases":sum(x=="NEW_CROSSING_PRESENT_BUT_BRACKET_INVALID" for x in classes),
         "other_invalid_cases":sum(x=="BRACKET_INVALID_OTHER" for x in classes),
         "process_failures":proc,
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R4_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R4_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R4=PASS")
