#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="FLUX":
        h=-50.; p=0.; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=.25*(-q)
    elif r=="HEAD":
        h=-5.; p=.025; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q
    else:
        h=-5.; p=.1; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q+(p-pmax)/rsro
    return h,p,rain

rows=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        attempts=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14E1_ROOT_ATTEMPT|")]
        modeslog=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
        entries=[x for x in modeslog if int(x.get("ENTRY","0"))==1]
        persists=[x for x in modeslog if int(x.get("ENTRY","0"))==0]
        entry_step=int(entries[0]["STEP"]) if len(entries)==1 else None
        post_attempts=0 if entry_step is None else sum(int(x["STEP"])>entry_step for x in attempts)
        row={"material":mid,"route":route,"mode":mode,"dt":dt,"process_ok":cp.returncode==0,
             "root_attempts":len(attempts),"entry_count":len(entries),"persistent_intervals":len(persists),
             "post_entry_root_attempts":post_attempts,
             "persistent_ok":all(int(x.get("OK","0"))==1 for x in persists)}
        if res:
            row["terminal_reason"]=res["TERMINAL_REASON"]
            row["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
            for k in ("TOP_H","TOP_THETA","MAX_LEDGER","CUM_LEDGER","MAX_ROUNDTRIP","MAX_NATIVE_RATE","MAX_K_SHIFT"):
                row[k.lower()]=float(res[k])
            row["work"]=int(res["WORK"])
            row["steps_done"]=int(res["STEPS_DONE"])
            row["finite"]=all(math.isfinite(row[k]) for k in ("top_h","top_theta","max_ledger","cum_ledger","max_roundtrip","max_native_rate","max_k_shift"))
        else:
            row.update({"terminal_reason":"MISSING_RESULT","complete":False,"finite":False,"work":0,"steps_done":0})
        rows.append(row)

def p3(rs,key):
    a,b,c=rs[1],rs[2],rs[3]
    if not all(x["complete"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-13*scale or d2<=1e-13*scale: return None
    return math.log(d1/d2,2.0)

ladders=[]; head_orders=[]; theta_orders=[]; head_pass=0
for mid in ("B01","B12","O05","O14"):
  for route in routes:
    rs=sorted([x for x in rows if x["material"]==mid and x["route"]==route and x["mode"]=="TG"],key=lambda x:-x["dt"])
    ph=p3(rs,"top_h") if len(rs)==4 else None
    pt=p3(rs,"top_theta") if len(rs)==4 else None
    if ph is not None and math.isfinite(ph): head_orders.append(ph)
    if pt is not None and math.isfinite(pt): theta_orders.append(pt)
    if ph is not None and ph>=1.5: head_pass+=1
    ladders.append({"material":mid,"route":route,"complete":len(rs)==4 and all(x["complete"] for x in rs),
                    "refined_top_head_order":ph,"refined_top_theta_order":pt})

work_ratios=[]
for tg in [x for x in rows if x["mode"]=="TG" and x["complete"]]:
    kl=next((x for x in rows if x["mode"]=="KLAG" and x["material"]==tg["material"] and
             x["route"]==tg["route"] and x["dt"]==tg["dt"] and x["complete"]),None)
    if kl and tg["steps_done"]>0 and kl["steps_done"]>0 and kl["work"]>0:
        work_ratios.append((tg["work"]/tg["steps_done"])/(kl["work"]/kl["steps_done"]))

tgrows=[x for x in rows if x["mode"]=="TG"]; klrows=[x for x in rows if x["mode"]=="KLAG"]
all_complete=all(x["complete"] for x in rows)
tg_ladders_complete=all(x["complete"] for x in ladders)
med_h=statistics.median(head_orders) if head_orders else None
med_t=statistics.median(theta_orders) if theta_orders else None
med_work=statistics.median(work_ratios) if work_ratios else None
max_ledger=max(abs(x.get("max_ledger",math.inf)) for x in rows)
max_cum=max(abs(x.get("cum_ledger",math.inf)) for x in rows)
max_round=max(x.get("max_roundtrip",math.inf) for x in tgrows)
max_native=max(x.get("max_native_rate",math.inf) for x in tgrows)
k_ok=all(math.isfinite(x.get("max_k_shift",math.nan)) and x.get("max_k_shift",0)>0 for x in tgrows)
semantic_ok=all(x["post_entry_root_attempts"]==0 and x["persistent_ok"] and x["entry_count"] in (0,1) for x in rows)
finite_ok=all(x["finite"] for x in rows)
route_ok=all(x["terminal_reason"]=="COMPLETE_SAME_ROUTE" for x in rows)

qualified=bool(proc==0 and tg_ladders_complete and all(x["complete"] for x in klrows) and
               med_h is not None and med_h>=1.6 and med_t is not None and med_t>=1.6 and head_pass>=9 and
               max_ledger<=5e-8 and max_cum<=5e-8 and max_round<=1e-12 and k_ok and max_native<=5e-8 and
               finite_ok and route_ok and med_work is not None and med_work<=1.20 and semantic_ok)

if max_ledger>5e-8 or max_cum>5e-8:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION"
elif proc or not tg_ladders_complete or not all(x["complete"] for x in klrows) or not finite_ok or not route_ok or not semantic_ok:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS"
elif med_h is None or med_t is None or med_h<1.6 or med_t<1.6 or head_pass<9:
    cls="CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL"
elif qualified:
    cls="QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE"
else:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS"

summary={"classification":cls,"qualified":qualified,"case_count":len(rows),"process_failures":proc,
         "tg_ladders_complete":tg_ladders_complete,"klag_complete":all(x["complete"] for x in klrows),
         "median_refined_top_head_order":med_h,"median_refined_top_theta_order":med_t,
         "head_ladders_order_ge_1p5":head_pass,"max_ledger":max_ledger,"max_cumulative_ledger":max_cum,
         "max_roundtrip":max_round,"max_native_rate":max_native,"predicted_k_ok":k_ok,
         "finite_ok":finite_ok,"route_ok":route_ok,"semantic_ok":semantic_ok,
         "median_work_ratio_vs_klag":med_work,"ladders":ladders}
print("F_PE_TIMEINT17R_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17R=PASS")
