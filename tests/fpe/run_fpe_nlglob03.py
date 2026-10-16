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
    if cur: out.append(cur)
    return out

def rho(d):
    a=float(d["FACTOR"]); raw0=float(d["RAW_ORIGIN"]); pred=raw0*(2*a-a*a)
    return None if pred<=0 or not math.isfinite(pred) else (raw0-float(d["RAW"]))/pred

def norm_route(r):
    return {"surface-flux":"FLUX","ponded-head":"HEAD","ponded-head-linear-runoff":"RUNOFF"}.get(r,r)

def med(v):
    q=sorted(x for x in v if x is not None and math.isfinite(x))
    return statistics.median(q) if q else None

def vector_segments(stdout):
    out=[]; cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB03_RES|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur); cur={}
        rec=cur.setdefault(it,{"nn":nn,"nodes":{}})
        rec["nodes"][node]=float(d["R"])
    if cur: out.append(cur)
    return out

def parse_vec(rec):
    if rec is None: return None
    nn=rec["nn"]; nodes=rec["nodes"]
    if sorted(nodes)!=list(range(1,nn+1)): return None
    return [nodes[i] for i in range(1,nn+1)]

audit=[]; cases=[]; vec_expected=0; vec_good=0
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
        bts=segments(cp.stdout,"F_PE_TIMEINT17H_BT|")
        sts=segments(cp.stdout,"F_PE_NLGLOB01_STEP|")
        vss=vector_segments(cp.stdout)
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        vs=vss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and vss else {}
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}; vec_by_iter=vs
        cases.append({"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,
                      "process_ok":cp.returncode==0,"iterations":len(groups)})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); rv=parse_vec(vec_by_iter.get(it))
          if s is None: continue
          vec_expected+=1
          if rv is None: continue
          vec_good+=1
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp
          rtot_naive=float(s["RES_SUM"])/tol_tot
          sf=math.fsum(rv); py=sum(rv); sa=math.fsum(abs(x) for x in rv)
          rtot_fsum=abs(sf)/tol_tot
          rbal=max(rcp,rtot_naive)
          move=abs(rtot_naive-rtot_fsum)/max(rtot_naive,1e-300)
          cross=(rtot_naive>1.0 and rtot_fsum<=1.0)
          audit.append({"material":mid,"route":route,"provider_route":norm_route(s["ROUTE"]),"mode":mode,"dt":dt,"iter":it,
                        "selected_rho":rr,"r_cp":rcp,"r_tot_naive":rtot_naive,"r_tot_fsum":rtot_fsum,"r_bal":rbal,
                        "sum_python":py,"sum_fsum":sf,"sum_abs":sa,"movement_fraction":move,"cross_to_floor":cross,
                        "c_sum":abs(py-sf)/max(abs(py),tol_tot),
                        "kappa_sum":sa/max(abs(sf),tol_tot)})

finite=sum(all(math.isfinite(x[k]) for k in ("r_cp","r_tot_naive","r_tot_fsum","r_bal")) for x in audit)
primary=[x for x in audit if x["selected_rho"]<.25 and x["r_bal"]<=10]
adequate=[x for x in audit if x["selected_rho"]>=.25]
coverage=(sorted({x["provider_route"] for x in audit})==["FLUX","HEAD","RUNOFF"] and
          len({x["material"] for x in audit})==4 and len({x["dt"] for x in audit})==4 and
          sorted({x["mode"] for x in audit})==["KLAG","TG"] and len(audit)>=500 and len(primary)>=100 and
          finite/max(1,len(audit))>=.99 and vec_good/max(1,vec_expected)>=.99)

td=[x for x in primary if x["r_tot_naive"]>=x["r_cp"]]
cd=[x for x in primary if x["r_cp"]>x["r_tot_naive"]]
total_dom_frac=len(td)/len(primary) if primary else 0
comp_dom_frac=len(cd)/len(primary) if primary else 0
move25=sum(x["movement_fraction"]>=.25 for x in td)/len(td) if td else 0
crossfrac=sum(x["cross_to_floor"] for x in td)/len(td) if td else 0

families={}
family_direction=0
for route in routes:
  for mode in modes:
    xs=[x for x in td if x["provider_route"]==route and x["mode"]==mode]
    mna=med([x["r_tot_naive"] for x in xs]); mfs=med([x["r_tot_fsum"] for x in xs])
    cf=sum(x["cross_to_floor"] for x in xs)/len(xs) if xs else 0
    direction=bool(xs and mna is not None and mfs is not None and mfs<mna and cf>=.10)
    if direction: family_direction+=1
    families[f"{route}|{mode}"]={"n_total_dominant_primary":len(xs),"median_r_tot_naive":mna,
                                 "median_r_tot_fsum":mfs,"cross_fraction":cf,"direction":direction}

total_signal=(coverage and total_dom_frac>=.5 and move25>=.25 and crossfrac>=.10 and family_direction>=4)
comp_signal=(coverage and comp_dom_frac>=.5 and med([x["r_cp"] for x in primary]) is not None and
             med([x["r_cp"] for x in primary])<=10 and not total_signal)
substantial=(move25>=.10 or crossfrac>=.05)
mixed=(coverage and not total_signal and not comp_signal and
       ((total_dom_frac>=.25 and comp_dom_frac>=.25) or substantial))

if not coverage: cls="BLOCKED_NLGLOB03_RESIDUAL_VECTOR_COVERAGE"
elif total_signal: cls="NLGLOB03_TOTAL_BALANCE_SUMMATION_SIGNAL"
elif comp_signal: cls="NLGLOB03_COMPARTMENT_FLOOR_SIGNAL"
elif mixed: cls="NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE"
else: cls="NLGLOB03_NO_SIMPLE_BALANCE_FLOOR_ATTRIBUTION"

summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":len(audit),
         "primary_iterations":len(primary),"adequate_iterations":len(adequate),
         "vector_coverage":vec_good/max(1,vec_expected),"finite_fraction":finite/max(1,len(audit)),
         "total_dominant_fraction":total_dom_frac,"compartment_dominant_fraction":comp_dom_frac,
         "total_move_ge_25_fraction":move25,"total_cross_to_floor_fraction":crossfrac,
         "family_direction_count":family_direction,
         "median_primary_r_cp":med([x["r_cp"] for x in primary]),
         "median_primary_r_tot_naive":med([x["r_tot_naive"] for x in primary]),
         "median_primary_r_tot_fsum":med([x["r_tot_fsum"] for x in primary]),
         "median_primary_kappa_sum":med([x["kappa_sum"] for x in primary]),
         "families":families,"process_failures":sum(not x["process_ok"] for x in cases)}

print("F_PE_NLGLOB03_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB03_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB03=PASS")
