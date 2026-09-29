#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.012; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

rows=[]; proc=0
m=mats["O05"]
for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    forcing=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14G_FORCING|")]
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
    rec={"material":"O05","route":route,"dt":dt,"wet_rain":rain,"process_ok":cp.returncode==0,
         "entry_count":len(entries),"forcing_records":len(forcing),"state_records":len(states)}
    if res:
      rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      rec["terminal_reason"]=res["TERMINAL_REASON"]
      rec["finite_final"]=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
      rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
    else:
      rec["complete"]=False; rec["terminal_reason"]="MISSING_RESULT"; rec["finite_final"]=False
      rec["max_ledger"]=math.inf; rec["cum_ledger"]=math.inf

    forcing_ok=bool(forcing)
    for f in forcing:
      forcing_ok = forcing_ok and abs(float(f["PRECIP"]))<=1e-15
      forcing_ok = forcing_ok and math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12)
      forcing_ok = forcing_ok and math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12)
      forcing_ok = forcing_ok and f.get("PHASE")=="DRY"
    rec["forcing_ok"]=forcing_ok

    event_nodes={int(x["EVENT_NODE"]) for x in states if int(x.get("EVENT_NODE","0"))>0}
    event_node=next(iter(event_nodes)) if len(event_nodes)==1 else 0
    rec["event_node"]=event_node
    bystep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
    inconsistent=False; release=None; release_other_sat=None; release_route=None; release_pond=None
    release_top=None; release_bottom=None
    observed_steps=0
    for step in sorted(bystep):
      xs=bystep[step]
      ev=next((x for x in xs if int(x["NODE"])==event_node),None)
      if ev is None: continue
      observed_steps+=1
      vals=[float(ev[k]) for k in ("H","THETA","THETA_S","DEFICIT","TOP_FLUX","BOTTOM_FLUX","POND")]
      if not all(math.isfinite(v) for v in vals): inconsistent=True
      h,th,ts=vals[0],vals[1],vals[2]
      sat_h=int(ev["SAT_H"])==1; sat_theta=int(ev["SAT_THETA"])==1
      if sat_h != sat_theta: inconsistent=True
      if release is None and h<0.0 and th<ts:
        release=step
        release_other_sat=any((int(q["SAT_H"])==1 or int(q["SAT_THETA"])==1) for q in xs if int(q["NODE"])!=event_node)
        release_route=ev["ROUTE"]; release_pond=float(ev["POND"])
        release_top=float(ev["TOP_FLUX"]); release_bottom=float(ev["BOTTOM_FLUX"])
    rec["observed_persistent_steps"]=observed_steps
    rec["indicator_inconsistent"]=inconsistent
    rec["release_observed"]=release is not None
    rec["release_step"]=release
    rec["release_other_node_saturated"]=release_other_sat
    rec["release_route"]=release_route
    rec["release_pond"]=release_pond
    rec["release_top_flux"]=release_top
    rec["release_bottom_flux"]=release_bottom
    rec["mass_ok"]=rec["max_ledger"]<=5e-8 and rec["cum_ledger"]<=5e-8
    rec["consistent_release"]=bool(release is not None and not inconsistent and not release_other_sat and
                                   rec["complete"] and rec["finite_final"] and rec["mass_ok"] and forcing_ok)
    rows.append(rec)

entered=[x for x in rows if x["entry_count"]==1]
release=[x for x in rows if x["consistent_release"]]
inconsistent=[x for x in rows if x["indicator_inconsistent"]]
coverage=(len(rows)==8 and proc==0 and len(entered)==8 and all(x["complete"] and x["finite_final"] for x in rows) and
          all(x["forcing_ok"] for x in rows))
if not coverage:
    cls="BLOCKED_NLGLOB14G_FORCING_REVERSAL"
elif inconsistent:
    cls="NLGLOB14G_RELEASE_STATE_INCONSISTENT"
elif len(release)==8:
    cls="NLGLOB14G_FORCING_REVERSAL_RELEASE_SIGNAL"
elif len(release)==0:
    cls="NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL"
else:
    cls="NLGLOB14G_MIXED_FORCING_REVERSAL_RELEASE"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "entry_cases":len(entered),"consistent_release_cases":len(release),
         "indicator_inconsistent_cases":len(inconsistent),
         "mass_ok":all(x["mass_ok"] for x in rows),
         "forcing_ok":all(x["forcing_ok"] for x in rows),
         "release_routes":sorted(set(x["release_route"] for x in release if x["release_route"])),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14G_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14G_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14G=PASS")
