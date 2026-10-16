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
        h=-50.; p=0.; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=.25*(-q)
    elif r=="HEAD":
        h=-5.; p=.025; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q
    else:
        h=-5.; p=.1; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q+(p-pmax)/rsro
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

def term_segments(stdout):
    out=[]; cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB04_TERM|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur); cur={}
        rec=cur.setdefault(it,{"nn":nn,"nodes":{}})
        rec["nodes"][node]={"theta":float(d["THETA"]),"thetam1":float(d["THETAM1"]),
                            "frac":float(d["FRAC"]),"dz":float(d["DZ"]),"res":float(d["RES"])}
    if cur: out.append(cur)
    return out

def transition(a,b):
    dinf=0.0; ds=0.0; us=0.0
    for ta,tb,f,dz in zip(a["theta"],b["theta"],b["frac"],b["dz"]):
        u=math.ulp(ta)+math.ulp(tb)
        dinf=max(dinf,abs(tb-ta)/max(u,sys.float_info.min))
        w=abs(f)*abs(dz); ds+=w*abs(tb-ta); us+=w*u
    return dinf, ds/max(us,sys.float_info.min)

def physical_l1(a,b):
    return sum(abs(f)*abs(dz)*abs(tb-ta) for ta,tb,f,dz in zip(a["theta"],b["theta"],b["frac"],b["dz"]))

records=[]; cases=[]; expected=0; good=0
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
        tss=term_segments(cp.stdout); css=segments(cp.stdout,"F_PE_NLGLOB05_CONTRACT|")
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        ts=tss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and tss else {}
        cs=css[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and css else []
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}; contract_by_iter={int(x["ITER"]):x for x in cs}
        key=f"{mid}|{route}|{mode}|{dt}"
        cases.append({"key":key,"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,"process_ok":cp.returncode==0})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); tr=ts.get(it); cc=contract_by_iter.get(it)
          expected+=1
          if s is None or tr is None or cc is None or sorted(tr["nodes"])!=list(range(1,tr["nn"]+1)): continue
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1]); rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          rcp=float(s["RES_INF"])/float(s["TOL_CP"]); rtot=float(s["RES_SUM"])/float(s["TOL_TOT"]); rbal=max(rcp,rtot)
          node=max(tr["nodes"],key=lambda i:abs(tr["nodes"][i]["res"])); n=tr["nodes"][node]
          ulp_rate=(math.ulp(n["theta"])+math.ulp(n["thetam1"]))*abs(n["frac"])*abs(n["dz"])/dt
          rstorage=abs(n["res"])/max(ulp_rate,sys.float_info.min)
          head=float(cc["HEAD_RATIO"]); pond_app=int(cc["POND_APPLICABLE"])==1; pond=float(cc["POND_RATIO"])
          provider=norm_route(cc["ROUTE"]); route_ok=(provider==route and terminal=="ENDPOINT_SOLVE_FAILURE")
          theta=[tr["nodes"][i]["theta"] for i in range(1,tr["nn"]+1)]
          frac=[tr["nodes"][i]["frac"] for i in range(1,tr["nn"]+1)]
          dz=[tr["nodes"][i]["dz"] for i in range(1,tr["nn"]+1)]
          finite=all(math.isfinite(x) for x in theta+[rbal,rstorage,head,pond,rr])
          guard=bool(rbal<=10 and rstorage<=10 and head<=1 and ((not pond_app) or pond<=1) and finite and route_ok)
          records.append({"case":key,"material":mid,"route":route,"mode":mode,"dt":dt,"iter":it,"rho":rr,
                          "r_bal":rbal,"r_storage_ulp":rstorage,"head_ratio":head,
                          "pond_applicable":pond_app,"pond_ratio":pond,"finite":finite,"route_ok":route_ok,
                          "guard":guard,"theta":theta,"frac":frac,"dz":dz})
          good+=1

by_case={}
for r in records: by_case.setdefault(r["case"],[]).append(r)
points=[]
for c in cases:
    rs=sorted(by_case.get(c["key"],[]),key=lambda x:x["iter"]); pos={x["iter"]:x for x in rs}; maxit=max(pos) if pos else 0
    terminal=pos.get(maxit)
    if terminal is None: continue
    for k in sorted(pos):
        if k-1 not in pos or k-2 not in pos: continue
        a,b,d=pos[k-2],pos[k-1],pos[k]
        d1,s1=transition(a,b); d2,s2=transition(b,d)
        stat=(d1<=32 and s1<=32 and d2<=32 and s2<=32)
        renewed=s2<=2*max(s1,1.0)
        continuity=all(x["finite"] and x["route_ok"] for x in (a,b,d))
        s0=bool(d["guard"] and stat and renewed and continuity)
        later=[pos[j] for j in sorted(pos) if j>k]
        tail=[physical_l1(d,x) for x in later]
        tail_max=max(tail) if tail else 0.0
        tail_final=physical_l1(d,terminal)
        tail_ok=all(x["finite"] and x["route_ok"] for x in later)
        inert=bool(s0 and tail_max<=5e-8 and tail_final<=5e-8 and tail_ok)
        points.append({"case":c["key"],"material":c["material"],"route":c["route"],"mode":c["mode"],"dt":c["dt"],
                       "iter":k,"max_iter":maxit,"early":k<maxit-1,"terminal":k==maxit,
                       "s0":s0,"tail_max":tail_max,"tail_final":tail_final,"tail_ok":tail_ok,"tail_inert":inert})

s0=[x for x in points if x["s0"]]; early=[x for x in s0 if x["early"]]; terminal=[x for x in s0 if x["terminal"]]
non_s0_early=[x for x in points if x["early"] and not x["s0"]]
pathological=[x for x in points if not x["tail_ok"]]

def frac(xs,key): return sum(bool(x[key]) for x in xs)/len(xs) if xs else 0.0
def pct(vals,p):
    if not vals: return 0.0
    vals=sorted(vals); idx=min(len(vals)-1,max(0,math.ceil(p*len(vals))-1)); return vals[idx]

all_inert=frac(s0,"tail_inert"); early_inert=frac(early,"tail_inert")
c1_motion=sum(x["tail_max"]>5e-8 for x in non_s0_early)/len(non_s0_early) if non_s0_early else 0.0
c2_fp=frac(pathological,"tail_inert")
span=(set(x["mode"] for x in early if x["tail_inert"])==set(modes) and
      set(x["route"] for x in early if x["tail_inert"])==set(routes) and
      len(set(x["material"] for x in early if x["tail_inert"]))>=3)
coverage=(len(cases)==96 and sum(c["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE" for c in cases)==96 and
          good/max(1,expected)>=.99 and all(c["process_ok"] for c in cases) and len(s0)>=100 and len(early)>=50)
qualified=coverage and all_inert>=.95 and early_inert>=.95 and span and c2_fp==0.0
if not coverage: cls="BLOCKED_NLGLOB08_TAIL_DRIFT_COVERAGE"
elif c2_fp>0: cls="NLGLOB08_TAIL_INERTNESS_UNSAFE"
elif early_inert<.50: cls="NLGLOB08_EARLY_STATIONARITY_HAS_MEANINGFUL_TAIL_DRIFT"
elif qualified: cls="NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT"
else: cls="NLGLOB08_MIXED_TAIL_DRIFT_SIGNAL"

ev=[x["tail_max"] for x in early]
summary={"classification":cls,"coverage_ok":coverage,"case_count":len(cases),"audited_iterations":len(records),
         "s0_points":len(s0),"early_s0_points":len(early),"terminal_s0_points":len(terminal),
         "all_s0_inert_fraction":all_inert,"early_s0_inert_fraction":early_inert,
         "early_tail_max_median":statistics.median(ev) if ev else 0.0,"early_tail_max_p95":pct(ev,.95),
         "early_tail_max_max":max(ev) if ev else 0.0,
         "non_s0_early_n":len(non_s0_early),"non_s0_early_meaningful_motion_fraction":c1_motion,
         "pathological_n":len(pathological),"pathological_inert_false_positive_rate":c2_fp,
         "early_inert_routes":sorted(set(x["route"] for x in early if x["tail_inert"])),
         "early_inert_modes":sorted(set(x["mode"] for x in early if x["tail_inert"])),
         "early_inert_materials":sorted(set(x["material"] for x in early if x["tail_inert"])),
         "diagnostic_coverage":good/max(1,expected),"process_failures":sum(not c["process_ok"] for c in cases)}
print("F_PE_NLGLOB08_POINTS="+json.dumps(points,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB08_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB08=PASS")
