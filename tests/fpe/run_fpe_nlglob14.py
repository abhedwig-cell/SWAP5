#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
targets=[
 ("O05","TG","HEAD",0.00025),
 ("O05","TG","HEAD",0.000125),
 ("O05","TG","HEAD",0.0000625),
 ("O05","TG","RUNOFF",0.00025),
 ("O05","TG","RUNOFF",0.000125),
]
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    ev=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14_EVENT|")]
    tr=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14_TRIAL|")]
    e=ev[-1] if ev else None; t=tr[-1] if tr else None
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,
         "event_found":e is not None,"trial_found":t is not None}
    if e is not None:
        rec["event_valid"]=int(e["VALID"])==1
        if rec["event_valid"]:
            rec["phi"]=float(e["PHI"]); rec["node"]=int(e["NODE"])
    if t is not None:
        rec["trial_ok"]=int(t["OK"])==1
        if rec["trial_ok"]:
            rec["theta_event"]=float(t["THETA_EVENT"]); rec["ts"]=float(t["TS"])
            rec["dsat"]=float(t["DSAT"]); rec["dz"]=float(t["DZ"])
            rec["event_water_depth_distance"]=abs(rec["dsat"])*abs(rec["dz"])
            rec["overshoot"]=float(t["OVERSHOOT"]); rec["ledger"]=abs(float(t["LEDGER"]))
            rec["pond"]=float(t["POND"]); rec["accept_route_code"]=int(t["ACCEPT_ROUTE_CODE"])
            rec["finite"]=all(math.isfinite(rec[k]) for k in ("theta_event","ts","dsat","dz","overshoot","ledger","pond"))
    rows.append(rec)

valid=[x for x in rows if x.get("event_valid") and 0<x.get("phi",0)<1]
trial_ok=[x for x in rows if x.get("trial_ok")]
inadmissible=sum((not x.get("trial_ok",False)) or x.get("overshoot",0)>0 for x in rows)
localized=[x for x in trial_ok if x.get("overshoot",1)==0 and
           x.get("event_water_depth_distance",math.inf)<=5e-8 and x.get("ledger",math.inf)<=5e-8 and
           x.get("finite",False) and x.get("accept_route_code",0) in (1,2,3)]

coverage=(proc==0 and len(rows)==5 and len(valid)==5 and len(trial_ok)==5)
if not coverage:
    cls="BLOCKED_NLGLOB14_EVENT_LOCALIZATION_COVERAGE"
elif any((not x.get("finite",False)) or x.get("ledger",math.inf)>5e-8 or x.get("accept_route_code",0) not in (1,2,3) for x in trial_ok):
    cls="NLGLOB14_EVENT_LOCALIZATION_PHYSICAL_ADMISSIBILITY_FAILED"
elif inadmissible>=3:
    cls="NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT"
elif len(localized)<3:
    cls="NLGLOB14_EVENT_TIME_ESTIMATE_NOT_LOCALIZED"
elif len(localized)==5:
    cls="NLGLOB14_SATURATION_EVENT_LOCALIZATION_QUALIFIED"
else:
    cls="NLGLOB14_EVENT_TIME_ESTIMATE_NOT_LOCALIZED"

summary={"classification":cls,"coverage_ok":coverage,"target_count":len(rows),
         "valid_event_fractions":len(valid),"successful_event_trials":len(trial_ok),
         "localized_count":len(localized),"inadmissible_count":inadmissible,
         "process_failures":proc,
         "max_event_water_depth_distance":max((x.get("event_water_depth_distance",0) for x in trial_ok),default=0),
         "max_event_ledger":max((x.get("ledger",0) for x in trial_ok),default=0)}
print("F_PE_NLGLOB14_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14=PASS")
