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
    rec={"material":"O05","route":route,"dt":dt,"wet_rain":rain,"entry_count":len(entries),"process_ok":cp.returncode==0}

    forcing_ok=bool(forcing)
    for f in forcing:
      forcing_ok = forcing_ok and abs(float(f["PRECIP"]))<=1e-15
      forcing_ok = forcing_ok and math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12)
      forcing_ok = forcing_ok and math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12)
      forcing_ok = forcing_ok and f.get("PHASE")=="DRY"
    rec["forcing_ok"]=forcing_ok

    bystep={}
    event_nodes=set()
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if int(x.get("EVENT_NODE","0"))>0: event_nodes.add(int(x["EVENT_NODE"]))
    event_node=next(iter(event_nodes)) if len(event_nodes)==1 else 0
    rec["event_node"]=event_node
    steps=sorted(bystep)
    event_series=[]; state_finite=True; indicator_inconsistent=False
    profile_series=[]
    for step in steps:
      xs=bystep[step]
      ev=next((x for x in xs if int(x["NODE"])==event_node),None)
      if ev is None: continue
      h=float(ev["H"]); th=float(ev["THETA"]); ts=float(ev["THETA_S"])
      pond=float(ev["POND"]); top=float(ev["TOP_FLUX"]); bottom=float(ev["BOTTOM_FLUX"])
      vals=[h,th,ts,pond,top,bottom]
      if not all(math.isfinite(v) for v in vals): state_finite=False
      sat_h=int(ev["SAT_H"])==1; sat_theta=int(ev["SAT_THETA"])==1
      if sat_h != sat_theta: indicator_inconsistent=True
      thetas=[float(q["THETA"]) for q in xs]
      if len(thetas)!=16 or not all(math.isfinite(v) for v in thetas): state_finite=False
      storage=10.0*sum(thetas)+pond
      event_series.append({"step":step,"h":h,"theta":th,"theta_s":ts,"sat_h":sat_h,"sat_theta":sat_theta,
                           "pond":pond,"top_flux":top,"bottom_flux":bottom,"route":ev["ROUTE"]})
      profile_series.append({"step":step,"storage":storage,"pond":pond,"route":ev["ROUTE"],
                             "top_flux":top,"bottom_flux":bottom})

    rec["observed_steps"]=len(event_series)
    if event_series:
      first=event_series[0]; last=event_series[-1]
      h_first=first["h"]; h_last=last["h"]; dh=h_last-h_first
      uh=32.0*(math.ulp(h_first)+math.ulp(h_last))
      transitions=[event_series[i+1]["h"]<=event_series[i]["h"] for i in range(len(event_series)-1)]
      monotone_frac=sum(transitions)/len(transitions) if transitions else 1.0
      firstS=profile_series[0]["storage"]; lastS=profile_series[-1]["storage"]
      dS=lastS-firstS
      all_sat=all(x["sat_h"] and x["sat_theta"] for x in event_series)
      rec.update({
        "h_first":h_first,"h_last":h_last,"delta_h":dh,"u_h":uh,
        "material_head_drift":abs(dh)>uh,
        "drying_direction_fraction":monotone_frac,
        "sustained_drying_direction":monotone_frac>=.90,
        "theta_deficit_first":first["theta_s"]-first["theta"],
        "theta_deficit_last":last["theta_s"]-last["theta"],
        "event_theta_saturated_throughout":all_sat,
        "storage_first":firstS,"storage_last":lastS,"delta_storage":dS,
        "net_profile_drying":dS<0.0,
        "pond_first":first["pond"],"pond_last":last["pond"],
        "route_first":first["route"],"route_last":last["route"],
        "top_flux_first":first["top_flux"],"top_flux_last":last["top_flux"],
        "bottom_flux_first":first["bottom_flux"],"bottom_flux_last":last["bottom_flux"]
      })
    else:
      rec.update({"h_first":math.nan,"h_last":math.nan,"delta_h":math.nan,"u_h":math.nan,
                  "material_head_drift":False,"drying_direction_fraction":0.0,
                  "sustained_drying_direction":False,"event_theta_saturated_throughout":False,
                  "delta_storage":math.nan,"net_profile_drying":False})

    if res:
      rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      rec["terminal_reason"]=res["TERMINAL_REASON"]
      rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
      rec["mass_ok"]=rec["max_ledger"]<=5e-8 and rec["cum_ledger"]<=5e-8
    else:
      rec["complete"]=False; rec["terminal_reason"]="MISSING_RESULT"; rec["mass_ok"]=False
      rec["max_ledger"]=math.inf; rec["cum_ledger"]=math.inf
    rec["state_finite"]=state_finite
    rec["indicator_inconsistent"]=indicator_inconsistent
    rec["moving_toward"]=bool(rec["material_head_drift"] and rec["delta_h"] < -rec["u_h"] and
                              rec["sustained_drying_direction"] and rec["net_profile_drying"] and
                              not indicator_inconsistent)
    rec["pinned"]=bool(abs(rec["delta_h"])<=rec["u_h"] and rec["event_theta_saturated_throughout"] and
                       rec["net_profile_drying"] and not indicator_inconsistent)
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and
          x["mass_ok"] and x["state_finite"] and x["observed_steps"]>0 for x in rows))
inconsistent=[x for x in rows if x["indicator_inconsistent"]]
moving=[x for x in rows if x["moving_toward"]]
pinned=[x for x in rows if x["pinned"]]

if not coverage:
    cls="BLOCKED_NLGLOB14H_DRIFT_ATTRIBUTION"
elif inconsistent:
    cls="NLGLOB14H_SATURATION_STATE_INCONSISTENT"
elif len(moving)==8:
    cls="NLGLOB14H_EVENT_NODE_MOVING_TOWARD_DESATURATION"
elif len(pinned)==8:
    cls="NLGLOB14H_EVENT_NODE_PINNED_ON_SATURATED_MANIFOLD"
else:
    cls="NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "moving_cases":len(moving),"pinned_cases":len(pinned),"indicator_inconsistent_cases":len(inconsistent),
         "all_mass_ok":all(x["mass_ok"] for x in rows),
         "all_net_profile_drying":all(x["net_profile_drying"] for x in rows),
         "min_drying_direction_fraction":min((x["drying_direction_fraction"] for x in rows),default=0.0),
         "max_abs_delta_h":max((abs(x["delta_h"]) for x in rows if math.isfinite(x["delta_h"])),default=0.0),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14H_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14H_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14H=PASS")
