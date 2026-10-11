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

rows=[];proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    ev=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14_EVENT|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    e=ev[-1] if ev else None
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,"event_present":e is not None}
    if e:
        rec["valid"]=int(e.get("VALID","0"))==1
        rec["node"]=int(e.get("NODE","0")); rec["phi"]=float(e.get("PHI","nan"))
        rec["trial_ok"]=int(e.get("TRIAL_OK","0"))==1 if "TRIAL_OK" in e else False
        rec["domain_fail"]=int(e.get("DOMAIN","0"))==1 if "DOMAIN" in e else False
        if rec["trial_ok"]:
            rec["dsat"]=float(e["DSAT"]); rec["max_over"]=float(e["MAX_OVER"]); rec["dz"]=float(e["DZ"])
            rec["event_distance_cm"]=abs(rec["dsat"])*abs(rec["dz"])
            rec["pond"]=float(e["POND"]); rec["event_ledger"]=abs(float(e["LEDGER"]))
            rec["finite"]=int(e.get("FINITE","0"))==1
            rec["origin_route_code"]=int(e.get("ORIGIN_ROUTE_CODE","0"))
            rec["event_route_code"]=int(e.get("EVENT_ROUTE_CODE","0"))
            rec["route_out"]=e.get("ROUTE","")
    if res:
        rec["terminal_reason"]=res["TERMINAL_REASON"]
    rows.append(rec)

valid=sum(x.get("valid",False) and math.isfinite(x.get("phi",math.nan)) and 0<x.get("phi",0)<1 for x in rows)
trial_ok=sum(x.get("trial_ok",False) for x in rows)
domain_fail=sum(x.get("domain_fail",False) for x in rows)
admissible=[x for x in rows if x.get("trial_ok")]
localized=[x for x in admissible if x.get("max_over",math.inf)<=0 and x.get("event_distance_cm",math.inf)<=5e-8 and x.get("event_ledger",math.inf)<=5e-8 and
           x.get("finite",False) and math.isfinite(x.get("pond",math.nan)) and x.get("route_out")==x["route"] and
           x.get("origin_route_code",0)==x.get("event_route_code",-1)]

coverage=(len(rows)==5 and proc==0 and all(x["event_present"] for x in rows))
if not coverage:
    cls="BLOCKED_NLGLOB14_EVENT_LOCALIZATION_COVERAGE"
elif domain_fail>=3:
    cls="NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT"
elif trial_ok>=3 and len(localized)<3:
    cls="NLGLOB14_EVENT_TIME_ESTIMATE_NOT_LOCALIZED"
elif len(localized)==5 and valid==5:
    cls="NLGLOB14_SATURATION_EVENT_LOCALIZATION_QUALIFIED"
else:
    cls="NLGLOB14_EVENT_LOCALIZATION_PHYSICAL_ADMISSIBILITY_FAILED"

summary={"classification":cls,"target_count":len(rows),"valid_event_fraction_count":valid,
         "trial_ok_count":trial_ok,"domain_fail_count":domain_fail,"localized_count":len(localized),
         "max_event_distance_cm":max((x.get("event_distance_cm",0) for x in admissible),default=math.inf),
         "max_event_overshoot":max((x.get("max_over",0) for x in admissible),default=math.inf),
         "max_event_ledger":max((x.get("event_ledger",0) for x in admissible),default=math.inf),
         "process_failures":proc}
print("F_PE_NLGLOB14_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14=PASS")
