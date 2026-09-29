#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
 mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
 return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
 if r=="FLUX":
  h=-50.;p=0.;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=.25*(-q)
 elif r=="HEAD":
  h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
 else:
  h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
 return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def segments(stdout):
 segs=[]; cur=[]
 for line in stdout.splitlines():
  if not line.startswith("F_PE_TIMEINT17G_ITER|"): continue
  d=fields(line); rec={"iter":int(d["ITER"]),"route":d["ROUTE"],"eligible":int(d["ELIGIBLE"]),
      "fails":int(d["FAILS"]),"max_abs":float(d["MAX_ABS"]),"max_rel":float(d["MAX_REL"]),
      "worst_row":int(d["WORST_ROW"]),"worst_col":int(d["WORST_COL"])}
  if rec["iter"]==1 and cur:
   segs.append(cur); cur=[]
  cur.append(rec)
 if cur: segs.append(cur)
 return segs
def loc(row): return "TOP" if row==1 else ("BOTTOM" if row==16 else "INTERIOR")

rows=[]; audited=[]
for mid in ("B01","B12","O05","O14"):
 m=mats[mid]
 for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
   for mode in modes:
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    terminal=result["TERMINAL_REASON"] if result else "MISSING_RESULT"
    seg=segments(cp.stdout)
    last=seg[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and seg else []
    row={"material":mid,"route":route,"dt":dt,"mode":mode,"process_ok":cp.returncode==0,
         "terminal_reason":terminal,"audited_iterations":len(last),
         "failing_iterations":sum(x["fails"]>0 for x in last),
         "eligible_entries":sum(x["eligible"] for x in last),
         "failing_entries":sum(x["fails"] for x in last)}
    rows.append(row)
    for x in last:
      audited.append({"material":mid,"route":route,"dt":dt,"mode":mode,**x,"location":loc(x["worst_row"])})

eligible=[x for x in audited if x["eligible"]>0]
bad=[x for x in eligible if x["fails"]>0]
frac=len(bad)/len(eligible) if eligible else 1.0
route_set=sorted({x["route"] for x in eligible}); mat_set=sorted({x["material"] for x in eligible}); dt_set=sorted({x["dt"] for x in eligible})
coverage=(route_set==["FLUX","HEAD","RUNOFF"] and len(mat_set)>=3 and len(dt_set)>=3 and len(eligible)>=100)
loc_counts={k:sum(x["location"]==k for x in bad) for k in ("TOP","INTERIOR","BOTTOM")}
if not coverage: cls="BLOCKED_TIMEINT17G_FD_COVERAGE"
elif frac>=.25: cls="TIMEINT17G_FULL_JACOBIAN_MISMATCH"
elif frac<=.10: cls="TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER"
else: cls="TIMEINT17G_MIXED_JACOBIAN_SIGNAL"
localization=max(loc_counts,key=loc_counts.get) if bad else "NONE"
summary={"classification":cls,"coverage_ok":coverage,"eligible_audited_iterations":len(eligible),
 "failing_audited_iterations":len(bad),"failing_iteration_fraction":frac,"routes":route_set,"materials":mat_set,
 "dt_levels":dt_set,"mismatch_location_counts":loc_counts,"mismatch_localization":localization,
 "process_failures":sum(not x["process_ok"] for x in rows)}
print("F_PE_TIMEINT17G_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17G_AUDIT="+json.dumps(audited,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17G_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17G=PASS")
