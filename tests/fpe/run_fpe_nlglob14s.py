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

    bystep={}; capstep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
    for x in caps: capstep.setdefault(int(x["STEP"]),[]).append(x)

    series=[]
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: continue
      sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
      series.append((step,sat,xs))

    hand=None
    for i in range(len(series)-1):
      a,b=series[i],series[i+1]
      if len(a[1])==14 and len(b[1])==13 and 3 in a[1] and 3 not in b[1] and b[1]==list(range(4,17)):
        hand=b; break

    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    control_ok=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1 and
                    maxledger<=5e-8 and cumledger<=5e-8)

    rec={"material":"O05","route":route,"dt":dt,"control_ok":control_ok,
         "max_ledger":maxledger,"cum_ledger":cumledger}
    if hand is None:
      rec.update({"classification":"SPLIT_GEOMETRY_NOT_APPLICABLE"})
      rows.append(rec); continue

    step,sat,xs=hand
    cs=sorted(capstep.get(step,[]),key=lambda q:int(q["NODE"]))
    if len(cs)!=16:
      rec.update({"classification":"UPPER_TG_DOMAIN_INADMISSIBLE"})
      rows.append(rec); continue

    heads=[float(x["H"]) for x in xs]
    theta=[float(x["THETA"]) for x in xs]
    caps_v=[float(x["CAP"]) for x in cs]
    kval=[kprovider(m,h) for h in heads]
    qface=[None]*17
    for j in range(1,16):
      km=.5*(kval[j-1]+kval[j])
      qface[j+1]=-km*((heads[j-1]-heads[j])/10.0+1.0)
    qtop=float(xs[0]["TOP_FLUX"]); qbot=float(xs[0]["BOTTOM_FLUX"])

    td=[]
    for node in range(1,17):
      if node==1: v=(qface[2]-qtop)/dz
      elif node==16: v=(qbot-qface[16])/dz
      else: v=(qface[node+1]-qface[node])/dz
      td.append(v)

    qint=qface[4]
    upper_rate=sum(td[:3])*dz
    lower_rate=sum(td[3:])*dz
    full_rate=sum(td)*dz
    upper_from_bounds=qint-qtop
    lower_from_bounds=qbot-qint
    interface_cancel=(upper_from_bounds+lower_from_bounds)-(qbot-qtop)
    split_closure=(upper_rate+lower_rate)-full_rate

    upper_ok=all(heads[i]<0 and theta[i]<m["theta_s"] and math.isfinite(caps_v[i]) and caps_v[i]>0 for i in range(3))
    hd=[]; ht=[]; pk=[]
    if upper_ok:
      for i in range(3):
        hdot=td[i]/caps_v[i]; htilde=heads[i]+dt*hdot
        hd.append(hdot); ht.append(htilde); pk.append(kprovider(m,htilde))
      upper_ok=all(math.isfinite(v) for v in hd+ht+pk) and all(v>0 for v in pk)

    finite=all(math.isfinite(v) for v in td+[qint,upper_rate,lower_rate,full_rate,interface_cancel,split_closure])
    mass_split_ok=(abs(split_closure)<=1e-12 and abs(interface_cancel)<=1e-12 and
                   abs(upper_rate-upper_from_bounds)<=1e-12 and abs(lower_rate-lower_from_bounds)<=1e-12)

    if sat!=list(range(4,17)):
      cls="SPLIT_GEOMETRY_NOT_APPLICABLE"
    elif not upper_ok:
      cls="UPPER_TG_DOMAIN_INADMISSIBLE"
    elif not finite or not mass_split_ok:
      cls="SPLIT_INTERFACE_MASS_INCONSISTENT"
    elif not control_ok:
      cls="SPLIT_INTERFACE_MASS_INCONSISTENT"
    else:
      cls="SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE"

    rec.update({"classification":cls,"step":step,"sat_nodes":sat,"interface_flux":qint,
      "upper_storage_rate":upper_rate,"lower_storage_rate":lower_rate,"full_storage_rate":full_rate,
      "upper_boundary_rate":upper_from_bounds,"lower_boundary_rate":lower_from_bounds,
      "interface_cancel":interface_cancel,"split_closure":split_closure,
      "upper_predictor_ok":upper_ok,"upper_max_abs_hdot":max((abs(v) for v in hd),default=None),
      "upper_min_htilde":min(ht,default=None),"upper_max_htilde":max(ht,default=None),
      "upper_min_pred_k":min(pk,default=None),"finite":finite,"mass_split_ok":mass_split_ok})
    rows.append(rec)

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x["control_ok"] for x in rows)
if coverage and all(x=="SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE" for x in classes):
  cls="NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE"
elif any(x=="SPLIT_INTERFACE_MASS_INCONSISTENT" for x in classes):
  cls="NLGLOB14S_SPLIT_INTERFACE_MASS_INCONSISTENT"
elif any(x=="UPPER_TG_DOMAIN_INADMISSIBLE" for x in classes):
  cls="NLGLOB14S_UPPER_TG_DOMAIN_INADMISSIBLE"
else:
  cls="NLGLOB14S_MIXED_SPLIT_FEASIBILITY"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
  "feasible_cases":sum(x=="SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE" for x in classes),
  "mass_inconsistent_cases":sum(x=="SPLIT_INTERFACE_MASS_INCONSISTENT" for x in classes),
  "upper_inadmissible_cases":sum(x=="UPPER_TG_DOMAIN_INADMISSIBLE" for x in classes),
  "geometry_cases":sum(x=="SPLIT_GEOMETRY_NOT_APPLICABLE" for x in classes),
  "max_abs_split_closure":max((abs(x.get("split_closure",math.inf)) for x in rows),default=math.inf),
  "max_abs_interface_cancel":max((abs(x.get("interface_cancel",math.inf)) for x in rows),default=math.inf),
  "max_control_ledger":max((x["max_ledger"] for x in rows),default=math.inf)}
print("F_PE_NLGLOB14S_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14S_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14S=PASS")
