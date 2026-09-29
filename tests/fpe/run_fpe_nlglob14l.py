#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.05; dtop=10.; pmax=.05; rsro=.05

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
    rec={"material":"O05","route":route,"dt":dt,"entry_count":len(entries),"process_ok":cp.returncode==0}

    forcing_ok=bool(forcing) and all(
      abs(float(f["PRECIP"]))<=1e-15 and
      math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12) and
      math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12) and f.get("PHASE")=="DRY" for f in forcing)
    rec["forcing_ok"]=forcing_ok

    bystep={}
    inconsistent=False
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1):
        inconsistent=True

    series=[]; finite=True; noncontig=False
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      vals=[]
      sat=[]
      thetas=[]
      for x in xs:
        vv=[float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
        vals.extend(vv); thetas.append(float(x["THETA"]))
        if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1:
          sat.append(int(x["NODE"]))
      if not all(math.isfinite(v) for v in vals): finite=False
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: noncontig=True
      first=xs[0]
      series.append({"step":step,"time":step*dt,"sat_count":len(sat),
                     "shallowest":min(sat) if sat else 0,"deepest":max(sat) if sat else 0,
                     "contiguous":contiguous,"top_unsat":1 not in sat,
                     "route":first["ROUTE"],"pond":float(first["POND"]),
                     "storage":10.0*sum(thetas)+float(first["POND"]),
                     "top_flux":float(first["TOP_FLUX"]),"bottom_flux":float(first["BOTTOM_FLUX"])})

    counts=[x["sat_count"] for x in series]
    initial=counts[0] if counts else None
    peak=max(counts) if counts else None
    peak_idx=[i for i,v in enumerate(counts) if v==peak] if counts else []
    first_peak=peak_idx[0] if peak_idx else None
    last_peak=peak_idx[-1] if peak_idx else None
    first_decline=next((i for i in range((last_peak+1) if last_peak is not None else 0,len(counts)) if counts[i]<peak),None)
    first_zero=next((i for i,v in enumerate(counts) if v==0),None)
    final=counts[-1] if counts else None
    expanded=bool(counts and peak>initial)
    retreated=bool(counts and final<peak)
    full_desat=first_zero is not None
    post_peak_decrease=first_decline is not None
    storage_dry=bool(series and series[-1]["storage"]<series[0]["storage"])

    complete=False; mass_ok=False; maxledger=math.inf; cumledger=math.inf; terminal="MISSING_RESULT"
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      terminal=res["TERMINAL_REASON"]; maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    if inconsistent or noncontig or not finite or not mass_ok:
      cls="NONCONTIGUOUS_OR_INCONSISTENT"
    elif expanded and post_peak_decrease and full_desat and complete:
      cls="FULL_DESATURATION_AFTER_PEAK"
    elif expanded and retreated and final>0 and complete:
      cls="PARTIAL_RETREAT_AFTER_PEAK"
    elif expanded and final==peak and not post_peak_decrease and complete:
      cls="NO_RETREAT_WITHIN_FIXED_HORIZON"
    else:
      cls="MIXED_EXTENDED_HORIZON_EVOLUTION"

    rec.update({"classification":cls,"state_finite":finite,"indicator_inconsistent":inconsistent,
                "noncontiguous":noncontig,"observed_steps":len(series),"initial_sat_count":initial,
                "max_sat_count":peak,"final_sat_count":final,"expanded":expanded,"retreated":retreated,
                "full_desaturation":full_desat,
                "first_peak_step":series[first_peak]["step"] if first_peak is not None else None,
                "first_peak_time":series[first_peak]["time"] if first_peak is not None else None,
                "last_peak_step":series[last_peak]["step"] if last_peak is not None else None,
                "last_peak_time":series[last_peak]["time"] if last_peak is not None else None,
                "first_decline_step":series[first_decline]["step"] if first_decline is not None else None,
                "first_decline_time":series[first_decline]["time"] if first_decline is not None else None,
                "first_zero_step":series[first_zero]["step"] if first_zero is not None else None,
                "first_zero_time":series[first_zero]["time"] if first_zero is not None else None,
                "net_profile_drying":storage_dry,"complete":complete,"terminal_reason":terminal,
                "mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger})
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and
          x["mass_ok"] and x["state_finite"] and x["observed_steps"]>0 for x in rows))
classes=[x["classification"] for x in rows]
full=sum(x=="FULL_DESATURATION_AFTER_PEAK" for x in classes)
retreat=sum(x in ("FULL_DESATURATION_AFTER_PEAK","PARTIAL_RETREAT_AFTER_PEAK") for x in classes)
if not coverage:
    cls="BLOCKED_NLGLOB14L_EXTENDED_HORIZON"
elif any(x=="NONCONTIGUOUS_OR_INCONSISTENT" for x in classes):
    cls="NLGLOB14L_EXTENDED_HORIZON_STATE_INCONSISTENT"
elif full==8:
    cls="NLGLOB14L_FULL_DESATURATION_OBSERVED"
elif retreat==8 and full>=4:
    cls="NLGLOB14L_SATURATED_BLOCK_RETREAT_CONFIRMED"
elif all(x=="NO_RETREAT_WITHIN_FIXED_HORIZON" for x in classes):
    cls="NLGLOB14L_NO_RETREAT_WITHIN_0P05D"
else:
    cls="NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "full_desaturation_cases":full,"retreat_cases":retreat,
         "no_retreat_cases":sum(x=="NO_RETREAT_WITHIN_FIXED_HORIZON" for x in classes),
         "inconsistent_cases":sum(x=="NONCONTIGUOUS_OR_INCONSISTENT" for x in classes),
         "initial_sat_counts":[x["initial_sat_count"] for x in rows],
         "max_sat_counts":[x["max_sat_count"] for x in rows],
         "final_sat_counts":[x["final_sat_count"] for x in rows],
         "first_zero_times":[x["first_zero_time"] for x in rows],
         "all_mass_ok":all(x["mass_ok"] for x in rows),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14L_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14L_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14L=PASS")
