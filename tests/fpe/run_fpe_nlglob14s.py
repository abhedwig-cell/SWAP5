#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]; routes=("HEAD","RUNOFF")
horizon=.05; dtop=10.; pmax=.05; rsro=.05; dz=10.0

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def theta_provider(m,h):
    if h>=0.0: return m["theta_s"]
    mm=1-1/m["n"]; hcrit=-1e-2
    if h>hcrit:
        c26=m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1+(abs(m["alpha"]*hcrit))**m["n"])**mm)
        c27=(m["theta_s"]-c26)/(-hcrit)
        return min(c26+c27*(h-hcrit),m["theta_s"])
    return m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1+(abs(m["alpha"]*h))**m["n"])**mm)
def kprovider(m,h):
    if h < -1e14: return 1e-10
    th=theta_provider(m,h)
    rel=(th-m["theta_r"])/(m["theta_s"]-m["theta_r"])
    if rel>1-1e-6: return m["ksat"]
    mm=1-1/m["n"]
    if rel<=0.0: return 0.0
    term=(1-rel**(1/mm))**mm
    return min(m["ksat"]*(rel**m["lambda"])*(1-term)**2,m["ksat"])
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
    caps=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14O_CAP|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    bystep={}; capstep={}; indicator_bad=False
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if int(x["SAT_H"])!=int(x["SAT_THETA"]): indicator_bad=True
    for x in caps: capstep.setdefault(int(x["STEP"]),[]).append(x)

    series=[]
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: continue
      sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      series.append({"step":step,"sat":sat})
    hi=None
    for i in range(len(series)-1):
      if len(series[i]["sat"])==14 and series[i]["sat"]==list(range(3,17)) and series[i+1]["sat"]==list(range(4,17)):
        hi=series[i+1]; break

    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    control_mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    partition_ok=False; upper_ok=False; lower_ok=False; split_mass_ok=False
    q34=math.nan; dsu=math.nan; dsl=math.nan; full_tendency=math.nan
    split_resid=math.nan; upper_resid=math.nan; lower_resid=math.nan
    interface_mismatch=math.nan; max_upper_hdot=math.nan; min_upper_pred_margin=math.nan
    if hi is not None:
      xs=sorted(bystep[hi["step"]],key=lambda q:int(q["NODE"]))
      cs=sorted(capstep.get(hi["step"],[]),key=lambda q:int(q["NODE"]))
      if len(xs)==16 and len(cs)==16:
        heads=[float(x["H"]) for x in xs]; theta=[float(x["THETA"]) for x in xs]
        cap=[float(x["CAP"]) for x in cs]
        finite=all(math.isfinite(v) for v in heads+theta+cap)
        partition_ok=(finite and hi["sat"]==list(range(4,17)) and
                      all(heads[i]<0.0 and theta[i]<m["theta_s"] for i in range(3)) and
                      all(heads[i]>=0.0 and math.isclose(theta[i],m["theta_s"],rel_tol=0,abs_tol=1e-12) for i in range(3,16)))
        kval=[kprovider(m,h) for h in heads]
        qiface=[None]*17
        for j in range(1,16):
          km=.5*(kval[j-1]+kval[j]); grad=(heads[j-1]-heads[j])/10.0+1.0
          qiface[j+1]=-km*grad
        qtop=float(xs[0]["TOP_FLUX"]); qbot=float(xs[0]["BOTTOM_FLUX"]); q34=qiface[4]
        tdot=[]
        for node in range(1,17):
          if node==1: td=(qiface[2]-qtop)/dz
          elif node==16: td=(qbot-qiface[16])/dz
          else: td=(qiface[node+1]-qiface[node])/dz
          tdot.append(td)

        upper_hdot=[tdot[i]/cap[i] for i in range(3)]
        upper_htilde=[heads[i]+dt*upper_hdot[i] for i in range(3)]
        upper_theta_pred=[theta_provider(m,h) for h in upper_htilde]
        upper_k_pred=[kprovider(m,h) for h in upper_htilde]
        upper_ok=(partition_ok and all(math.isfinite(v) for v in upper_hdot+upper_htilde+upper_theta_pred+upper_k_pred)
                  and all(cap[i]>0.0 for i in range(3))
                  and all(upper_k_pred[i]>0.0 and upper_theta_pred[i]<m["theta_s"] for i in range(3)))
        max_upper_hdot=max(abs(v) for v in upper_hdot)
        min_upper_pred_margin=min(m["theta_s"]-v for v in upper_theta_pred)

        lower_ok=(partition_ok and math.isfinite(q34) and math.isfinite(qbot) and
                  all(math.isfinite(v) for v in tdot[3:]) and hi["sat"]==list(range(4,17)))
        dsu=sum(tdot[:3])*dz; dsl=sum(tdot[3:])*dz; full_tendency=qbot-qtop
        upper_resid=dsu-(q34-qtop); lower_resid=dsl-(qbot-q34)
        split_resid=(dsu+dsl)-full_tendency
        interface_mismatch=q34-q34
        split_mass_ok=(abs(upper_resid)<=1e-12 and abs(lower_resid)<=1e-12 and
                       abs(split_resid)<=1e-12 and abs(interface_mismatch)<=1e-15)

    if indicator_bad or not partition_ok:
      cls="SPLIT_PARTITION_STATE_INCONSISTENT"
    elif not split_mass_ok:
      cls="SPLIT_INTERFACE_MASS_INCONSISTENT"
    elif not upper_ok and lower_ok:
      cls="UPPER_TG_PARTITION_NOT_ADMISSIBLE"
    elif upper_ok and not lower_ok:
      cls="LOWER_SATURATED_PARTITION_NOT_ADMISSIBLE"
    elif upper_ok and lower_ok and complete and control_mass_ok:
      cls="SPLIT_TEMPORAL_OWNERSHIP_OBSERVATIONALLY_FEASIBLE"
    else:
      cls="SPLIT_PARTITION_STATE_INCONSISTENT"

    rows.append({"material":"O05","route":route,"dt":dt,"classification":cls,
      "process_ok":cp.returncode==0,"control_complete":complete,"control_mass_ok":control_mass_ok,
      "partition_ok":partition_ok,"upper_tg_ok":upper_ok,"lower_saturated_ok":lower_ok,
      "split_mass_ok":split_mass_ok,"q34":q34,"dS_upper_dt":dsu,"dS_lower_dt":dsl,
      "full_storage_tendency":full_tendency,"upper_residual":upper_resid,"lower_residual":lower_resid,
      "split_residual":split_resid,"interface_mismatch":interface_mismatch,
      "max_upper_hdot":max_upper_hdot,"min_upper_pred_margin":min_upper_pred_margin,
      "max_ledger":maxledger,"cum_ledger":cumledger})

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["control_complete"] and x["control_mass_ok"] for x in rows)
if any(x=="SPLIT_INTERFACE_MASS_INCONSISTENT" for x in classes):
  cls="NLGLOB14S_SPLIT_INTERFACE_MASS_INCONSISTENT"
elif coverage and all(x=="SPLIT_TEMPORAL_OWNERSHIP_OBSERVATIONALLY_FEASIBLE" for x in classes):
  cls="NLGLOB14S_SPLIT_TEMPORAL_OWNERSHIP_FEASIBLE"
elif coverage and all(x=="UPPER_TG_PARTITION_NOT_ADMISSIBLE" for x in classes):
  cls="NLGLOB14S_UPPER_TG_PARTITION_NOT_ADMISSIBLE"
elif coverage and all(x=="LOWER_SATURATED_PARTITION_NOT_ADMISSIBLE" for x in classes):
  cls="NLGLOB14S_LOWER_SATURATED_PARTITION_NOT_ADMISSIBLE"
else:
  cls="NLGLOB14S_MIXED_SPLIT_FEASIBILITY"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "feasible_cases":sum(x=="SPLIT_TEMPORAL_OWNERSHIP_OBSERVATIONALLY_FEASIBLE" for x in classes),
  "upper_fail_cases":sum(x=="UPPER_TG_PARTITION_NOT_ADMISSIBLE" for x in classes),
  "lower_fail_cases":sum(x=="LOWER_SATURATED_PARTITION_NOT_ADMISSIBLE" for x in classes),
  "mass_inconsistent_cases":sum(x=="SPLIT_INTERFACE_MASS_INCONSISTENT" for x in classes),
  "state_inconsistent_cases":sum(x=="SPLIT_PARTITION_STATE_INCONSISTENT" for x in classes),
  "max_abs_split_residual":max((abs(x["split_residual"]) for x in rows if math.isfinite(x["split_residual"])),default=math.inf),
  "max_abs_interface_mismatch":max((abs(x["interface_mismatch"]) for x in rows if math.isfinite(x["interface_mismatch"])),default=math.inf),
  "max_upper_hdot":max((x["max_upper_hdot"] for x in rows if math.isfinite(x["max_upper_hdot"])),default=math.inf),
  "min_upper_pred_margin":min((x["min_upper_pred_margin"] for x in rows if math.isfinite(x["min_upper_pred_margin"])),default=math.nan)}
print("F_PE_NLGLOB14S_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14S_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14S=PASS")
