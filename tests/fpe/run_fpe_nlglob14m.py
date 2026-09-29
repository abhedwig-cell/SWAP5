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
    inconsistent=False
    for x in states:
      bystep.setdefault(int(x["STEP"]),[]).append(x)
      if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1):
        inconsistent=True

    series=[]; finite=True; noncontig=False
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: finite=False; continue
      sat=[]; nodes={}
      for x in xs:
        node=int(x["NODE"]); h=float(x["H"]); th=float(x["THETA"]); ts=float(x["THETA_S"])
        if not all(math.isfinite(v) for v in (h,th,ts)): finite=False
        sh=int(x["SAT_H"])==1; st=int(x["SAT_THETA"])==1
        if sh!=st: inconsistent=True
        if sh and st: sat.append(node)
        nodes[node]={"h":h,"theta":th,"theta_s":ts,"sat":sh and st}
      contiguous=(not sat) or sat==list(range(min(sat),17))
      if not contiguous: noncontig=True
      series.append({"step":step,"time":step*dt,"sat_count":len(sat),
                     "shallow":min(sat) if sat else 0,"nodes":nodes,"contiguous":contiguous})

    bracket_ok=False; retreat_node=0; tA=tB=troot=hA=hB=math.nan
    max_count=max((x["sat_count"] for x in series),default=0)
    peak_indices=[i for i,x in enumerate(series) if x["sat_count"]==max_count]
    if peak_indices:
      last_peak=peak_indices[-1]
      peak_state=series[last_peak]
      retreat_node=peak_state["shallow"]
      if retreat_node>0 and last_peak+1<len(series):
        A=series[last_peak]; B=series[last_peak+1]
        a=A["nodes"][retreat_node]; b=B["nodes"][retreat_node]
        hA=a["h"]; hB=b["h"]; tA=A["time"]; tB=B["time"]
        thetaA=a["theta"]; thetaB=b["theta"]; thetaS=a["theta_s"]
        immediate=(B["step"]==A["step"]+1)
        indicators=(a["sat"] and (not b["sat"]))
        signs=(hA>=0.0 and hB<0.0 and thetaA==thetaS and thetaB<thetaS)
        denom=hB-hA
        if immediate and indicators and signs and denom!=0 and math.isfinite(denom):
          troot=tA+(0.0-hA)/denom*(tB-tA)
          bracket_ok=(tA<=troot<=tB and math.isfinite(troot))

    complete=False; mass_ok=False; maxledger=math.inf; cumledger=math.inf; terminal="MISSING"
    if res:
      complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
      terminal=res["TERMINAL_REASON"]; maxledger=abs(float(res["MAX_LEDGER"])); cumledger=abs(float(res["CUM_LEDGER"]))
      mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    rows.append({"material":"O05","route":route,"dt":dt,"retreat_node":retreat_node,
                 "max_sat_count":max_count,"bracket_ok":bracket_ok,"t_A":tA,"t_B":tB,"t_root":troot,
                 "h_A":hA,"h_B":hB,"bracket_width":tB-tA if bracket_ok else math.nan,
                 "state_finite":finite,"indicator_consistent":not inconsistent,"contiguous":not noncontig,
                 "complete":complete,"terminal_reason":terminal,"mass_ok":mass_ok,
                 "max_ledger":maxledger,"cum_ledger":cumledger})

coverage=(len(rows)==8 and proc==0 and all(x["complete"] and x["mass_ok"] and x["state_finite"] and
          x["indicator_consistent"] and x["contiguous"] for x in rows))

family={}
for route in routes:
    xs=sorted([x for x in rows if x["route"]==route],key=lambda x:-x["dt"])
    valid=len(xs)==4 and all(x["bracket_ok"] for x in xs)
    if valid:
      roots=[x["t_root"] for x in xs]
      dmid=abs(roots[2]-roots[1]); dfine=abs(roots[3]-roots[2])
      signal=(dfine<=dmid and dfine<=2*0.0000625)
    else:
      dmid=dfine=math.inf; signal=False
    family[route]={"valid":valid,"signal":signal,"D_mid":dmid,"D_fine":dfine,
                   "roots":[x["t_root"] for x in xs],"brackets":[[x["t_A"],x["t_B"]] for x in xs]}

if not coverage:
    cls="BLOCKED_NLGLOB14M_RETREAT_EVENT_LOCALIZATION"
elif any(not x["indicator_consistent"] or not x["state_finite"] or not x["mass_ok"] for x in rows):
    cls="NLGLOB14M_RETREAT_EVENT_STATE_INCONSISTENT"
elif all(family[r]["signal"] for r in routes):
    cls="NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED"
elif any(family[r]["signal"] for r in routes):
    cls="NLGLOB14M_MIXED_RETREAT_EVENT_LOCALIZATION"
else:
    cls="NLGLOB14M_RETREAT_EVENT_DT_SENSITIVE"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "family":family,"all_brackets_ok":all(x["bracket_ok"] for x in rows),
         "retreat_nodes":sorted(set(x["retreat_node"] for x in rows)),
         "all_mass_ok":all(x["mass_ok"] for x in rows),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14M_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14M_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14M=PASS")
