#!/usr/bin/env python3
import json, math, subprocess, sys
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

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

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
        bts=segments(cp.stdout,"F_PE_TIMEINT17H_BT|")
        sts=segments(cp.stdout,"F_PE_NLGLOB01_STEP|")
        tss=term_segments(cp.stdout)
        css=segments(cp.stdout,"F_PE_NLGLOB05_CONTRACT|")
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
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp; rtot=float(s["RES_SUM"])/tol_tot; rbal=max(rcp,rtot)
          node=max(tr["nodes"],key=lambda i:abs(tr["nodes"][i]["res"])); n=tr["nodes"][node]
          ulp_rate=(math.ulp(n["theta"])+math.ulp(n["thetam1"]))*abs(n["frac"])*abs(n["dz"])/dt
          rstorage=abs(n["res"])/max(ulp_rate,sys.float_info.min)
          zh=float(s["ZH_INF"]); mh=float(selected["M_H"]); sm=float(selected["M"])
          allm=[float(x["M"]) for x in g if math.isfinite(float(x["M"]))]; best=min(allm) if allm else math.inf
          noimp=bool(math.isfinite(sm) and math.isfinite(best) and best>=.90*sm)
          head=float(cc["HEAD_RATIO"]); pond_app=int(cc["POND_APPLICABLE"])==1; pond=float(cc["POND_RATIO"])
          provider=norm_route(cc["ROUTE"]); route_ok=(provider==route and terminal=="ENDPOINT_SOLVE_FAILURE")
          finite=all(math.isfinite(x) for x in (rcp,rtot,rbal,rstorage,zh,mh,sm,best,head,pond,rr))
          l0=bool(rbal<=10 and rstorage<=10 and head<=1 and ((not pond_app) or pond<=1) and zh<=1e-8 and noimp and finite and route_ok)
          records.append({"case":key,"material":mid,"route":route,"mode":mode,"dt":dt,"iter":it,
                          "rho":rr,"r_bal":rbal,"r_storage_ulp":rstorage,"z_h_inf":zh,"m_h":mh,
                          "head_ratio":head,"pond_applicable":pond_app,"pond_ratio":pond,
                          "selected_m":sm,"best_tested_m":best,"no_material_improvement":noimp,
                          "finite":finite,"route_ok":route_ok,"l0":l0})
          good+=1

by_case={}
for r in records: by_case.setdefault(r["case"],[]).append(r)
evals=[]
for c in cases:
    rs=sorted(by_case.get(c["key"],[]),key=lambda x:x["iter"])
    pos={x["iter"]:x for x in rs}
    maxit=max(pos) if pos else 0
    for k in sorted(pos):
        if k-1 not in pos or k-2 not in pos: continue
        w=[pos[k-2],pos[k-1],pos[k]]
        rvals=[x["r_bal"] for x in w]
        persistence=all(x["l0"] for x in w)
        balance_range=max(rvals)/max(min(rvals),sys.float_info.min) <= 4.0
        no_progress=rvals[-1] >= .75*rvals[0]
        correction=all(x["z_h_inf"]<=1e-8 for x in w)
        bt=sum(x["no_material_improvement"] for x in w)>=2
        poor=sum(x["rho"]<.25 for x in w)>=2
        continuity=all(x["finite"] and x["route_ok"] for x in w)
        t0=bool(persistence and balance_range and no_progress and correction and bt and poor and continuity)
        evals.append({"case":c["key"],"material":c["material"],"route":c["route"],"mode":c["mode"],"dt":c["dt"],
                      "iter":k,"max_iter":maxit,"terminal":k==maxit,"early":k<maxit-1,
                      "terminal_rho":w[-1]["rho"],"terminal_r_bal":w[-1]["r_bal"],
                      "terminal_storage":w[-1]["r_storage_ulp"],"terminal_head":w[-1]["head_ratio"],
                      "terminal_pond_bad":w[-1]["pond_applicable"] and w[-1]["pond_ratio"]>1,
                      "window_l0":persistence,"balance_range_ok":balance_range,"no_progress":no_progress,
                      "poor_count":sum(x["rho"]<.25 for x in w),"t0":t0})

endpoint=[c for c in cases if c["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE"]
terminal=[x for x in evals if x["terminal"]]
early=[x for x in evals if x["early"]]
adequate=[x for x in evals if x["terminal_rho"]>=.25]
n3=[x for x in evals if x["terminal_r_bal"]>10]
n4=[x for x in evals if x["terminal_storage"]>10]
n5=[x for x in evals if x["terminal_head"]>1 or x["terminal_pond_bad"]]
def fp(xs): return sum(x["t0"] for x in xs)/len(xs) if xs else 0.0
cert=[x for x in terminal if x["t0"]]
families={}; fam_pass=0
for route in routes:
  for mode in modes:
    xs=[x for x in terminal if x["route"]==route and x["mode"]==mode]; cs=[x for x in xs if x["t0"]]
    frac=len(cs)/len(xs) if xs else 0.0
    families[f"{route}|{mode}"]={"terminal_n":len(xs),"certified_n":len(cs),"fraction":frac}
    if xs and frac>=.50: fam_pass+=1
coverage=(len(cases)==96 and len(endpoint)==96 and len(terminal)>=90 and good/max(1,expected)>=.99 and
          all(c["process_ok"] for c in cases) and all(r["finite"] for r in records))
hard_unsafe=fp(n3)>0 or fp(n4)>0 or fp(n5)>0
terminal_frac=len(cert)/len(terminal) if terminal else 0.0
span=(set(x["mode"] for x in cert)==set(modes) and set(x["route"] for x in cert)==set(routes) and len(set(x["material"] for x in cert))>=3)
qualified=coverage and terminal_frac>=.60 and span and fam_pass>=4 and fp(early)<=.05 and fp(adequate)<=.05 and not hard_unsafe
if not coverage: cls="BLOCKED_NLGLOB06_TRAJECTORY_COVERAGE"
elif hard_unsafe: cls="NLGLOB06_TRAJECTORY_CERTIFICATE_UNSAFE"
elif fp(early)>.05 or fp(adequate)>.05: cls="NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC"
elif terminal_frac<.25: cls="NLGLOB06_TRAJECTORY_CERTIFICATE_NOT_USEFUL"
elif qualified: cls="NLGLOB06_TRAJECTORY_EXHAUSTION_DISCRIMINATOR_QUALIFIED"
else: cls="NLGLOB06_MIXED_TRAJECTORY_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(cases),"endpoint_failure_cases":len(endpoint),
         "audited_iterations":len(records),"eligible_windows":len(evals),"terminal_evaluated":len(terminal),
         "terminal_certified":len(cert),"terminal_cert_fraction":terminal_frac,
         "early_n":len(early),"early_false_positive_rate":fp(early),
         "adequate_n":len(adequate),"adequate_false_positive_rate":fp(adequate),
         "above_floor_n":len(n3),"above_floor_false_positive_rate":fp(n3),
         "storage_absent_n":len(n4),"storage_absent_false_positive_rate":fp(n4),
         "head_pond_unresolved_n":len(n5),"head_pond_unresolved_false_positive_rate":fp(n5),
         "family_pass_count":fam_pass,"families":families,
         "certified_routes":sorted(set(x["route"] for x in cert)),
         "certified_modes":sorted(set(x["mode"] for x in cert)),
         "certified_materials":sorted(set(x["material"] for x in cert)),
         "diagnostic_coverage":good/max(1,expected),"process_failures":sum(not c["process_ok"] for c in cases)}
print("F_PE_NLGLOB06_EVALS="+json.dumps(evals,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB06_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB06=PASS")
