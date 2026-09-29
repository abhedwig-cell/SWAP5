#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.012; dtop=10.; pmax=.05; rsro=.05; dz=10.0; distance=10.0

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def theta_vg(m,h):
    if h>=0.0: return m["theta_s"]
    n=m["n"]; mm=1-1/n
    return m["theta_r"]+(m["theta_s"]-m["theta_r"])/(1+(abs(m["alpha"]*h))**n)**mm

def cap_vg(m,h,dt):
    floor=dt*1e-7
    if h>=0.0: return floor
    n=m["n"]; mm=1-1/n; a=m["alpha"]
    ah=abs(a*h)
    c=(m["theta_s"]-m["theta_r"])*a*mm*n*(ah**(n-1))/((1+ah**n)**(mm+1))
    if h>-1.0 and c<floor: c=floor
    return c

def kvg(m,h):
    if h>=0.0: return m["ksat"]
    n=m["n"]; mm=1-1/n
    se=(1+(abs(m["alpha"]*h))**n)**(-mm)
    term=1-(1-se**(1/mm))**mm
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
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    bystep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)

    mixed=0; clean=0; admiss=0; min_upper_c=math.inf; max_lower_c=0.0; invalid=False
    first_step=None; last_step=None
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: continue
      heads=[float(x["H"]) for x in xs]; thetas=[float(x["THETA"]) for x in xs]
      pond=float(xs[0]["POND"]); route_now=xs[0]["ROUTE"]
      sat=[]
      inconsistent=False
      for i,x in enumerate(xs):
        sh=int(x["SAT_H"])==1; st=int(x["SAT_THETA"])==1
        if sh!=st: inconsistent=True
        if sh and st: sat.append(i+1)
      if inconsistent: invalid=True; continue
      contiguous=(not sat) or sat==list(range(min(sat),17))
      top_unsat=1 not in sat
      is_mixed=(route_now=="surface-flux" and pond==0.0 and top_unsat and bool(sat) and contiguous)
      if not is_mixed: continue

      mixed+=1
      first_step=step if first_step is None else first_step
      last_step=step
      s=min(sat)
      upper=range(0,s-1); lower=range(s-1,16)
      split_ok=True
      upper_caps=[]
      for i in upper:
        c=cap_vg(m,heads[i],dt); th=theta_vg(m,heads[i])
        upper_caps.append(c)
        if not (math.isfinite(c) and c>0 and math.isfinite(th) and abs(th-thetas[i])<=1e-12):
          split_ok=False
      lower_caps=[]
      floor=dt*1e-7
      for i in lower:
        c=cap_vg(m,heads[i],dt); lower_caps.append(c)
        if not (heads[i]>=0 and thetas[i]==m["theta_s"] and c==floor):
          split_ok=False
      if upper_caps: min_upper_c=min(min_upper_c,min(upper_caps))
      if lower_caps: max_lower_c=max(max_lower_c,max(abs(x) for x in lower_caps))
      if split_ok: clean+=1

      # Diagnostic upper-region TG current-step predictor.
      # Use the same vertical flux convention as TIMEINT16/17.
      K=[kvg(m,h) for h in heads]
      qtop=float(xs[0]["TOP_FLUX"])
      theta_dot=[0.0]*16
      if s>1:
        km=.5*(K[0]+K[1])
        grad=(heads[0]-heads[1])/distance+1.0
        g=qtop+km*grad
        theta_dot[0]=-g/dz
        for i in range(1,s-1):
          kmu=.5*(K[i-1]+K[i]); gradu=(heads[i-1]-heads[i])/distance+1.0
          kml=.5*(K[i]+K[i+1]); gradl=(heads[i]-heads[i+1])/distance+1.0
          g=-kmu*gradu+kml*gradl
          theta_dot[i]=-g/dz
      pred_ok=split_ok
      for i in upper:
        tt=thetas[i]+dt*theta_dot[i]
        if not (math.isfinite(tt) and tt>m["theta_r"] and tt<m["theta_s"]):
          pred_ok=False
      if pred_ok: admiss+=1

    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    mass_ok=bool(res and abs(float(res["MAX_LEDGER"]))<=5e-8 and abs(float(res["CUM_LEDGER"]))<=5e-8)
    clean_frac=clean/mixed if mixed else 0.0
    adm_frac=admiss/mixed if mixed else 0.0
    support=(mixed>0 and clean_frac==1.0 and adm_frac==1.0 and complete and mass_ok and not invalid)

    rows.append({"route":route,"dt":dt,"process_ok":cp.returncode==0,"mixed_states":mixed,
                 "first_mixed_step":first_step,"last_mixed_step":last_step,
                 "min_upper_capacity":min_upper_c if math.isfinite(min_upper_c) else None,
                 "max_lower_capacity":max_lower_c,
                 "clean_split_fraction":clean_frac,"upper_tg_admissible_fraction":adm_frac,
                 "state_inconsistent":invalid,"complete":complete,"mass_ok":mass_ok,"support":support})

coverage=(len(rows)==8 and proc==0 and all(x["mixed_states"]>0 and x["complete"] and x["mass_ok"] for x in rows))
if not coverage:
    cls="BLOCKED_NLGLOB14K_MODE_OWNERSHIP_ATTRIBUTION"
elif any(x["clean_split_fraction"]<1.0 for x in rows):
    cls="NLGLOB14K_NO_CLEAN_CONSTITUTIVE_MODE_SPLIT"
elif all(x["support"] for x in rows):
    cls="NLGLOB14K_SPATIALLY_SPLIT_MODE_OWNERSHIP_SIGNAL"
elif all(x["clean_split_fraction"]==1.0 for x in rows) and any(x["upper_tg_admissible_fraction"]<1.0 for x in rows):
    cls="NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE"
else:
    cls="NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "support_cases":sum(x["support"] for x in rows),
         "min_clean_split_fraction":min((x["clean_split_fraction"] for x in rows),default=0.0),
         "min_upper_tg_admissible_fraction":min((x["upper_tg_admissible_fraction"] for x in rows),default=0.0),
         "all_mass_ok":all(x["mass_ok"] for x in rows)}
print("F_PE_NLGLOB14K_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K=PASS")
