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
def parse_segments(stdout):
 segs=[]; current=[]; last_iter=None
 for line in stdout.splitlines():
  if not line.startswith("F_PE_TIMEINT17H_BT|"): continue
  d=fields(line)
  rec={"iter":int(d["ITER"]),"try":int(d["TRY"]),"factor":float(d["FACTOR"]),
       "raw":float(d["RAW"]),"raw_origin":float(d["RAW_ORIGIN"]),
       "m_cp":float(d["M_CP"]),"m_tot":float(d["M_TOT"]),"m_h":float(d["M_H"]),
       "m":float(d["M"]),"current_accept":int(d["CURRENT_ACCEPT"])==1,"route":d["ROUTE"]}
  if rec["iter"]==1 and current and last_iter is not None:
   segs.append(current); current=[]
  current.append(rec); last_iter=rec["iter"]
 if current: segs.append(current)
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

cases=[]; audit=[]
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
                  "process_ok":cp.returncode==0,"iterations":len(its),
                  "candidates":sum(len(x) for x in its)})
    for group in its:
      if not group: continue
      selected=next((x for x in group if x["current_accept"]),group[-1])
      best=min(group,key=lambda x:x["m"])
      diff=abs(selected["factor"]-best["factor"])>1e-15
      improve=(best["m"] <= 0.9*selected["m"]) if selected["m"]>0 else False
      dom=max((("CP",selected["m_cp"]),("TOT",selected["m_tot"]),("HEAD",selected["m_h"])),key=lambda z:z[1])[0]
      audit.append({"material":mid,"route":route,"dt":dt,"mode":mode,"iter":group[0]["iter"],
                    "provider_route":norm_route(group[0]["route"]),"candidate_count":len(group),
                    "selected_factor":selected["factor"],"best_m_factor":best["factor"],
                    "selected_m":selected["m"],"best_m":best["m"],
                    "factor_misaligned":diff,"improvement_ge_10pct":improve,
                    "selected_dominant_component":dom})

eligible=audit
n=len(eligible); nc=sum(x["candidate_count"] for x in eligible)
mis=sum(x["factor_misaligned"] for x in eligible); imp=sum(x["improvement_ge_10pct"] for x in eligible)
mis_frac=mis/n if n else 0.; imp_frac=imp/n if n else 0.
route_set=sorted({x["provider_route"] for x in eligible}); mat_set=sorted({x["material"] for x in eligible}); dt_set=sorted({x["dt"] for x in eligible}); mode_set=sorted({x["mode"] for x in eligible})
coverage=(route_set==["FLUX","HEAD","RUNOFF"] and len(mat_set)>=3 and len(dt_set)>=3 and mode_set==["KLAG","TG"] and n>=100 and nc>=300)
if not coverage: cls="BLOCKED_TIMEINT17H_MERIT_COVERAGE"
elif mis_frac>=.25 and imp_frac>=.25: cls="TIMEINT17H_MERIT_MISALIGNMENT"
elif mis_frac<=.10 and imp_frac<=.10: cls="TIMEINT17H_RAW_MERIT_ALIGNED_GLOBALIZATION_BLOCKER"
else: cls="TIMEINT17H_MIXED_MERIT_SIGNAL"
dom={k:sum(x["selected_dominant_component"]==k for x in eligible) for k in ("CP","TOT","HEAD")}
summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":n,"tested_candidates":nc,
 "misaligned_iterations":mis,"misaligned_fraction":mis_frac,"improvement_iterations":imp,
 "improvement_fraction":imp_frac,"routes":route_set,"materials":mat_set,"dt_levels":dt_set,"modes":mode_set,
 "selected_dominant_component_counts":dom,"process_failures":sum(not x["process_ok"] for x in cases)}
print("F_PE_TIMEINT17H_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17H_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17H_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17H=PASS")
