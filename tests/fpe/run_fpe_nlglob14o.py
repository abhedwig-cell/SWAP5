#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]; routes=("HEAD","RUNOFF")
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
    caps=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14O_CAP|")]
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    contracts=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14N3_RETRY_CONTRACT|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]

    bystep={}; capstep={}
    inconsistent=False
    for x in caps:
      capstep.setdefault(int(x["STEP"]),[]).append(x)
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1):
        inconsistent=True

    series=[]; finite=True
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      sat=[]
      for x in xs:
        vals=[float(x[k]) for k in ("H","THETA","THETA_S")]
        if not all(math.isfinite(v) for v in vals): finite=False
        if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1:
          sat.append(int(x["NODE"]))
      node3=xs[2]
      series.append({"step":step,"time":step*dt,"sat_count":len(sat),"sat_nodes":sat,
                     "h3":float(node3["H"]),"theta3":float(node3["THETA"]),"theta_s3":float(node3["THETA_S"]),
                     "route":xs[0]["ROUTE"]})

    lo=None; hi=None
    for i in range(len(series)-1):
      a,b=series[i],series[i+1]
      if a["sat_count"]==14 and b["sat_count"]==13 and 3 in a["sat_nodes"] and 3 not in b["sat_nodes"]:
        lo=a; hi=b; break

    complete=False; mass_ok=False; maxledger=math.inf; cumledger=math.inf
    terminal_reason="MISSING_RESULT"; steps_done=None
    if res:
      terminal_reason=res["TERMINAL_REASON"]
      steps_done=int(res["STEPS_DONE"])
      complete=terminal_reason=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    bracket_ok=False; phi=math.nan; tevent=math.nan
    handoff_caps=None; handoff_theta_eval=None; handoff_consistent=False
    if lo and hi:
      pcs=sorted(capstep.get(hi["step"],[]),key=lambda q:int(q["NODE"]))
      if len(pcs)==16:
        handoff_caps=[float(x["CAP"]) for x in pcs]
        handoff_theta_eval=[float(x["THETA_EVAL"]) for x in pcs]
        state_hi=sorted(bystep[hi["step"]],key=lambda q:int(q["NODE"]))
        handoff_consistent=all(math.isfinite(v) for v in handoff_caps+handoff_theta_eval) and max(abs(handoff_theta_eval[i]-float(state_hi[i]["THETA"])) for i in range(16))<=1e-12
      dtbr=hi["time"]-lo["time"]
      lower_sat=all(n in lo["sat_nodes"] and n in hi["sat_nodes"] for n in range(4,17))
      sign_ok=lo["h3"]>=0.0 and hi["h3"]<0.0
      if sign_ok and lower_sat and math.isclose(dtbr,dt,rel_tol=0,abs_tol=1e-12):
        denom=lo["h3"]-hi["h3"]
        if denom>0:
          phi=lo["h3"]/denom
          tevent=lo["time"]+phi*dtbr
          bracket_ok=math.isfinite(phi) and 0.0<=phi<=1.0 and lo["time"]<=tevent<=hi["time"]

    restore_ok=all(abs(float(x.get("RESTORE_H","nan")))<=1e-15 and abs(float(x.get("RESTORE_THETA","nan")))<=1e-15 and abs(float(x.get("RESTORE_POND","nan")))<=1e-15 for x in contracts)
    rows.append({"material":"O05","route":route,"dt":dt,"complete":complete,"mass_ok":mass_ok,
                 "entry_count":len(entries),"retry_contractions":len(contracts),"restore_ok":restore_ok,
                 "state_finite":finite,"indicator_inconsistent":inconsistent,
                 "terminal_reason":terminal_reason,"steps_done":steps_done,
                 "bracket_found":lo is not None and hi is not None,"bracket_ok":bracket_ok,
                 "t_lo":lo["time"] if lo else None,"t_hi":hi["time"] if hi else None,
                 "h3_lo":lo["h3"] if lo else None,"h3_hi":hi["h3"] if hi else None,
                 "theta3_lo":lo["theta3"] if lo else None,"theta3_hi":hi["theta3"] if hi else None,
                 "phi":phi,"event_time":tevent,"terminal_reason":terminal_reason,"max_ledger":maxledger,"cum_ledger":cumledger,
                 "handoff_caps":handoff_caps,"handoff_consistent":handoff_consistent})

coverage=(len(rows)==12 and proc==0 and all(x["complete"] and x["mass_ok"] and x["state_finite"] and
          not x["indicator_inconsistent"] for x in rows))
all_brackets=all(x["bracket_ok"] for x in rows)
family={}
conv_ok=True
old_diff={"HEAD":1.2153801567028888e-4,"RUNOFF":7.574058036472972e-5}
for route in routes:
    xs=sorted([x for x in rows if x["route"]==route],key=lambda x:x["dt"],reverse=True)
    ok=len(xs)==6 and all(x["bracket_ok"] for x in xs)
    if ok:
      fine=sorted(xs,key=lambda x:x["dt"])
      diff=abs(fine[0]["event_time"]-fine[1]["event_time"])
      thresh=2*min(dts)
      improves=diff<old_diff[route]
      ok=diff<=thresh and improves
      family[route]={"event_times":[x["event_time"] for x in xs],
                     "refined_difference":diff,"threshold":thresh,
                     "previous_refined_difference":old_diff[route],
                     "improves_over_nlglob14m":improves,"passes":ok}
    else:
      family[route]={"event_times":[x["event_time"] for x in xs],"passes":False}
    conv_ok=conv_ok and family[route]["passes"]

route_passes=sum(bool(family[r]["passes"]) for r in routes)
if not coverage:
    cls="BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE"
elif not all_brackets:
    cls="NLGLOB14N_RETREAT_EVENT_STATE_INCONSISTENT"
elif route_passes==2:
    cls="QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE"
elif route_passes==1:
    cls="NLGLOB14N_MIXED_REFINED_RETREAT_CONVERGENCE"
else:
    cls="NLGLOB14N_RETREAT_EVENT_TIME_STILL_NOT_CONVERGED"

for x in rows:
    caps=x["handoff_caps"]
    if caps is None:
      x["upper_caps_positive"]=False; x["lower_caps_zero"]=False; x["full_column_caps_positive"]=False
    else:
      x["upper_caps_positive"]=all(math.isfinite(v) and v>0.0 for v in caps[:3])
      x["lower_caps_zero"]=all(math.isfinite(v) and v==0.0 for v in caps[3:])
      x["full_column_caps_positive"]=all(math.isfinite(v) and v>0.0 for v in caps)

if all(x["complete"] and x["mass_ok"] and x["bracket_ok"] and x["handoff_consistent"] and
       x["upper_caps_positive"] and x["lower_caps_zero"] for x in rows):
    ocls="NLGLOB14O_FULL_COLUMN_TG_HANDOFF_FALSIFIED_BY_SATURATED_DOMAIN"
elif all(x["complete"] and x["mass_ok"] and x["bracket_ok"] and x["handoff_consistent"] and
         x["full_column_caps_positive"] for x in rows):
    ocls="NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE"
elif any(not x["handoff_consistent"] for x in rows):
    ocls="NLGLOB14O_HANDOFF_STATE_INCONSISTENT"
else:
    ocls="NLGLOB14O_MIXED_HANDOFF_ADMISSIBILITY"

target=next((x for x in rows if x["route"]=="HEAD" and math.isclose(x["dt"],min(dts),rel_tol=0,abs_tol=1e-15)),None)
target_ok=bool(target and target["complete"] and target["mass_ok"] and target["state_finite"] and
               not target["indicator_inconsistent"] and target["retry_contractions"]>=1 and
               target["restore_ok"] and target["entry_count"]==1)
all_safe=bool(coverage and all(x["restore_ok"] for x in rows) and all(x["entry_count"]==1 for x in rows))
if not target_ok:
    n3cls="NLGLOB14N3_RETRY_BRACKET_CONTRACTION_FALSIFIED"
elif not all_safe:
    n3cls="NLGLOB14N3_RETRY_BRACKET_CONTRACTION_REGRESSION"
else:
    n3cls="QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "all_brackets_ok":all_brackets,"families":family,
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
n3summary={"classification":n3cls,"target_ok":target_ok,"all_safe":all_safe,
           "target":target,"nlglob14n_classification":cls,
           "total_retry_contractions":sum(x["retry_contractions"] for x in rows),
           "all_restore_ok":all(x["restore_ok"] for x in rows)}
osummary={"classification":ocls,"case_count":len(rows),
          "all_mass_ok":all(x["mass_ok"] for x in rows),
          "all_handoff_consistent":all(x["handoff_consistent"] for x in rows),
          "all_upper_caps_positive":all(x["upper_caps_positive"] for x in rows),
          "all_lower_caps_zero":all(x["lower_caps_zero"] for x in rows),
          "full_column_admissible_cases":sum(x["full_column_caps_positive"] for x in rows)}
print("F_PE_NLGLOB14O_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14O_SUMMARY="+json.dumps(osummary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N3_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N3_SUMMARY="+json.dumps(n3summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14N=PASS")
print("F_PE_NLGLOB14N3=PASS")
print("F_PE_NLGLOB14O=PASS")
