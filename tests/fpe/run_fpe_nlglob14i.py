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
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    forcing=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14G_FORCING|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    bystep={}
    inconsistent=False; finite=True
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1): inconsistent=True
      finite=finite and all(math.isfinite(float(x[k])) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX"))
    series=[]
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda x:int(x["NODE"]))
      if len(xs)!=16: finite=False; continue
      sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      contiguous=True
      if sat:
        contiguous=(sat==list(range(min(sat),17)))
        shallow=min(sat); deep=max(sat)
      else:
        shallow=0; deep=0
      pond=float(xs[0]["POND"])
      storage=10.0*sum(float(x["THETA"]) for x in xs)+pond
      series.append({"step":step,"sat_count":len(sat),"shallow":shallow,"deep":deep,
                     "contiguous_lower":contiguous,"unsat_above":(shallow-1 if sat else 16),
                     "top_unsat":1 not in sat,"pond":pond,"storage":storage,
                     "route":xs[0]["ROUTE"],"top_flux":float(xs[0]["TOP_FLUX"]),"bottom_flux":float(xs[0]["BOTTOM_FLUX"])})

    forcing_ok=bool(forcing) and all(abs(float(f["PRECIP"]))<=1e-15 and
      math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12) and
      math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12) and f.get("PHASE")=="DRY" for f in forcing)
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxled=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumled=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxled<=5e-8 and cumled<=5e-8
    valid=complete and finite and not inconsistent and forcing_ok and mass_ok and len(series)>1

    counts=[x["sat_count"] for x in series]
    first_decrease=None
    for i in range(1,len(counts)):
      if counts[i]<counts[i-1]:
        first_decrease=i; break
    never_increase_after=True
    if first_decrease is not None:
      never_increase_after=all(counts[i]<=counts[i-1] for i in range(first_decrease+1,len(counts)))
    contiguous_all=all(x["contiguous_lower"] for x in series)
    dS=series[-1]["storage"]-series[0]["storage"] if series else math.nan
    retreat=valid and contiguous_all and first_decrease is not None and never_increase_after and series[-1]["top_unsat"]
    persistent=valid and contiguous_all and len(set(counts))==1 and dS<0

    if not valid:
      cls="INVALID"
    elif inconsistent:
      cls="SATURATION_INDICATOR_INCONSISTENT"
    elif not contiguous_all:
      cls="NONCONTIGUOUS_SATURATION_PATTERN"
    elif retreat:
      cls="LOWER_BLOCK_RETREAT"
    elif persistent:
      cls="LOWER_BLOCK_PERSISTENT"
    else:
      cls="MIXED_SATURATED_SET_MIGRATION"

    rows.append({"material":"O05","route":route,"dt":dt,"valid":valid,"classification":cls,
                 "initial_sat_count":counts[0] if counts else None,"final_sat_count":counts[-1] if counts else None,
                 "min_sat_count":min(counts) if counts else None,"max_sat_count":max(counts) if counts else None,
                 "first_decrease_index":first_decrease,"never_increase_after_first_decrease":never_increase_after,
                 "contiguous_lower_all":contiguous_all,"final_top_unsat":series[-1]["top_unsat"] if series else False,
                 "initial_shallow":series[0]["shallow"] if series else None,"final_shallow":series[-1]["shallow"] if series else None,
                 "delta_storage":dS,"pond_first":series[0]["pond"] if series else None,"pond_last":series[-1]["pond"] if series else None,
                 "route_first":series[0]["route"] if series else None,"route_last":series[-1]["route"] if series else None,
                 "max_ledger":maxled,"cum_ledger":cumled,"forcing_ok":forcing_ok,
                 "indicator_inconsistent":inconsistent,"process_ok":cp.returncode==0})

counts={}
for x in rows: counts[x["classification"]]=counts.get(x["classification"],0)+1
if proc or any(not x["valid"] for x in rows):
  overall="BLOCKED_NLGLOB14I_SATURATED_SET_ATTRIBUTION"
elif counts.get("SATURATION_INDICATOR_INCONSISTENT",0)>0:
  overall="NLGLOB14I_SATURATION_INDICATOR_INCONSISTENT"
elif counts.get("NONCONTIGUOUS_SATURATION_PATTERN",0)>0:
  overall="NLGLOB14I_NONCONTIGUOUS_SATURATION_PATTERN"
elif counts.get("LOWER_BLOCK_RETREAT",0)==8:
  overall="NLGLOB14I_LOWER_SATURATED_BLOCK_RETREATS"
elif counts.get("LOWER_BLOCK_PERSISTENT",0)==8:
  overall="NLGLOB14I_LOWER_SATURATED_BLOCK_PERSISTS"
else:
  overall="NLGLOB14I_MIXED_SATURATED_SET_MIGRATION"

summary={"classification":overall,"coverage_ok":proc==0 and all(x["valid"] for x in rows),
         "case_count":len(rows),"counts":counts,"process_failures":proc,
         "all_mass_ok":all(x["max_ledger"]<=5e-8 and x["cum_ledger"]<=5e-8 for x in rows),
         "all_contiguous_lower":all(x["contiguous_lower_all"] for x in rows),
         "min_final_sat_count":min((x["final_sat_count"] for x in rows),default=None),
         "max_final_sat_count":max((x["final_sat_count"] for x in rows),default=None)}
print("F_PE_NLGLOB14I_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I=PASS")
