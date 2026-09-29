#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
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
def segments(stdout,prefix):
    out=[]; cur=[]
    for line in stdout.splitlines():
        if not line.startswith(prefix): continue
        d=fields(line); it=int(d["ITER"])
        if it==1 and cur: out.append(cur); cur=[]
        cur.append(d)
    if cur: out.append(cur)
    return out
def split_bt(seg):
    out=[];cur=[];it=None
    for d in seg:
        i=int(d["ITER"])
        if it is None or i==it: cur.append(d);it=i
        else: out.append(cur);cur=[d];it=i
    if cur:out.append(cur)
    return out
def rho(d):
    a=float(d["FACTOR"]); raw0=float(d["RAW_ORIGIN"]); pred=raw0*(2*a-a*a)
    return None if pred<=0 or not math.isfinite(pred) else (raw0-float(d["RAW"]))/pred
def norm_route(r):
    return {"surface-flux":"FLUX","ponded-head":"HEAD","ponded-head-linear-runoff":"RUNOFF"}.get(r,r)
def med(v):
    x=sorted(y for y in v if y is not None and math.isfinite(y))
    return statistics.median(x) if x else None

audit=[]; cases=[]
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        terminal=result["TERMINAL_REASON"] if result else "MISSING_RESULT"
        bts=segments(cp.stdout,"F_PE_TIMEINT17H_BT|"); sts=segments(cp.stdout,"F_PE_NLGLOB01_STEP|")
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}
        cases.append({"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,
                      "process_ok":cp.returncode==0,"iterations":len(groups)})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it)
          if s is None: continue
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          res_inf=float(s["RES_INF"]); res_sum=float(s["RES_SUM"])
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=res_inf/tol_cp if tol_cp>0 else math.inf
          rtot=res_sum/tol_tot if tol_tot>0 else math.inf
          rbal=max(rcp,rtot)
          audit.append({"material":mid,"route":route,"provider_route":norm_route(s["ROUTE"]),"mode":mode,"dt":dt,"iter":it,
                        "selected_rho":rr,"selected_factor":float(selected["FACTOR"]),
                        "res_inf":res_inf,"res_sum":res_sum,"tol_cp":tol_cp,"tol_tot":tol_tot,
                        "r_cp":rcp,"r_tot":rtot,"r_bal":rbal,
                        "z_h_inf":float(s["ZH_INF"]),"dh_inf":float(s["DH_INF"])})

poor=[x for x in audit if x["selected_rho"]<.25]; adequate=[x for x in audit if x["selected_rho"]>=.25]
finite=sum(math.isfinite(x["r_bal"]) for x in audit)
routes_seen=sorted({x["provider_route"] for x in audit}); mats_seen=sorted({x["material"] for x in audit})
dts_seen=sorted({x["dt"] for x in audit}); modes_seen=sorted({x["mode"] for x in audit})
coverage=(routes_seen==["FLUX","HEAD","RUNOFF"] and len(mats_seen)==4 and len(dts_seen)==4 and modes_seen==["KLAG","TG"]
          and len(audit)>=500 and len(poor)>=100 and finite/max(1,len(audit))>=.99)

def nearfrac(xs): return sum(x["r_bal"]<=10 for x in xs)/len(xs) if xs else 0.0
poor_near=nearfrac(poor); adequate_near=nearfrac(adequate)
poor_med=med([x["r_bal"] for x in poor]); adequate_med=med([x["r_bal"] for x in adequate])

families={}
final_family_pass=0
for route in routes:
  for mode in modes:
    xs=[x for x in audit if x["provider_route"]==route and x["mode"]==mode]
    pp=[x for x in xs if x["selected_rho"]<.25]
    final_by_case=[]
    for mid in ("B01","B12","O05","O14"):
      for dt in dts:
        ys=[x for x in xs if x["material"]==mid and x["dt"]==dt]
        if ys: final_by_case.append(max(ys,key=lambda x:x["iter"]))
    fm=med([x["r_bal"] for x in final_by_case])
    pmed=med([x["r_bal"] for x in pp]); pnear=nearfrac(pp)
    if fm is not None and fm<=10: final_family_pass+=1
    families[f"{route}|{mode}"]={"n":len(xs),"poor_n":len(pp),"poor_near_fraction":pnear,
                                 "poor_median_r_bal":pmed,"final_median_r_bal":fm}

aggregate=(coverage and poor_near>=.5 and adequate_near>0 and poor_near>=1.5*adequate_near and
           poor_med is not None and poor_med<=10 and final_family_pass>=4)
route_specific=(coverage and not aggregate and
                all(families[f"FLUX|{m}"]["poor_near_fraction"]>=.5 and
                    families[f"FLUX|{m}"]["poor_median_r_bal"] is not None and
                    families[f"FLUX|{m}"]["poor_median_r_bal"]<=10 for m in modes)
                and any(not (families[f"{r}|{m}"]["poor_near_fraction"]>=.5 and
                             families[f"{r}|{m}"]["poor_median_r_bal"] is not None and
                             families[f"{r}|{m}"]["poor_median_r_bal"]<=10)
                        for r in ("HEAD","RUNOFF") for m in modes))
not_dom=(coverage and poor_near<.25 and poor_med is not None and poor_med>10)
if not coverage: cls="BLOCKED_NLGLOB02_FLOOR_COVERAGE"
elif aggregate: cls="NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL"
elif route_specific: cls="NLGLOB02_ROUTE_SPECIFIC_BALANCE_FLOOR_SIGNAL"
elif not_dom: cls="NLGLOB02_BALANCE_FLOOR_NOT_DOMINANT"
else: cls="NLGLOB02_MIXED_BALANCE_FLOOR_SIGNAL"

bands=lambda xs:{"AT_FLOOR":sum(x["r_bal"]<=1 for x in xs),
                 "NEAR_FLOOR":sum(1<x["r_bal"]<=10 for x in xs),
                 "ABOVE_FLOOR":sum(x["r_bal"]>10 for x in xs)}
summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":len(audit),"poor_model_iterations":len(poor),
         "finite_fraction":finite/max(1,len(audit)),"poor_near_floor_fraction":poor_near,
         "adequate_near_floor_fraction":adequate_near,"poor_to_adequate_near_ratio":poor_near/adequate_near if adequate_near>0 else None,
         "poor_median_r_bal":poor_med,"adequate_median_r_bal":adequate_med,"final_family_median_le_10_count":final_family_pass,
         "poor_bands":bands(poor),"adequate_bands":bands(adequate),"route_mode":families,
         "routes":routes_seen,"materials":mats_seen,"dt_levels":dts_seen,"modes":modes_seen,
         "process_failures":sum(not x["process_ok"] for x in cases)}
print("F_PE_NLGLOB02_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB02_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB02=PASS")
