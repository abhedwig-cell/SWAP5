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

rows=[]; proc=0; m=mats["O05"]
for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    probes=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14K_PROBE|")]
    forcing=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14G_FORCING|")]
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
    rec={"material":"O05","route":route,"dt":dt,"entry_count":len(entries),"process_ok":cp.returncode==0}

    forcing_ok=bool(forcing) and all(abs(float(f["PRECIP"]))<=1e-15 and
      math.isclose(float(f["EBARE"]),rain,rel_tol=0,abs_tol=1e-12) and
      math.isclose(float(f["EPOND"]),rain,rel_tol=0,abs_tol=1e-12) and f.get("PHASE")=="DRY" for f in forcing)

    sb={}; pb={}
    for x in states: sb.setdefault(int(x["STEP"]),[]).append(x)
    for x in probes: pb.setdefault(int(x["STEP"]),[]).append(x)
    series=[]; inconsistent=False; noncontig=False; finite=True
    for step in sorted(sb):
      xs=sorted(sb[step],key=lambda q:int(q["NODE"]))
      ps=sorted(pb.get(step,[]),key=lambda q:int(q["NODE"]))
      if len(xs)!=16 or len(ps)!=16: finite=False; continue
      sat=[]
      for x in xs:
        if (int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1): inconsistent=True
        if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1: sat.append(int(x["NODE"]))
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: noncontig=True
      shallow=min(sat) if sat else 0
      route_actual=xs[0]["ROUTE"]
      pond=float(xs[0]["POND"])
      top_unsat=1 not in sat
      mixed=(route_actual=="surface-flux" and pond<=1e-12 and top_unsat and bool(sat) and contiguous and shallow>1)
      upper_ok=True; min_cap=math.inf; max_roundtrip=0.0; max_abs_hdot=0.0; max_abs_htilde=0.0
      if shallow>1:
        for i in range(shallow-1):
          h=float(xs[i]["H"]); th=float(xs[i]["THETA"]); te=float(ps[i]["THETA_EVAL"])
          cap=float(ps[i]["CAP"]); td=float(ps[i]["THETA_DOT"])
          vals=(h,th,te,cap,td)
          if not all(math.isfinite(v) for v in vals): finite=False; upper_ok=False; continue
          min_cap=min(min_cap,cap); max_roundtrip=max(max_roundtrip,abs(te-th))
          if not (h<0.0 and th<m["theta_s"] and cap>0.0 and abs(te-th)<=1e-12):
            upper_ok=False
          if cap>0.0:
            hdot=td/cap; htilde=h+dt*hdot
            if not (math.isfinite(hdot) and math.isfinite(htilde)): upper_ok=False
            else:
              max_abs_hdot=max(max_abs_hdot,abs(hdot)); max_abs_htilde=max(max_abs_htilde,abs(htilde))
          else:
            upper_ok=False
      else:
        upper_ok=False
      edge_finite=True; qdown=None
      if shallow>1:
        hu=float(xs[shallow-2]["H"]); hl=float(xs[shallow-1]["H"])
        km=.5*(kvg(m,hu)+kvg(m,hl))
        q=-km*((hu-hl)/distance+1.0); qdown=-q
        edge_finite=math.isfinite(qdown)
      vals=[float(xs[0][k]) for k in ("TOP_FLUX","BOTTOM_FLUX","POND")]
      if not all(math.isfinite(v) for v in vals): finite=False
      series.append({"step":step,"mixed":mixed,"route":route_actual,"pond":pond,"sat_count":len(sat),
        "shallowest":shallow,"contiguous":contiguous,"upper_ok":upper_ok,"min_upper_cap":min_cap,
        "max_roundtrip":max_roundtrip,"max_abs_hdot":max_abs_hdot,"max_abs_htilde":max_abs_htilde,
        "edge_finite":edge_finite,"q_down_edge":qdown,"bottom_flux":float(xs[0]["BOTTOM_FLUX"])})

    onset_i=next((i for i,x in enumerate(series) if x["mixed"]),None)
    post=series[onset_i:] if onset_i is not None else []
    lower_persistent=bool(post) and all(x["sat_count"]>0 and x["contiguous"] and x["shallowest"]>1 and x["edge_finite"] for x in post)
    upper_all=bool(post) and all(x["upper_ok"] for x in post)
    max_bottom=max((abs(x["bottom_flux"]) for x in post),default=math.inf)
    mass_ok=False; complete=False; terminal="MISSING_RESULT"; maxledger=math.inf; cumledger=math.inf
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      terminal=res["TERMINAL_REASON"]; maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    state_bad=inconsistent or noncontig or not finite
    if state_bad:
      cls="MIXED_PROFILE_STATE_INCONSISTENT"
    elif onset_i is None:
      cls="NO_MIXED_PROFILE_ONSET"
    elif upper_all and lower_persistent and max_bottom<=5e-8 and mass_ok and cp.returncode==0:
      cls="UPPER_TG_LOWER_SATURATED_SPLIT"
    elif lower_persistent and not upper_all:
      cls="WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED"
    else:
      cls="MIXED_MODE_OWNERSHIP_SIGNAL"

    rec.update({"classification":cls,"forcing_ok":forcing_ok,"complete":complete,"terminal_reason":terminal,
      "mass_ok":mass_ok,"max_ledger":maxledger,"cum_ledger":cumledger,"state_finite":finite,
      "indicator_inconsistent":inconsistent,"noncontiguous":noncontig,"mixed_onset_step":series[onset_i]["step"] if onset_i is not None else None,
      "post_onset_states":len(post),"upper_tg_all_admissible":upper_all,"lower_block_persistent":lower_persistent,
      "min_upper_capacity":min((x["min_upper_cap"] for x in post),default=None),
      "max_upper_roundtrip":max((x["max_roundtrip"] for x in post),default=None),
      "max_abs_upper_hdot":max((x["max_abs_hdot"] for x in post),default=None),
      "max_abs_upper_htilde":max((x["max_abs_htilde"] for x in post),default=None),
      "max_abs_bottom_flux":max_bottom})
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["forcing_ok"] and x["complete"] and x["mass_ok"] and x["state_finite"] for x in rows))
classes=[x["classification"] for x in rows]
if not coverage:
  cls="BLOCKED_NLGLOB14K_MODE_OWNERSHIP_ATTRIBUTION"
elif any(x=="MIXED_PROFILE_STATE_INCONSISTENT" for x in classes):
  cls="NLGLOB14K_MIXED_PROFILE_STATE_INCONSISTENT"
elif all(x=="UPPER_TG_LOWER_SATURATED_SPLIT" for x in classes):
  cls="NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL"
elif all(x=="WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED" for x in classes):
  cls="NLGLOB14K_WHOLE_COLUMN_SATURATED_OWNERSHIP_SUPPORTED"
else:
  cls="NLGLOB14K_MIXED_TEMPORAL_OWNERSHIP"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "split_signal_cases":sum(x=="UPPER_TG_LOWER_SATURATED_SPLIT" for x in classes),
  "whole_column_cases":sum(x=="WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED" for x in classes),
  "no_onset_cases":sum(x=="NO_MIXED_PROFILE_ONSET" for x in classes),
  "inconsistent_cases":sum(x=="MIXED_PROFILE_STATE_INCONSISTENT" for x in classes),
  "all_mass_ok":all(x["mass_ok"] for x in rows),
  "min_upper_capacity":min((x["min_upper_capacity"] for x in rows if x["min_upper_capacity"] is not None),default=None),
  "max_upper_roundtrip":max((x["max_upper_roundtrip"] for x in rows if x["max_upper_roundtrip"] is not None),default=None)}
print("F_PE_NLGLOB14K_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K=PASS")
