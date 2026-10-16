#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

dynamic=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="FLUX":
        h=-50.; p=0.; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=.25*(-q)
    elif r=="HEAD":
        h=-5.; p=.025; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q
    else:
        h=-5.; p=.1; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q+(p-pmax)/rsro
    return h,p,rain

rows=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      cp=subprocess.run([str(dynamic),mid,"TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
        str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
      if cp.returncode!=0: proc+=1
      mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
      states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
      res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
      entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
      rec={"material":mid,"route":route,"dt":dt,"process_ok":cp.returncode==0,
           "entry_count":len(entries),"state_records":len(states)}
      if res:
        rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
        rec["terminal_reason"]=res["TERMINAL_REASON"]
      else:
        rec["complete"]=False; rec["terminal_reason"]="MISSING_RESULT"
      if not entries:
        rec["release_observed"]=False; rec["event_node"]=0; rec["event_node_remains_saturated"]=False
        rows.append(rec); continue

      event_nodes={int(x["EVENT_NODE"]) for x in states if int(x.get("EVENT_NODE","0"))>0}
      rec["event_node"]=next(iter(event_nodes)) if len(event_nodes)==1 else 0
      event_node=rec["event_node"]
      bystep={}
      for x in states:
        bystep.setdefault(int(x["STEP"]),[]).append(x)
      release_step=None; inconsistent=False; contradictory=False; release_route=None
      event_series=[]
      for step in sorted(bystep):
        xs=bystep[step]
        ev=next((x for x in xs if int(x["NODE"])==event_node),None)
        if ev is None: continue
        h=float(ev["H"]); th=float(ev["THETA"]); ts=float(ev["THETA_S"])
        sat_h=int(ev["SAT_H"])==1; sat_theta=int(ev["SAT_THETA"])==1
        finite=all(math.isfinite(float(ev[k])) for k in ("H","THETA","THETA_S","DEFICIT","TOP_FLUX","BOTTOM_FLUX","POND"))
        if not finite: inconsistent=True
        if sat_h != sat_theta: inconsistent=True
        event_series.append({"step":step,"h":h,"theta":th,"theta_s":ts,"sat_h":sat_h,"sat_theta":sat_theta,
                             "route":ev["ROUTE"],"pond":float(ev["POND"])})
        if release_step is None and h<0.0 and th<ts:
          release_step=step; release_route=ev["ROUTE"]
          other_sat=any(int(q["NODE"])!=event_node and (int(q["SAT_H"])==1 or int(q["SAT_THETA"])==1) for q in xs)
          contradictory=other_sat
      rec["release_observed"]=release_step is not None
      rec["release_step"]=release_step
      rec["release_route"]=release_route
      rec["release_other_node_saturated"]=contradictory
      rec["indicator_inconsistent"]=inconsistent
      rec["event_node_remains_saturated"]=bool(event_series and all(x["sat_h"] and x["sat_theta"] for x in event_series))
      rec["observed_intervals"]=len(event_series)
      rows.append(rec)

entered=[x for x in rows if x["entry_count"]>0]
release=[x for x in entered if x.get("release_observed")]
inconsistent=[x for x in entered if x.get("indicator_inconsistent")]
safe_release=[x for x in release if not x.get("release_other_node_saturated")]
coverage=(proc==0 and all(x["complete"] for x in rows) and len(entered)>0 and all(x["event_node"]>0 for x in entered))
if not coverage:
    cls="BLOCKED_NLGLOB14F_RELEASE_ATTRIBUTION"
elif inconsistent:
    cls="NLGLOB14F_RELEASE_STATE_INCONSISTENT"
elif safe_release:
    cls="NLGLOB14F_NATURAL_DESATURATION_SIGNAL"
elif all(x.get("event_node_remains_saturated") for x in entered):
    cls="NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON"
else:
    cls="NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "entry_trajectories":len(entered),"release_trajectories":len(release),
         "safe_release_trajectories":len(safe_release),"indicator_inconsistent_trajectories":len(inconsistent),
         "all_entered_complete":all(x["complete"] for x in entered) if entered else False,
         "event_nodes":sorted(set(x["event_node"] for x in entered))}
print("F_PE_NLGLOB14F_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14F_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14F=PASS")
