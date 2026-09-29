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
    at=sorted([fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_ATTEMPT|")],key=lambda x:int(x["DEPTH"]))
    roots=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R4_ROOT|")]
    nodes=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R4_NODE|")]
    rb=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14R3_ROLLBACK|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    invalid_attempt=next((x for x in at if x["TERMINAL"]=="SATURATION_ROOT_BRACKET_INVALID"),None)
    exhausted=(len(at)==8 and all(int(x["RETRY"])==1 for x in at))
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    rollback_ok=(len(rb)==len(at) and len(rb)>0 and all(all(abs(float(x[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")) for x in rb))

    rmatch=None; nmatch=[]
    if invalid_attempt is not None:
      adt=float(invalid_attempt["DT"])
      cand=[x for x in roots if math.isclose(float(x["ATTEMPT_DT"]),adt,rel_tol=0,abs_tol=1e-15) and int(x["BRACKET_INVALID"])==1]
      if len(cand)==1:
        rmatch=cand[0]
        nmatch=[x for x in nodes if math.isclose(float(x["ATTEMPT_DT"]),adt,rel_tol=0,abs_tol=1e-15)]
      if not mass_ok or not rollback_ok:
        cls="ROOT_ATTRIBUTION_STATE_INCONSISTENT"
      elif rmatch is None or len(nmatch)!=16 or not all(math.isfinite(float(x["CAND_THETA"])) for x in nmatch):
        cls="INVALID_BRACKET_STALE_CANDIDATE_SURFACE"
      else:
        newc=int(rmatch["NEW_CROSSINGS"]); event=int(rmatch["EVENT_NODE"])
        valid_new_phi=[float(x["PHI"]) for x in nmatch if int(x["ORIGIN_SAT"])==0 and float(x["DELTA_S"])>0.0 and math.isfinite(float(x["PHI"]))]
        valid_new_phi=[v for v in valid_new_phi if 0.0<v<1.0]
        if int(rmatch["ORIGIN_SAT_COUNT"])==13 and newc==0 and event==0:
          cls="INVALID_BRACKET_NO_NEW_CROSSING"
        elif newc>0 and not valid_new_phi:
          cls="INVALID_BRACKET_NEW_CROSSING_BUT_PHI_INVALID"
        elif newc>0 and valid_new_phi and event==0:
          cls="INVALID_BRACKET_NEW_CROSSING_SELECTION_FAILURE"
        else:
          cls="INVALID_BRACKET_NEW_CROSSING_SELECTION_FAILURE"
    elif exhausted:
      if mass_ok and rollback_ok and not any(int(x.get("BRACKET_INVALID","0"))==1 for x in roots):
        cls="CONTROL_NO_INVALID_BRACKET"
      else:
        cls="ROOT_ATTRIBUTION_STATE_INCONSISTENT"
    else:
      cls="ROOT_ATTRIBUTION_STATE_INCONSISTENT"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
      "process_ok":cp.returncode==0,"invalid_attempt":invalid_attempt,"root":rmatch,
      "node_count":len(nmatch),"r3_attempt_count":len(at),"exhausted_control":exhausted,
      "rollback_ok":rollback_ok,"mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger})

classes=[x["classification"] for x in rows]
invalid_rows=[x for x in rows if x["invalid_attempt"] is not None]
control_rows=[x for x in rows if x["invalid_attempt"] is None]
coverage=(len(rows)==12 and proc==0 and len(invalid_rows)==9 and len(control_rows)==3 and
          all(x["mass_ok"] and x["rollback_ok"] for x in rows))
if any(x=="ROOT_ATTRIBUTION_STATE_INCONSISTENT" for x in classes):
  cls="NLGLOB14R4_ROOT_ATTRIBUTION_STATE_INCONSISTENT"
elif coverage and all(x["classification"]=="INVALID_BRACKET_NO_NEW_CROSSING" for x in invalid_rows) and all(x["classification"]=="CONTROL_NO_INVALID_BRACKET" for x in control_rows):
  cls="NLGLOB14R4_ROOT_GLOBALIZATION_WITHOUT_NEW_CROSSING"
elif coverage and all(x["classification"]=="INVALID_BRACKET_STALE_CANDIDATE_SURFACE" for x in invalid_rows):
  cls="NLGLOB14R4_ROOT_GLOBALIZATION_USES_STALE_CANDIDATE"
elif any(x["classification"].startswith("INVALID_BRACKET_NEW_CROSSING") for x in invalid_rows):
  cls="NLGLOB14R4_GENUINE_POSTRELEASE_SATURATION_EVENT_SIGNAL"
else:
  cls="NLGLOB14R4_MIXED_ROOT_INVALIDITY"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "invalid_cases":len(invalid_rows),"control_cases":len(control_rows),
  "no_new_crossing_cases":sum(x=="INVALID_BRACKET_NO_NEW_CROSSING" for x in classes),
  "stale_candidate_cases":sum(x=="INVALID_BRACKET_STALE_CANDIDATE_SURFACE" for x in classes),
  "genuine_crossing_cases":sum(x.startswith("INVALID_BRACKET_NEW_CROSSING") for x in classes),
  "control_ok_cases":sum(x=="CONTROL_NO_INVALID_BRACKET" for x in classes),
  "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
  "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14R4_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R4_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14R4=PASS")
