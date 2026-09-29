#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
 mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
 return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
 if r=="FLUX":
  h=-50.;p=0.;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=.25*(-q)
 elif r=="HEAD":
  h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
 else:
  h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
 return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def last_solve(stdout):
 solves=[]; cur=None
 for line in stdout.splitlines():
  if line.startswith("F_PE_TIMEINT17E_INIT|"):
   if cur: solves.append(cur)
   cur={"bt":[],"gate":[]}
  elif cur is not None and line.startswith("F_PE_TIMEINT17F_BT|"):
   d=fields(line); cur["bt"].append({"iter":int(d["ITER"]),"try":int(d["TRY"]),"max_node":int(d["MAX_NODE"]),
      "max_res":float(d["MAX_RES"]),"top_res":float(d["TOP_RES"]),"bottom_res":float(d["BOTTOM_RES"]),
      "sum_res":float(d["SUM_RES"]),"sump":float(d["SUMP"])})
  elif cur is not None and line.startswith("F_PE_TIMEINT17F_GATE|"):
   d=fields(line); cur["gate"].append({"iter":int(d["ITER"]),"max_node":int(d["MAX_NODE"]),
      "max_res":float(d["MAX_RES"]),"top_res":float(d["TOP_RES"]),"bottom_res":float(d["BOTTOM_RES"]),
      "sum_res":float(d["SUM_RES"]),"max_head_node":int(d["MAX_HEAD_NODE"]),
      "max_head_metric":float(d["MAX_HEAD_METRIC"]),"pond_dev":float(d["POND_DEV"]),
      "bal":int(d["BAL_FAIL"]),"head":int(d["HEAD_FAIL"]),"pond":int(d["POND_FAIL"]),
      "total":int(d["TOTAL_FAIL"]),"converged":int(d["CONVERGED"])})
 if cur: solves.append(cur)
 return solves[-1] if solves else None

def loc(node): return "TOP" if node==1 else ("BOTTOM" if node==16 else "INTERIOR")

rows=[]
for mid in ("B01","B12","O05","O14"):
 m=mats[mid]
 for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
   for mode in modes:
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    row={"material":mid,"route":route,"dt":dt,"mode":mode,"ok":cp.returncode==0,
         "terminal_reason":result["TERMINAL_REASON"] if result else "MISSING_RESULT"}
    sol=last_solve(cp.stdout)
    if row["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE" and sol:
     best_by_iter=[]
     for it in sorted({x["iter"] for x in sol["bt"]}):
      xs=[x for x in sol["bt"] if x["iter"]==it]; best=min(xs,key=lambda x:x["sump"])
      best_by_iter.append(loc(best["max_node"]))
     loc_counts={k:best_by_iter.count(k) for k in ("TOP","INTERIOR","BOTTOM")}
     row["iter_location_counts"]=loc_counts
     row["dominant_location"]=max(loc_counts,key=loc_counts.get) if best_by_iter else "NONE"
     gs=sol["gate"]
     row["gate_counts"]={k:sum(g[k] for g in gs) for k in ("bal","head","pond","total")}
     row["top_balance_iterations"]=sum(g["bal"] and g["max_node"]==1 for g in gs)
     row["interior_balance_iterations"]=sum(g["bal"] and 1<g["max_node"]<16 for g in gs)
     row["bottom_balance_iterations"]=sum(g["bal"] and g["max_node"]==16 for g in gs)
     row["max_abs_pond_dev"]=max((abs(g["pond_dev"]) for g in gs),default=0.)
    rows.append(row)

fails=[x for x in rows if x["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE"]
def subset(mode,route): return [x for x in fails if x["mode"]==mode and x["route"]==route]

route_summary={}
for route in routes:
 tg=subset("TG",route); kl=subset("KLAG",route)
 tg_dom={k:sum(x.get("dominant_location") == k for x in tg) for k in ("TOP","INTERIOR","BOTTOM")}
 kl_dom={k:sum(x.get("dominant_location") == k for x in kl) for k in ("TOP","INTERIOR","BOTTOM")}
 if route=="FLUX":
  if tg and tg_dom["TOP"]/len(tg)>=.75: cls="TIMEINT17F_FLUX_TOP_RESIDUAL_DOMINANT"
  elif tg and tg_dom["INTERIOR"]/len(tg)>=.75: cls="TIMEINT17F_FLUX_INTERIOR_RESIDUAL_DOMINANT"
  elif tg and tg_dom["BOTTOM"]/len(tg)>=.75: cls="TIMEINT17F_FLUX_BOTTOM_RESIDUAL_DOMINANT"
  else: cls="TIMEINT17F_FLUX_DISTRIBUTED_RESIDUAL"
 else:
  pond=sum(x.get("gate_counts",{}).get("pond",0)>0 for x in tg)/len(tg) if tg else 0
  total=sum(x.get("gate_counts",{}).get("total",0)>0 for x in tg)/len(tg) if tg else 0
  top=sum(x.get("top_balance_iterations",0)>0 for x in tg)/len(tg) if tg else 0
  interior=sum(x.get("interior_balance_iterations",0)>0 for x in tg)/len(tg) if tg else 0
  if top>=.75: cls=f"TIMEINT17F_{route}_TOP_COMPARTMENT_GATE"
  elif interior>=.75: cls=f"TIMEINT17F_{route}_INTERIOR_COMPARTMENT_GATE"
  elif pond>=.75: cls=f"TIMEINT17F_{route}_PONDING_GATE"
  elif total>=.75: cls=f"TIMEINT17F_{route}_TOTAL_GATE"
  else: cls=f"TIMEINT17F_{route}_DISTRIBUTED_POSTSTEP_GATE"
 route_summary[route]={"classification":cls,"tg_n":len(tg),"klag_n":len(kl),"tg_dominant_locations":tg_dom,
    "klag_dominant_locations":kl_dom}

pairs=same=0
for x in [q for q in fails if q["mode"]=="TG"]:
 y=next((q for q in fails if q["mode"]=="KLAG" and q["material"]==x["material"] and q["route"]==x["route"] and q["dt"]==x["dt"]),None)
 if y:
  pairs+=1
  if x.get("dominant_location")==y.get("dominant_location") and x.get("gate_counts")==y.get("gate_counts"): same+=1
shared=same/pairs if pairs else 0
summary={"route_summary":route_summary,"matched_pairs":pairs,"same_localization_pairs":same,
 "shared_localization_fraction":shared,
 "secondary_classification":"TIMEINT17F_SHARED_LOCALIZATION" if shared>=.75 else "TIMEINT17F_TG_KLAG_LOCALIZATION_DIVERGENCE",
 "process_failures":sum(not x["ok"] for x in rows)}
print("F_PE_TIMEINT17F_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17F_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17F=PASS")
