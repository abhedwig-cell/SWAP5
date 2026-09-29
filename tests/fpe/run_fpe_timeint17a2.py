#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]
horizon=0.001
dtop=10.0; pmax=0.05; rsro=0.05

def k_vg(m,h):
    tr=m["theta_r"]; ts=m["theta_s"]; alpha=m["alpha"]; n=m["n"]; l=m["lambda"]; ks=m["ksat"]
    mm=1.0-1.0/n
    se=(1.0+(abs(alpha*h))**n)**(-mm)
    term=(1.0-(1.0-se**(1.0/mm))**mm)
    return ks*(se**l)*(term**2)

def fixture(m,route):
    if route=="FLUX":
        h=-50.0; p=0.0
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        rain=0.25*(-qhead)
        return h,p,rain,{"ktop":kt,"qhead":qhead,"capacity":-qhead,"capacity_slack":-qhead-rain}
    if route=="HEAD":
        h=-5.0; p=0.025
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        rain=-qhead
        return h,p,rain,{"ktop":kt,"qhead":qhead,"pdot0":0.0}
    h=-5.0; p=0.100
    kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
    qhead=-kf*((p-h)/dtop+1.0)
    r0=(p-pmax)/rsro
    rain=-qhead+r0
    return h,p,rain,{"ktop":kt,"qhead":qhead,"runoff0":r0,"pdot0":0.0}

def run(mid,route,dt,mode):
    m=mats[mid]; h0,p0,rain,diag=fixture(m,route)
    cmd=[str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"route":route,"dt":dt,"mode":mode,"rain":rain,"fixture":diag,
         "ok":cp.returncode==0,"stdout":cp.stdout[-1800:],"stderr":cp.stderr[-1200:]}
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
    if d1<=1e-14*scale or d2<=1e-14*scale: return None
    return math.log(d1/d2,2.0)

rows=[]; bases=[]
for mid in ("B01","B12","O05","O14"):
    for route in ("FLUX","HEAD","RUNOFF"):
        for dt in dts:
            rows.append(run(mid,route,dt,"TG"))
            bases.append(run(mid,route,dt,"KLAG"))

cases=[]; head_orders=[]; theta_orders=[]; pond_orders=[]; ratios=[]
eligible_ladders=0; materials=set(); routes=set()
for mid in ("B01","B12","O05","O14"):
    for route in ("FLUX","HEAD","RUNOFF"):
        rs=sorted([x for x in rows if x["material"]==mid and x["route"]==route],key=lambda x:-x["dt"])
        bs=sorted([x for x in bases if x["material"]==mid and x["route"]==route],key=lambda x:-x["dt"])
        eligible=all(x["ok"] and x["eligible"]==1 for x in rs)
        ph=order(rs,"top_h") if len(rs)==4 else None
        pt=order(rs,"top_theta") if len(rs)==4 else None
        pp=order(rs,"pond") if route!="FLUX" and len(rs)==4 else None
        if eligible:
            eligible_ladders+=1; materials.add(mid); routes.add(route)
            if ph is not None and math.isfinite(ph): head_orders.append(ph)
            if pt is not None and math.isfinite(pt): theta_orders.append(pt)
            if pp is not None and math.isfinite(pp): pond_orders.append(pp)
        local=[]
        for x,b in zip(rs,bs):
            if x["ok"] and x.get("eligible")==1 and b["ok"] and b.get("eligible")==1 and b.get("work_per_step",0)>0:
                rr=x["work_per_step"]/b["work_per_step"]; local.append(rr); ratios.append(rr)
        cases.append({
          "material":mid,"route":route,"eligible":eligible,
          "rain":rs[0]["rain"] if rs else None,
          "transition_steps":[x.get("transition_step") for x in rs],
          "head_order":ph,"theta_order":pt,"pond_order":pp,
          "max_ledger":max((abs(x.get("max_ledger",float("inf"))) for x in rs if x["ok"]),default=None),
          "max_cumulative":max((abs(x.get("cum_ledger",float("inf"))) for x in rs if x["ok"]),default=None),
          "max_roundtrip":max((x.get("max_roundtrip",float("inf")) for x in rs if x["ok"]),default=None),
          "max_native_rate":max((x.get("max_native_rate",float("inf")) for x in rs if x["ok"]),default=None),
          "max_surface_rate_residual":max((x.get("max_surface_rate_residual",float("inf")) for x in rs if x["ok"]),default=None),
          "median_work_ratio":statistics.median(local) if local else None
        })

eligible=[c for c in cases if c["eligible"]]
medh=statistics.median(head_orders) if head_orders else None
medt=statistics.median(theta_orders) if theta_orders else None
medp=statistics.median(pond_orders) if pond_orders else None
headfrac=sum(x>=1.5 for x in head_orders)/len(head_orders) if head_orders else 0.0
ledger=all(c["max_ledger"] is not None and c["max_ledger"]<=5e-8 and c["max_cumulative"]<=5e-8 for c in eligible)
rt=all(c["max_roundtrip"] is not None and c["max_roundtrip"]<=1e-12 for c in eligible)
native=all(c["max_native_rate"] is not None and c["max_native_rate"]<=5e-8 for c in eligible)
surf=all(c["max_surface_rate_residual"] is not None and c["max_surface_rate_residual"]<=5e-8 for c in eligible)
work=statistics.median(ratios) if ratios else None
bankok=eligible_ladders>=8 and len(materials)>=3 and len(routes)==3
orderok=(medh is not None and medh>=1.6 and medt is not None and medt>=1.6 and headfrac>=0.75 and
         (medp is None or medp>=1.6))
advance=bool(bankok and orderok and ledger and rt and native and surf and work is not None and work<=1.20)

if not bankok:
    cls="BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT"
elif not ledger:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION"
elif not orderok:
    cls="CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL"
elif not advance:
    cls="BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS"
else:
    cls="QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE"

summary={"classification":cls,"advance":advance,"eligible_ladders":eligible_ladders,
         "materials":sorted(materials),"routes":sorted(routes),
         "median_head_order":medh,"median_theta_order":medt,"median_pond_order":medp,
         "head_orders_ge_1p5_fraction":headfrac,"ledger_ok":ledger,"roundtrip_ok":rt,
         "native_balance_ok":native,"surface_collocation_ok":surf,
         "median_work_ratio_vs_klag":work,"cases":cases}
print("F_PE_TIMEINT17A2_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A2_BASELINES="+json.dumps(bases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A2_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17A2=PASS")
