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
    out=[]; cur=[]; it=None
    for d in seg:
        i=int(d["ITER"])
        if it is None or i==it: cur.append(d); it=i
        else: out.append(cur); cur=[d]; it=i
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

def term_segments(stdout):
    out=[]; cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB04_TERM|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur); cur={}
        rec=cur.setdefault(it,{"nn":nn,"nodes":{}})
        rec["nodes"][node]={k:float(d[k]) for k in ("S","U","L","Q","T","R")}
    if cur: out.append(cur)
    return out

def valid_terms(rec):
    if rec is None: return False
    return sorted(rec["nodes"])==list(range(1,rec["nn"]+1))

def term_metrics(rec,node):
    d=rec["nodes"][node]
    vals={k:d[k] for k in ("S","U","L","Q","T")}
    sa=sum(abs(v) for v in vals.values())
    rem=d["R"]-sum(vals.values())
    gate=max(1e-14,1e-10*sa)
    order=sorted(vals.items(),key=lambda kv:abs(kv[1]),reverse=True)
    (k1,v1),(k2,v2)=order[:2]
    opposite=(v1*v2<0.0)
    storage_flux=opposite and (("S" in (k1,k2)) and any(k in ("U","L","T") for k in (k1,k2)))
    return {"node":node,"R":d["R"],"sum_abs_terms":sa,"remainder":rem,"decomp_gate":gate,
            "decomp_ok":abs(rem)<=gate,"cancel_ratio":sa/max(abs(d["R"]),1e-300),
            "residual_fraction":abs(d["R"])/max(sa,1e-300),"pair":[k1,k2],
            "pair_opposite":opposite,"storage_flux_pair":storage_flux}

audit=[]; cases=[]; expected_nodes=0; valid_nodes=0; exact_nodes=0
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
        tss=term_segments(cp.stdout)
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        ts=tss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and tss else {}
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}; term_by_iter=ts
        cases.append({"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,
                      "process_ok":cp.returncode==0,"iterations":len(groups)})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); trm=term_by_iter.get(it)
          if s is None or trm is None: continue
          expected_nodes += trm["nn"]
          if not valid_terms(trm): continue
          valid_nodes += trm["nn"]
          ms=[term_metrics(trm,n) for n in range(1,trm["nn"]+1)]
          exact_nodes += sum(x["decomp_ok"] for x in ms)
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1]); rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp; rtot=float(s["RES_SUM"])/tol_tot; rbal=max(rcp,rtot)
          node_res=int(s["NODE_RES"]); dm=ms[node_res-1]
          audit.append({"material":mid,"route":norm_route(s["ROUTE"]),"mode":mode,"dt":dt,"iter":it,
                        "selected_rho":rr,"r_cp":rcp,"r_tot":rtot,"r_bal":rbal,
                        "balance_dominance":"TOTAL" if rtot>=rcp else "COMPARTMENT",**dm})

primary=[x for x in audit if x["selected_rho"]<.25 and x["r_bal"]<=10]
adequate=[x for x in audit if x["selected_rho"]>=.25]
node_cov=valid_nodes/max(1,expected_nodes); exact_frac=exact_nodes/max(1,valid_nodes)
coverage=(sorted({x["route"] for x in audit})==["FLUX","HEAD","RUNOFF"] and len({x["material"] for x in audit})==4 and
          len({x["dt"] for x in audit})==4 and sorted({x["mode"] for x in audit})==["KLAG","TG"] and
          len(audit)>=500 and len(primary)>=100 and node_cov>=.99 and exact_frac>=.9999 and
          sum(not x["process_ok"] for x in cases)==0)

med_p=med([x["cancel_ratio"] for x in primary]); med_a=med([x["cancel_ratio"] for x in adequate])
ratio=(med_p/med_a) if med_p is not None and med_a not in (None,0) else None
opp=sum(x["pair_opposite"] for x in primary)/len(primary) if primary else 0
sf=sum(x["storage_flux_pair"] for x in primary)/len(primary) if primary else 0

families={}; direction_count=0
route_mode_local={}
for route in routes:
  for mode in modes:
    p=[x for x in primary if x["route"]==route and x["mode"]==mode]
    a=[x for x in adequate if x["route"]==route and x["mode"]==mode]
    mp=med([x["cancel_ratio"] for x in p]); ma=med([x["cancel_ratio"] for x in a])
    rat=(mp/ma) if mp is not None and ma not in (None,0) else None
    op=sum(x["pair_opposite"] for x in p)/len(p) if p else 0
    local=bool(p and mp is not None and mp>=1e6 and rat is not None and rat>=10 and op>=.75)
    if rat is not None and rat>1: direction_count+=1
    route_mode_local[(route,mode)]=local
    families[f"{route}|{mode}"]={"n_primary":len(p),"median_primary_cancel_ratio":mp,
      "median_adequate_cancel_ratio":ma,"poor_adequate_ratio":rat,"opposite_pair_fraction":op,
      "storage_flux_pair_fraction":sum(x["storage_flux_pair"] for x in p)/len(p) if p else 0,
      "local_signal":local}

local_signal=bool(coverage and med_p is not None and med_p>=1e6 and ratio is not None and ratio>=10 and direction_count>=4 and opp>=.75)
storage_flux=bool(local_signal and sf>=.60)
route_flags={}
for route in routes:
  route_flags[route]=route_mode_local[(route,"TG")] and route_mode_local[(route,"KLAG")]
route_specific=bool(coverage and not local_signal and any(route_flags.values()) and not all(route_flags.values()))

if not coverage: cls="BLOCKED_NLGLOB04_TERM_DECOMPOSITION_COVERAGE"
elif storage_flux: cls="NLGLOB04_STORAGE_FLUX_CANCELLATION_SIGNAL"
elif local_signal: cls="NLGLOB04_LOCAL_CANCELLATION_SIGNAL"
elif route_specific: cls="NLGLOB04_ROUTE_SPECIFIC_CANCELLATION_SIGNAL"
elif med_p is not None and med_p<1e4: cls="NLGLOB04_NO_STRONG_LOCAL_CANCELLATION_SIGNAL"
else: cls="NLGLOB04_MIXED_LOCAL_PRECISION_STRUCTURE"

pair_counts={}
for x in primary:
    key="-".join(x["pair"]); pair_counts[key]=pair_counts.get(key,0)+1
summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":len(audit),"primary_iterations":len(primary),
         "adequate_iterations":len(adequate),"node_coverage":node_cov,"exact_decomposition_fraction":exact_frac,
         "median_primary_cancel_ratio":med_p,"median_adequate_cancel_ratio":med_a,
         "primary_adequate_cancel_ratio":ratio,"primary_opposite_pair_fraction":opp,
         "primary_storage_flux_pair_fraction":sf,"direction_family_count":direction_count,
         "route_flags":route_flags,"pair_counts":pair_counts,"families":families,
         "total_dominant_primary_fraction":sum(x["balance_dominance"]=="TOTAL" for x in primary)/max(1,len(primary)),
         "compartment_dominant_primary_fraction":sum(x["balance_dominance"]=="COMPARTMENT" for x in primary)/max(1,len(primary)),
         "process_failures":sum(not x["process_ok"] for x in cases)}
print("F_PE_NLGLOB04_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04=PASS")
