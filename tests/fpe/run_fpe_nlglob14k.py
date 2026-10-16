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
m=mats["O05"]; tr=m["theta_r"]; ts=m["theta_s"]
for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
    cp=subprocess.run([str(exe),"O05","TG",route,str(tr),str(ts),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    mode=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    entries=[x for x in mode if int(x.get("ENTRY","0"))==1]
    rec={"material":"O05","route":route,"dt":dt,"entry_count":len(entries),"process_ok":cp.returncode==0}

    bystep={}
    inconsistent=False
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1): inconsistent=True

    mixed=[]; finite=True; noncontig=False
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      heads=[float(x["H"]) for x in xs]; theta=[float(x["THETA"]) for x in xs]
      pond=float(xs[0]["POND"]); qtop=float(xs[0]["TOP_FLUX"]); actual_route=xs[0]["ROUTE"]
      if not all(math.isfinite(v) for v in heads+theta+[pond,qtop]): finite=False
      sat=[i+1 for i,x in enumerate(xs) if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: noncontig=True
      if not sat: continue
      s=min(sat)
      is_mixed=("surface-flux" in actual_route and abs(pond)<=1e-15 and 1 not in sat and contiguous)
      if not is_mixed: continue

      kval=[kvg(m,h) for h in heads]
      qiface=[None]*17  # 1-based interface index between i-1 and i for i>=2
      for i in range(1,16):
        km=.5*(kval[i-1]+kval[i])
        grad=(heads[i-1]-heads[i])/distance+1.0
        qiface[i+1]=-km*grad

      upper_n=s-1
      pred=[]; admissible=True
      for node in range(1,upper_n+1):
        if node==1:
          qbelow=qiface[2] if upper_n>=1 else 0.0
          tdot=(qbelow-qtop)/dz
        else:
          qabove=qiface[node]
          qbelow=qiface[node+1]
          tdot=(qbelow-qabove)/dz
        thtilde=theta[node-1]+dt*tdot
        pred.append(thtilde)
        if not math.isfinite(thtilde) or not (tr<thtilde<ts): admissible=False

      distances=[min((x-tr)/(ts-tr),(ts-x)/(ts-tr)) for x in pred] if pred else []
      mixed.append({"step":step,"sat_count":len(sat),"edge_node":s,"upper_nodes":upper_n,
                    "pred_min":min(pred) if pred else math.nan,"pred_max":max(pred) if pred else math.nan,
                    "min_norm_bound_distance":min(distances) if distances else math.nan,
                    "upper_tg_admissible":admissible,"route":actual_route,"pond":pond})

    first_adm=next((i for i,x in enumerate(mixed) if x["upper_tg_admissible"]),None)
    adm_count=sum(x["upper_tg_admissible"] for x in mixed)
    adm_frac=adm_count/len(mixed) if mixed else 0.0
    persists=bool(first_adm is not None and all(x["upper_tg_admissible"] for x in mixed[first_adm:]))

    complete=False; mass_ok=False; maxledger=math.inf; cumledger=math.inf
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    if inconsistent or noncontig or not finite:
      cls="MIXED_PROFILE_STATE_INCONSISTENT"
    elif mixed and adm_frac>=.95 and persists and complete and mass_ok:
      cls="UPPER_TG_REGION_ADMISSIBLE"
    elif mixed and adm_frac<.50:
      cls="UPPER_TG_REGION_NOT_ADMISSIBLE"
    else:
      cls="UPPER_TG_ADMISSIBILITY_MIXED"

    rec.update({"classification":cls,"mixed_intervals":len(mixed),"upper_tg_admissible_intervals":adm_count,
                "upper_tg_admissible_fraction":adm_frac,"first_admissible_index":first_adm,
                "admissibility_persists":persists,"state_finite":finite,"indicator_inconsistent":inconsistent,
                "noncontiguous":noncontig,"complete":complete,"mass_ok":mass_ok,
                "max_ledger":maxledger,"cum_ledger":cumledger,
                "first_mixed_step":mixed[0]["step"] if mixed else None,
                "final_edge_node":mixed[-1]["edge_node"] if mixed else None,
                "final_upper_nodes":mixed[-1]["upper_nodes"] if mixed else None,
                "min_predictor_bound_distance":min((x["min_norm_bound_distance"] for x in mixed if math.isfinite(x["min_norm_bound_distance"])),default=math.nan)})
    rows.append(rec)

coverage=(len(rows)==8 and proc==0 and all(x["entry_count"]==1 and x["complete"] and x["mass_ok"] and
          x["state_finite"] and x["mixed_intervals"]>0 for x in rows))
classes=[x["classification"] for x in rows]
if not coverage:
    cls="BLOCKED_NLGLOB14K_MODE_OWNERSHIP_ATTRIBUTION"
elif any(x=="MIXED_PROFILE_STATE_INCONSISTENT" for x in classes):
    cls="NLGLOB14K_MIXED_PROFILE_STATE_INCONSISTENT"
elif all(x=="UPPER_TG_REGION_ADMISSIBLE" for x in classes):
    cls="NLGLOB14K_UPPER_TG_REGION_ADMISSIBLE_WITH_LOWER_SATURATED_BLOCK"
elif all(x=="UPPER_TG_REGION_NOT_ADMISSIBLE" for x in classes):
    cls="NLGLOB14K_FULL_COLUMN_KLAG_STILL_REQUIRED_BY_TG_DOMAIN"
else:
    cls="NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "upper_admissible_cases":sum(x=="UPPER_TG_REGION_ADMISSIBLE" for x in classes),
         "upper_not_admissible_cases":sum(x=="UPPER_TG_REGION_NOT_ADMISSIBLE" for x in classes),
         "mixed_cases":sum(x=="UPPER_TG_ADMISSIBILITY_MIXED" for x in classes),
         "inconsistent_cases":sum(x=="MIXED_PROFILE_STATE_INCONSISTENT" for x in classes),
         "min_admissible_fraction":min((x["upper_tg_admissible_fraction"] for x in rows),default=0.0),
         "all_mass_ok":all(x["mass_ok"] for x in rows)}
print("F_PE_NLGLOB14K_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14K=PASS")
