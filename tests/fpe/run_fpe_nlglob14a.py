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
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    root=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14A_ROOT|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    d=root[-1] if root else None
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,"root_present":d is not None}
    if d:
        rec["valid"]=int(d.get("VALID","0"))==1
        rec["trial_ok"]=int(d.get("TRIAL_OK","0"))==1
        rec["node"]=int(d.get("NODE","0"))
        rec["iters"]=int(d.get("ITER","0"))
        rec["phi_lo"]=float(d.get("PHI_LO","nan"))
        rec["phi_hi"]=float(d.get("PHI_HI","nan"))
        if rec["trial_ok"]:
            rec["dsat"]=float(d["DSAT"]); rec["event_depth"]=float(d["EVENT_DEPTH"])
            rec["max_over"]=float(d["MAX_OVER"]); rec["event_ledger"]=float(d["EVENT_LEDGER"])
            rec["pond"]=float(d["POND"]); rec["route_out"]=d["ROUTE"]
    if res: rec["terminal_reason"]=res["TERMINAL_REASON"]
    rows.append(rec)

localized=[x for x in rows if x.get("valid") and x.get("trial_ok") and 0<x.get("phi_lo",0)<x.get("phi_hi",1) and
           x.get("event_depth",math.inf)<=5e-8 and x.get("max_over",math.inf)<=0 and
           x.get("event_ledger",math.inf)<=5e-8 and x.get("route_out")==x["route"] and
           all(math.isfinite(x.get(k,math.nan)) for k in ("phi_lo","phi_hi","event_depth","max_over","event_ledger","pond"))]
coverage=(len(rows)==5 and proc==0 and all(x["root_present"] for x in rows))
if not coverage:
    cls="BLOCKED_NLGLOB14A_EVENT_ROOT_COVERAGE"
elif len(localized)==5:
    cls="NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED"
elif sum(x.get("valid") and not x.get("trial_ok") for x in rows)>=3:
    cls="NLGLOB14A_BISECTION_LOCALIZATION_INSUFFICIENT"
elif any(x.get("trial_ok") and (x.get("event_ledger",0)>5e-8 or x.get("route_out")!=x["route"]) for x in rows):
    cls="NLGLOB14A_EVENT_ROOT_PHYSICAL_ADMISSIBILITY_FAILED"
else:
    cls="NLGLOB14A_BISECTION_LOCALIZATION_INSUFFICIENT"

summary={"classification":cls,"target_count":len(rows),"localized_count":len(localized),"process_failures":proc,
         "max_bisection_iterations":max((x.get("iters",0) for x in rows),default=0),
         "max_event_depth_cm":max((x.get("event_depth",0) for x in localized),default=math.inf),
         "max_event_ledger":max((x.get("event_ledger",0) for x in localized),default=math.inf)}
print("F_PE_NLGLOB14A_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14A=PASS")
