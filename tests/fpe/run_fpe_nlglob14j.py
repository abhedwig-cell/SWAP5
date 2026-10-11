#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.012; dtop=10.; pmax=.05; rsro=.05; dz=10.0; distance=10.0

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    if h>=0.0: return m["ksat"]
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
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    forcing=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14G_FORCING|")]
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
      if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1): inconsistent=True

    series=[]; finite=True; noncontig=False
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      heads=[float(x["H"]) for x in xs]; thetas=[float(x["THETA"]) for x in xs]
      if not all(math.isfinite(v) for v in heads+thetas): finite=False
      sat=[i+1 for i,x in enumerate(xs) if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: noncontig=True
      s=min(sat) if sat else 0
      qedge=None; qdown=None
      if s>1:
        iu=s-2; il=s-1
        ku=kvg(m,heads[iu]); kl=kvg(m,heads[il]); km=.5*(ku+kl)
        grad=(heads[iu]-heads[il])/distance+1.0
        qedge=-km*grad
        qdown=-qedge
        if not math.isfinite(qedge): finite=False
      pond=float(xs[0]["POND"]); top=float(xs[0]["TOP_FLUX"]); bottom=float(xs[0]["BOTTOM_FLUX"])
      upper_dynamic=dz*sum(thetas[:s-1]) if s>1 else 0.0
      lower_dynamic=dz*sum(thetas[s-1:]) if s>0 else 0.0
      upper_fixed=dz*sum(thetas[:2]); lower_fixed=dz*sum(thetas[2:])
      total=dz*sum(thetas)+pond
      series.append({"step":step,"sat_count":len(sat),"edge_node":s,"q_edge":qedge,"q_down_edge":qdown,
                     "upper_dynamic_storage":upper_dynamic,"lower_dynamic_storage":lower_dynamic,
                     "upper_fixed_storage":upper_fixed,"lower_fixed_storage":lower_fixed,
                     "total_storage":total,"top_flux":top,"bottom_flux":bottom,"pond":pond,
                     "contiguous":contiguous})

    expansion=[]
    for i in range(1,len(series)):
      if series[i]["sat_count"]>series[i-1]["sat_count"]:
        expansion.append(series[i])

    downward=[x for x in expansion if x["q_down_edge"] is not None and x["q_down_edge"]>0.0]
    down_frac=len(downward)/len(expansion) if expansion else 0.0
    if series:
      du=series[-1]["upper_fixed_storage"]-series[0]["upper_fixed_storage"]
      dl=series[-1]["lower_fixed_storage"]-series[0]["lower_fixed_storage"]
      dtot=series[-1]["total_storage"]-series[0]["total_storage"]
      max_bottom=max(abs(x["bottom_flux"]) for x in series)
      expanded=series[-1]["sat_count"]>series[0]["sat_count"]
    else:
      du=dl=dtot=math.nan; max_bottom=math.inf; expanded=False

    mass_ok=False; complete=False; terminal="MISSING_RESULT"; maxledger=math.inf; cumledger=math.inf
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      terminal=res["TERMINAL_REASON"]; maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    if inconsistent or noncontig or not finite:
      cls="INTERNAL_FLUX_STATE_INCONSISTENT"
    elif expanded and dl>0 and du<0 and down_frac>=.90 and max_bottom<=5e-8 and mass_ok:
      cls="DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION"
    elif expanded and dl<=0:
      cls="LOWER_REGION_DOES_NOT_GAIN_STORAGE"
    elif expanded and down_frac<.90:
      cls="BLOCK_EXPANSION_WITHOUT_DOWNWARD_EDGE_SUPPLY"
    else:
      cls="MIXED_BLOCK_REDISTRIBUTION"

    rec.update({"classification":cls,"state_finite":finite,"indicator_inconsistent":inconsistent,
                "noncontiguous":noncontig,"observed_steps":len(series),"expansion_intervals":len(expansion),
                "downward_expansion_intervals":len(downward),"downward_expansion_fraction":down_frac,
                "delta_storage_upper_fixed":du,"delta_storage_lower_fixed":dl,"delta_storage_total":dtot,
                "max_abs_bottom_flux":max_bottom,"expanded":expanded,
                "complete":complete,"terminal_reason":terminal,"mass_ok":mass_ok,
                "max_ledger":maxledger,"cum_ledger":cumledger})
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and
          x["mass_ok"] and x["state_finite"] and x["observed_steps"]>0 for x in rows))
classes=[x["classification"] for x in rows]
if not coverage:
    cls="BLOCKED_NLGLOB14J_BLOCK_REDISTRIBUTION"
elif any(x=="INTERNAL_FLUX_STATE_INCONSISTENT" for x in classes):
    cls="NLGLOB14J_INTERNAL_FLUX_STATE_INCONSISTENT"
elif all(x=="DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION" for x in classes):
    cls="NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION"
elif all(x=="BLOCK_EXPANSION_WITHOUT_DOWNWARD_EDGE_SUPPLY" for x in classes):
    cls="NLGLOB14J_BLOCK_EXPANSION_NOT_EXPLAINED_BY_EDGE_FLUX"
else:
    cls="NLGLOB14J_MIXED_BLOCK_REDISTRIBUTION"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "downward_redistribution_cases":sum(x=="DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION" for x in classes),
         "without_edge_supply_cases":sum(x=="BLOCK_EXPANSION_WITHOUT_DOWNWARD_EDGE_SUPPLY" for x in classes),
         "lower_no_gain_cases":sum(x=="LOWER_REGION_DOES_NOT_GAIN_STORAGE" for x in classes),
         "inconsistent_cases":sum(x=="INTERNAL_FLUX_STATE_INCONSISTENT" for x in classes),
         "min_downward_expansion_fraction":min((x["downward_expansion_fraction"] for x in rows),default=0.0),
         "max_abs_bottom_flux":max((x["max_abs_bottom_flux"] for x in rows),default=math.inf),
         "all_mass_ok":all(x["mass_ok"] for x in rows)}
print("F_PE_NLGLOB14J_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14J_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14J=PASS")
