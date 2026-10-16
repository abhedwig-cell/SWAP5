#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
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
def parse_segments(stdout):
 segs=[]; cur=[]
 for line in stdout.splitlines():
  if not line.startswith("F_PE_TIMEINT17H_BT|"): continue
  d=fields(line)
  rec={"iter":int(d["ITER"]),"try":int(d["TRY"]),"factor":float(d["FACTOR"]),
       "raw":float(d["RAW"]),"raw_origin":float(d["RAW_ORIGIN"]),
       "current_accept":int(d["CURRENT_ACCEPT"])==1,"route":d["ROUTE"]}
  if rec["iter"]==1 and cur:
   segs.append(cur); cur=[]
  cur.append(rec)
 if cur: segs.append(cur)
 return segs
def split_iterations(seg):
 out=[]; cur=[]; it=None
 for x in seg:
  if it is None or x["iter"]==it:
   cur.append(x); it=x["iter"]
  else:
   out.append(cur); cur=[x]; it=x["iter"]
 if cur: out.append(cur)
 return out
def norm_route(r):
 return {"surface-flux":"FLUX","ponded-head":"HEAD","ponded-head-linear-runoff":"RUNOFF"}.get(r,r)
def rho(x):
 a=x["factor"]; p=x["raw_origin"]*(2*a-a*a)
 if not math.isfinite(p) or p<=0: return None
 return (x["raw_origin"]-x["raw"])/p

audit=[]; cases=[]
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
    segs=parse_segments(cp.stdout)
    terminal_seg=segs[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and segs else []
    its=split_iterations(terminal_seg)
    cases.append({"material":mid,"route":route,"dt":dt,"mode":mode,"terminal_reason":terminal,
                  "process_ok":cp.returncode==0,"iterations":len(its),"candidates":sum(len(x) for x in its)})
    for group in its:
      if not group: continue
      selected=next((x for x in group if x["current_accept"]),group[-1])
      rs=[(x,rho(x)) for x in group if rho(x) is not None and math.isfinite(rho(x))]
      selected_rho=rho(selected)
      positives=[(x,r) for x,r in rs if x["raw"] < x["raw_origin"]]
      best=max(positives,key=lambda q:q[1]) if positives else (None,None)
      full=next((x for x in group if abs(x["factor"]-1.0)<1e-15),None)
      full_rho=rho(full) if full else None
      smaller_better=False
      if selected_rho is not None:
       for x,r in positives:
        if x["factor"] < selected["factor"] and r >= selected_rho + 0.25:
         smaller_better=True; break
      audit.append({"material":mid,"route":route,"provider_route":norm_route(group[0]["route"]),
                    "dt":dt,"mode":mode,"iter":group[0]["iter"],"candidate_count":len(group),
                    "selected_factor":selected["factor"],"selected_rho":selected_rho,
                    "best_positive_rho":best[1],"full_rho":full_rho,
                    "smaller_improves_rho_ge_0p25":smaller_better})

eligible=[x for x in audit if x["selected_rho"] is not None and math.isfinite(x["selected_rho"])]
n=len(eligible); nc=sum(x["candidate_count"] for x in eligible)
neg=sum(x["selected_rho"]<0 for x in eligible); poor=sum(x["selected_rho"]<0.25 for x in eligible)
fullneg=sum(x["full_rho"] is not None and x["full_rho"]<0 for x in eligible)
better=sum(x["smaller_improves_rho_ge_0p25"] for x in eligible)
poor_frac=poor/n if n else 0.; better_frac=better/n if n else 0.
route_set=sorted({x["provider_route"] for x in eligible}); mat_set=sorted({x["material"] for x in eligible}); dt_set=sorted({x["dt"] for x in eligible}); mode_set=sorted({x["mode"] for x in eligible})
coverage=(route_set==["FLUX","HEAD","RUNOFF"] and len(mat_set)>=3 and len(dt_set)>=3 and mode_set==["KLAG","TG"] and n>=100 and nc>=300)
if not coverage: cls="BLOCKED_TIMEINT17I_MODEL_QUALITY_COVERAGE"
elif poor_frac>=.25 and better_frac>=.25: cls="TIMEINT17I_TRUST_REGION_SIGNAL"
elif poor_frac<=.10: cls="TIMEINT17I_LOCAL_MODEL_ADEQUATE_OTHER_GLOBALIZATION_BLOCKER"
else: cls="TIMEINT17I_MIXED_MODEL_QUALITY"

def median(vals):
 v=sorted(x for x in vals if x is not None and math.isfinite(x))
 if not v:return None
 n=len(v); return v[n//2] if n%2 else .5*(v[n//2-1]+v[n//2])
by={}
for route in routes:
 for mode in modes:
  xs=[x for x in eligible if x["provider_route"]==route and x["mode"]==mode]
  if not xs: continue
  by[f"{route}|{mode}"]={"n":len(xs),"selected_rho_lt_0p25_fraction":sum(x["selected_rho"]<.25 for x in xs)/len(xs),
    "selected_rho_negative_fraction":sum(x["selected_rho"]<0 for x in xs)/len(xs),
    "smaller_improves_fraction":sum(x["smaller_improves_rho_ge_0p25"] for x in xs)/len(xs),
    "median_selected_rho":median([x["selected_rho"] for x in xs])}
summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":n,"tested_candidates":nc,
 "selected_rho_negative_fraction":neg/n if n else 0.,"selected_rho_lt_0p25_fraction":poor_frac,
 "full_step_rho_negative_fraction":fullneg/n if n else 0.,"smaller_improves_rho_fraction":better_frac,
 "median_selected_rho":median([x["selected_rho"] for x in eligible]),"routes":route_set,"materials":mat_set,
 "dt_levels":dt_set,"modes":mode_set,"route_mode":by,"process_failures":sum(not x["process_ok"] for x in cases)}
print("F_PE_TIMEINT17I_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17I_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17I_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17I=PASS")
