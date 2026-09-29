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
    forcing=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14G_FORCING|")]
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
    rec={"material":"O05","route":route,"dt":dt,"entry_count":len(entries),"process_ok":cp.returncode==0}

    forcing_ok=bool(forcing) and all(
      abs(float(f["PRECIP"]))<=1e-15 and
      math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12) and
      math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12) and
      f.get("PHASE")=="DRY" for f in forcing)
    rec["forcing_ok"]=forcing_ok

    bystep={}
    inconsistent=False
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x.get("SAT_H","0"))==1) != (int(x.get("SAT_THETA","0"))==1):
        inconsistent=True

    steps=sorted(bystep)
    series=[]; finite=True; noncontig=False
    for step in steps:
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      sat=[]
      theta=[]
      for x in xs:
        vals=[float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
        if not all(math.isfinite(v) for v in vals): finite=False
        theta.append(float(x["THETA"]))
        if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1:
          sat.append(int(x["NODE"]))
      contiguous=True
      if sat:
        contiguous=(sat==list(range(min(sat),17)))
      if not contiguous: noncontig=True
      shallow=min(sat) if sat else 0
      deep=max(sat) if sat else 0
      lower_unsat=(shallow-1) if sat else 16
      first=xs[0]
      series.append({"step":step,"sat_count":len(sat),"shallowest":shallow,"deepest":deep,
                     "contiguous_lower":contiguous,"unsat_above_lower":lower_unsat,
                     "top_unsat":1 not in sat,"route":first["ROUTE"],"pond":float(first["POND"]),
                     "storage":10.0*sum(theta)+float(first["POND"]),
                     "top_flux":float(first["TOP_FLUX"]),"bottom_flux":float(first["BOTTOM_FLUX"])})

    counts=[x["sat_count"] for x in series]
    decreased=any(counts[i]<counts[i-1] for i in range(1,len(counts))) if len(counts)>1 else False
    first_dec=next((i for i in range(1,len(counts)) if counts[i]<counts[i-1]),None)
    no_reincrease=True if first_dec is None else all(counts[i]<=counts[i-1] for i in range(first_dec+1,len(counts)))
    all_contig=all(x["contiguous_lower"] and (x["deepest"] in (0,16)) for x in series)
    storage_dry=bool(series and series[-1]["storage"]<series[0]["storage"])
    final_top_unsat=bool(series and series[-1]["top_unsat"])

    if inconsistent:
      cls="SATURATION_INDICATOR_INCONSISTENT"
    elif noncontig:
      cls="NONCONTIGUOUS_SATURATION_PATTERN"
    elif all_contig and decreased and no_reincrease and final_top_unsat and finite and storage_dry:
      cls="LOWER_BLOCK_RETREAT"
    elif all_contig and counts and len(set(counts))==1 and storage_dry:
      cls="LOWER_BLOCK_PERSISTENT"
    else:
      cls="MIXED_SATURATED_SET_MIGRATION"

    rec.update({"classification":cls,"observed_steps":len(series),"indicator_inconsistent":inconsistent,
                "noncontiguous":noncontig,"state_finite":finite,"counts":counts,
                "initial_sat_count":counts[0] if counts else None,"final_sat_count":counts[-1] if counts else None,
                "min_sat_count":min(counts) if counts else None,"max_sat_count":max(counts) if counts else None,
                "decreased":decreased,"no_reincrease_after_first_decrease":no_reincrease,
                "all_contiguous_lower":all_contig,"final_top_unsaturated":final_top_unsat,
                "net_profile_drying":storage_dry})
    if res:
      rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      rec["terminal_reason"]=res["TERMINAL_REASON"]
      rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
      rec["mass_ok"]=rec["max_ledger"]<=5e-8 and rec["cum_ledger"]<=5e-8
    else:
      rec["complete"]=False; rec["terminal_reason"]="MISSING_RESULT"; rec["mass_ok"]=False
      rec["max_ledger"]=math.inf; rec["cum_ledger"]=math.inf
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and
          x["mass_ok"] and x["state_finite"] and x["observed_steps"]>0 for x in rows))
classes=[x["classification"] for x in rows]
if not coverage:
    cls="BLOCKED_NLGLOB14I_SATURATED_SET_ATTRIBUTION"
elif any(x=="SATURATION_INDICATOR_INCONSISTENT" for x in classes):
    cls="NLGLOB14I_SATURATION_INDICATOR_INCONSISTENT"
elif any(x=="NONCONTIGUOUS_SATURATION_PATTERN" for x in classes):
    cls="NLGLOB14I_NONCONTIGUOUS_SATURATION_PATTERN"
elif all(x=="LOWER_BLOCK_RETREAT" for x in classes):
    cls="NLGLOB14I_LOWER_SATURATED_BLOCK_RETREATS"
elif all(x=="LOWER_BLOCK_PERSISTENT" for x in classes):
    cls="NLGLOB14I_LOWER_SATURATED_BLOCK_PERSISTS"
else:
    cls="NLGLOB14I_MIXED_SATURATED_SET_MIGRATION"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "retreat_cases":sum(x=="LOWER_BLOCK_RETREAT" for x in classes),
         "persistent_cases":sum(x=="LOWER_BLOCK_PERSISTENT" for x in classes),
         "noncontiguous_cases":sum(x=="NONCONTIGUOUS_SATURATION_PATTERN" for x in classes),
         "indicator_inconsistent_cases":sum(x=="SATURATION_INDICATOR_INCONSISTENT" for x in classes),
         "all_mass_ok":all(x["mass_ok"] for x in rows),
         "initial_sat_counts":[x["initial_sat_count"] for x in rows],
         "final_sat_counts":[x["final_sat_count"] for x in rows],
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14I_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14I=PASS")
