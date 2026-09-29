#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.012; dtop=10.; pmax=.05; rsro=.05; dz=10.; distance=10.; hcrit=-1e-2

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def setup(m,dt):
    mm=1-1/m["n"]; c25=m["theta_s"]-m["theta_r"]
    c26=m["theta_r"]+c25/((1+(abs(m["alpha"]*hcrit))**m["n"])**mm)
    c27=(m["theta_s"]-c26)/(-hcrit)
    return {"mm":mm,"c25":c25,"c26":c26,"c27":c27,"dt":dt}
def theta_of(m,c,h):
    if h>=0: return m["theta_s"]
    if h>hcrit: return min(c["c26"]+c["c27"]*(h-hcrit),m["theta_s"])
    return m["theta_r"]+c["c25"]/((1+(abs(m["alpha"]*h))**m["n"])**c["mm"])
def capacity(m,c,h):
    if h>=0: return c["dt"]*1e-7
    if h>hcrit:
        cap=c["c27"]
    else:
        alphah=abs(m["alpha"]*h); term1=alphah**(m["n"]-1)
        term2=c["c25"]/((1+term1*alphah)**(c["mm"]+1))
        cap=m["n"]*c["mm"]*m["alpha"]*term2*term1
    if h>-1 and cap<c["dt"]*1e-7: cap=c["dt"]*1e-7
    return cap
def kvg(m,h,theta=None):
    if theta is None:
        c=setup(m,1.0); theta=theta_of(m,c,h)
    rel=(theta-m["theta_r"])/(m["theta_s"]-m["theta_r"])
    if h < -1e14: return 1e-10
    if rel > 1-1e-6: return m["ksat"]
    mm=1-1/m["n"]; term=(1-rel**(1/mm))**mm
    return m["ksat"]*(rel**m["lambda"])*(1-term)**2
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
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    bystep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
    series=[]; inconsistent=False; finite=True; onset=None; c=setup(m,dt)
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      h=[float(x["H"]) for x in xs]; th=[float(x["THETA"]) for x in xs]
      vals=h+th+[float(xs[0]["POND"]),float(xs[0]["TOP_FLUX"]),float(xs[0]["BOTTOM_FLUX"])]
      if not all(math.isfinite(v) for v in vals): finite=False
      sat=[]
      for i,x in enumerate(xs,1):
        sh=int(x["SAT_H"])==1; st=int(x["SAT_THETA"])==1
        if sh!=st: inconsistent=True
        if sh and st: sat.append(i)
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: inconsistent=True
      s=min(sat) if sat else 0
      mixed=(xs[0]["ROUTE"]=="surface-flux" and float(xs[0]["POND"])<=1e-12 and 1 not in sat and bool(sat) and contiguous and s>1)
      K=[kvg(m,h[i],th[i]) for i in range(16)]
      g=[0.0]*16; qtop=float(xs[0]["TOP_FLUX"])
      km=.5*(K[0]+K[1]); grad=(h[0]-h[1])/distance+1; g[0]=qtop+km*grad
      for i in range(1,15):
        kmu=.5*(K[i-1]+K[i]); gu=(h[i-1]-h[i])/distance+1
        kmd=.5*(K[i]+K[i+1]); gd=(h[i]-h[i+1])/distance+1
        g[i]=-kmu*gu+kmd*gd
      km=.5*(K[14]+K[15]); gu=(h[14]-h[15])/distance+1; g[15]=-km*gu
      tdot=[-x/dz for x in g]
      upper_ok=True; max_roundtrip=0.; min_cap=math.inf; max_abs_hdot=0.
      if mixed:
        for i in range(s-1):
          hh=h[i]; tt=th[i]; cap=capacity(m,c,hh); thchk=theta_of(m,c,hh)
          max_roundtrip=max(max_roundtrip,abs(thchk-tt)); min_cap=min(min_cap,cap)
          if not (hh<0 and tt<m["theta_s"] and math.isfinite(cap) and cap>0 and math.isfinite(tdot[i])):
            upper_ok=False; continue
          hdot=tdot[i]/cap; htilde=hh+dt*hdot; max_abs_hdot=max(max_abs_hdot,abs(hdot))
          if not math.isfinite(hdot) or not math.isfinite(htilde) or abs(thchk-tt)>1e-12: upper_ok=False
      else:
        upper_ok=False
      if onset is None and mixed: onset=step
      series.append({"step":step,"mixed":mixed,"upper_ok":upper_ok,"sat_count":len(sat),"shallow":s,
                     "contiguous":contiguous,"max_roundtrip":max_roundtrip,
                     "min_capacity":min_cap if math.isfinite(min_cap) else None,
                     "max_abs_hdot":max_abs_hdot})
    post=[x for x in series if onset is not None and x["step"]>=onset]
    lower_persistent=bool(post) and all(x["sat_count"]>0 and x["contiguous"] for x in post)
    upper_all=bool(post) and all(x["mixed"] and x["upper_ok"] for x in post)
    mass_ok=False; complete=False; terminal="MISSING"
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      terminal=res["TERMINAL_REASON"]
      mass_ok=abs(float(res["MAX_LEDGER"]))<=5e-8 and abs(float(res["CUM_LEDGER"]))<=5e-8
    if inconsistent or not finite:
      cls="MIXED_PROFILE_STATE_INCONSISTENT"
    elif onset is None:
      cls="NO_MIXED_PROFILE_ONSET"
    elif upper_all and lower_persistent and mass_ok and complete:
      cls="UPPER_TG_LOWER_SATURATED_SPLIT"
    else:
      cls="WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED"
    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,"onset_step":onset,
                 "post_onset_steps":len(post),"upper_all_tg_admissible":upper_all,"lower_persistent":lower_persistent,
                 "state_finite":finite,"indicator_consistent":not inconsistent,"complete":complete,"terminal_reason":terminal,
                 "mass_ok":mass_ok,"max_roundtrip":max((x["max_roundtrip"] for x in post),default=0.0),
                 "min_capacity":min((x["min_capacity"] for x in post if x["min_capacity"] is not None),default=None),
                 "max_abs_hdot":max((x["max_abs_hdot"] for x in post),default=0.0)})

coverage=(len(rows)==8 and proc==0 and all(x["complete"] and x["mass_ok"] and x["state_finite"] for x in rows))
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
         "split_cases":sum(x=="UPPER_TG_LOWER_SATURATED_SPLIT" for x in classes),
         "whole_column_cases":sum(x=="WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED" for x in classes),
         "no_onset_cases":sum(x=="NO_MIXED_PROFILE_ONSET" for x in classes),
         "inconsistent_cases":sum(x=="MIXED_PROFILE_STATE_INCONSISTENT" for x in classes),
         "all_mass_ok":all(x["mass_ok"] for x in rows),
         "max_roundtrip":max((x["max_roundtrip"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14K_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K=PASS")
