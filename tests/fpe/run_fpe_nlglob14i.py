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
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
    forcing_ok=bool(forcing) and all(
      abs(float(f["PRECIP"]))<=1e-15 and math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12) and
      math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12) and f.get("PHASE")=="DRY"
      for f in forcing
    )
    bystep={}
    inconsistent=False; finite=True
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      vals=[float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
      finite=finite and all(math.isfinite(v) for v in vals)
      if (int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1): inconsistent=True

    steps=[]
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: continue
      sats=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      if sats:
        shallow=min(sats); deep=max(sats)
        contiguous=(deep==16 and sats==list(range(shallow,17)))
      else:
        shallow=0; deep=0; contiguous=True
      unsat=[int(x["NODE"]) for x in xs if not (int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1)]
      storage=10.0*sum(float(x["THETA"]) for x in xs)+float(xs[0]["POND"])
      steps.append({
        "step":step,"sat_count":len(sats),"shallow":shallow,"deep":deep,"contiguous_lower":contiguous,
        "unsat_above_count":sum(i < shallow for i in unsat) if shallow else len(unsat),
        "top_unsat":1 not in sats,"storage":storage,"pond":float(xs[0]["POND"]),
        "route":xs[0]["ROUTE"],"top_flux":float(xs[0]["TOP_FLUX"]),"bottom_flux":float(xs[0]["BOTTOM_FLUX"])
      })

    counts=[x["sat_count"] for x in steps]
    any_decrease=any(counts[i]<counts[i-1] for i in range(1,len(counts)))
    first_dec=next((i for i in range(1,len(counts)) if counts[i]<counts[i-1]),None)
    never_increase_after=True
    if first_dec is not None:
      never_increase_after=all(counts[i]<=counts[i-1] for i in range(first_dec+1,len(counts)))
    all_contig=all(x["contiguous_lower"] for x in steps)
    unchanged=bool(counts and all(x==counts[0] for x in counts))
    net_drying=bool(steps and steps[-1]["storage"]<steps[0]["storage"])
    top_unsat_final=bool(steps and steps[-1]["top_unsat"])

    cls="MIXED_SATURATED_SET_MIGRATION"
    if inconsistent:
      cls="SATURATION_INDICATOR_INCONSISTENT"
    elif any(not x["contiguous_lower"] for x in steps):
      cls="NONCONTIGUOUS_SATURATION_PATTERN"
    elif all_contig and any_decrease and never_increase_after and top_unsat_final and finite:
      cls="LOWER_BLOCK_RETREAT"
    elif all_contig and unchanged and net_drying:
      cls="LOWER_BLOCK_PERSISTENT"

    rec={"material":"O05","route":route,"dt":dt,"process_ok":cp.returncode==0,"entry_count":len(entries),
         "forcing_ok":forcing_ok,"observed_steps":len(steps),"finite":finite,"indicator_inconsistent":inconsistent,
         "classification":cls,"first_sat_count":counts[0] if counts else None,"last_sat_count":counts[-1] if counts else None,
         "min_sat_count":min(counts) if counts else None,"any_decrease":any_decrease,
         "never_increase_after_first_decrease":never_increase_after,"all_contiguous_lower":all_contig,
         "top_unsat_final":top_unsat_final,"net_profile_drying":net_drying,
         "storage_first":steps[0]["storage"] if steps else None,"storage_last":steps[-1]["storage"] if steps else None,
         "shallow_first":steps[0]["shallow"] if steps else None,"shallow_last":steps[-1]["shallow"] if steps else None,
         "route_first":steps[0]["route"] if steps else None,"route_last":steps[-1]["route"] if steps else None}
    if res:
      rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      rec["terminal_reason"]=res["TERMINAL_REASON"]
      rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
      rec["mass_ok"]=rec["max_ledger"]<=5e-8 and rec["cum_ledger"]<=5e-8
    else:
      rec["complete"]=False; rec["terminal_reason"]="MISSING_RESULT"; rec["mass_ok"]=False
      rec["max_ledger"]=math.inf; rec["cum_ledger"]=math.inf
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and x["finite"] and x["mass_ok"] and x["observed_steps"]>0 for x in rows))
counts={}
for x in rows: counts[x["classification"]]=counts.get(x["classification"],0)+1

if not coverage:
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

summary={"classification":overall,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "trajectory_counts":counts,"all_mass_ok":all(x["mass_ok"] for x in rows),
         "all_net_profile_drying":all(x["net_profile_drying"] for x in rows),
         "min_final_saturated_count":min((x["last_sat_count"] for x in rows if x["last_sat_count"] is not None),default=None),
         "max_final_saturated_count":max((x["last_sat_count"] for x in rows if x["last_sat_count"] is not None),default=None),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14I_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I=PASS")
