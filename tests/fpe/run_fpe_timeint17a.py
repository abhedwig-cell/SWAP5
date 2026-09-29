#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
routes={
 "FLUX":{"h0":-50.0,"p0":0.0,"rain":2.0},
 "HEAD":{"h0":-5.0,"p0":0.020,"rain":12.0},
 "RUNOFF":{"h0":-5.0,"p0":0.080,"rain":25.0},
}
dts=[0.0025,0.00125,0.000625,0.0003125]
horizon=0.010

def run(mid,route,dt,mode):
    m=mats[mid]; q=routes[route]
    cmd=[str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(q["h0"]),str(q["p0"]),str(q["rain"]),str(dt),str(horizon)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"route":route,"dt":dt,"mode":mode,"ok":cp.returncode==0,
         "stdout":cp.stdout[-1800:],"stderr":cp.stderr[-1200:]}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        if not line:
            row.update(ok=False,stderr="missing result")
        else:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("ELIGIBLE","TRANSITION_STEP","STEPS_DONE","NL","BACK","JAC","LIN","WORK"):
                row[k.lower()]=int(d[k])
            for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE","RUNOFF","MAX_LEDGER",
                      "CUM_LEDGER","MAX_ROUNDTRIP","MAX_NATIVE_RATE","MAX_SURFACE_RATE_RESIDUAL","MAX_K_SHIFT"):
                row[k.lower()]=float(d[k])
            row["work_per_step"]=row["work"]/max(1,row["steps_done"])
    return row

def order(rs,key):
    a,b,c=rs[1],rs[2],rs[3]
    if not all(x["ok"] and x["eligible"]==1 for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-13*scale or d2<=1e-13*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; bases=[]
for mid in ("B01","B12","O05","O14"):
    for route in ("FLUX","HEAD","RUNOFF"):
        for dt in dts:
            rows.append(run(mid,route,dt,"TG"))
            bases.append(run(mid,route,dt,"KLAG"))

cases=[]; head_orders=[]; theta_orders=[]; pond_orders=[]; ratios=[]
eligible_ladders=0; materials=set(); route_set=set()
for mid in ("B01","B12","O05","O14"):
    for route in ("FLUX","HEAD","RUNOFF"):
        rs=sorted([x for x in rows if x["material"]==mid and x["route"]==route],key=lambda x:-x["dt"])
        bs=sorted([x for x in bases if x["material"]==mid and x["route"]==route],key=lambda x:-x["dt"])
        eligible=all(x["ok"] and x["eligible"]==1 for x in rs)
        ph=order(rs,"top_h") if len(rs)==4 else None
        pt=order(rs,"top_theta") if len(rs)==4 else None
        pp=order(rs,"pond") if route!="FLUX" and len(rs)==4 else None
        if eligible:
            eligible_ladders+=1; materials.add(mid); route_set.add(route)
            if ph is not None and math.isfinite(ph): head_orders.append(ph)
            if pt is not None and math.isfinite(pt): theta_orders.append(pt)
            if pp is not None and math.isfinite(pp): pond_orders.append(pp)
        local=[]
        for x,b in zip(rs,bs):
            if x["ok"] and x.get("eligible")==1 and b["ok"] and b.get("eligible")==1 and b.get("work_per_step",0)>0:
                rr=x["work_per_step"]/b["work_per_step"]; ratios.append(rr); local.append(rr)
        cases.append({
            "material":mid,"route":route,"eligible":eligible,
            "transition_steps":[x.get("transition_step") for x in rs],
            "head_order":ph,"theta_order":pt,"pond_order":pp,
            "max_ledger":max((abs(x.get("max_ledger",float("inf"))) for x in rs if x["ok"]),default=None),
            "max_cumulative":max((abs(x.get("cum_ledger",float("inf"))) for x in rs if x["ok"]),default=None),
            "max_roundtrip":max((x.get("max_roundtrip",float("inf")) for x in rs if x["ok"]),default=None),
            "max_native_rate":max((x.get("max_native_rate",float("inf")) for x in rs if x["ok"]),default=None),
            "max_surface_rate_residual":max((x.get("max_surface_rate_residual",float("inf")) for x in rs if x["ok"]),default=None),
            "median_work_ratio":statistics.median(local) if local else None
        })

eligible_cases=[c for c in cases if c["eligible"]]
med_h=statistics.median(head_orders) if head_orders else None
med_t=statistics.median(theta_orders) if theta_orders else None
med_p=statistics.median(pond_orders) if pond_orders else None
head_ge=sum(p>=1.5 for p in head_orders)
head_frac=head_ge/len(head_orders) if head_orders else 0.0
ledger=all(c["max_ledger"] is not None and c["max_ledger"]<=5e-8 and c["max_cumulative"]<=5e-8 for c in eligible_cases)
rt=all(c["max_roundtrip"] is not None and c["max_roundtrip"]<=1e-12 for c in eligible_cases)
native=all(c["max_native_rate"] is not None and c["max_native_rate"]<=5e-8 for c in eligible_cases)
surf=all(c["max_surface_rate_residual"] is not None and c["max_surface_rate_residual"]<=5e-8 for c in eligible_cases)
kfinite=all(all(math.isfinite(x.get("max_k_shift",float("nan"))) for x in rows if x["material"]==c["material"] and x["route"]==c["route"] and x["ok"]) for c in eligible_cases)
medwork=statistics.median(ratios) if ratios else None

bank_ok=(eligible_ladders>=8 and len(materials)>=3 and len(route_set)==3)
order_ok=(med_h is not None and med_h>=1.6 and med_t is not None and med_t>=1.6 and head_frac>=0.75 and
          (med_p is None or med_p>=1.6))
advance=bool(bank_ok and order_ok and ledger and rt and native and surf and kfinite and medwork is not None and medwork<=1.20)

if not bank_ok:
    cls="BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE"
elif not ledger:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION"
elif not order_ok:
    cls="CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL"
elif not advance:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS"
else:
    cls="QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE"

summary={
 "classification":cls,"advance":advance,"eligible_ladders":eligible_ladders,
 "materials":sorted(materials),"routes":sorted(route_set),
 "median_head_order":med_h,"median_theta_order":med_t,"median_pond_order":med_p,
 "head_orders_ge_1p5_fraction":head_frac,"ledger_ok":ledger,"roundtrip_ok":rt,
 "native_balance_ok":native,"surface_collocation_ok":surf,"predicted_k_diagnostic_finite":kfinite,
 "median_work_ratio_vs_klag":medwork,"cases":cases
}
print("F_PE_TIMEINT17A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A_BASELINES="+json.dumps(bases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A=PASS")
