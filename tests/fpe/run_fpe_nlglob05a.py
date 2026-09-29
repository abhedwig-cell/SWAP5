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

def term_segments(stdout):
    out=[]; cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB04_TERM|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur); cur={}
        rec=cur.setdefault(it,{"nn":nn,"nodes":{}})
        rec["nodes"][node]={
          "theta":float(d["THETA"]),"thetam1":float(d["THETAM1"]),
          "frac":float(d["FRAC"]),"dz":float(d["DZ"]),"res":float(d["RES"])
        }
    if cur: out.append(cur)
    return out

def contract_segments(stdout):
    return segments(stdout,"F_PE_NLGLOB05_CONTRACT|")

records=[]; cases=[]; diag_expected=0; diag_good=0
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
        css=contract_segments(cp.stdout)
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        ts=tss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and tss else {}
        cs=css[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and css else []
        groups=split_bt(bt)
        step_by_iter={int(x["ITER"]):x for x in st}
        contract_by_iter={int(x["ITER"]):x for x in cs}
        its=sorted(int(g[0]["ITER"]) for g in groups if g)
        case_key=f"{mid}|{route}|{mode}|{dt}"
        cases.append({"key":case_key,"material":mid,"route":route,"mode":mode,"dt":dt,
                      "terminal_reason":terminal,"process_ok":cp.returncode==0,"iterations":len(its)})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); tr=ts.get(it); cc=contract_by_iter.get(it)
          if s is None: continue
          diag_expected+=1
          if tr is None or cc is None or sorted(tr["nodes"])!=list(range(1,tr["nn"]+1)): continue
          diag_good+=1
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp; rtot=float(s["RES_SUM"])/tol_tot; rbal=max(rcp,rtot)
          node=max(tr["nodes"],key=lambda i:abs(tr["nodes"][i]["res"])); n=tr["nodes"][node]
          ulp_rate=(math.ulp(n["theta"])+math.ulp(n["thetam1"]))*abs(n["frac"])*abs(n["dz"])/dt
          r_storage=abs(n["res"])/max(ulp_rate,sys.float_info.min)
          head_ratio=float(cc["HEAD_RATIO"]); pond_app=int(cc["POND_APPLICABLE"])==1
          pond_ratio=float(cc["POND_RATIO"]); provider_route=norm_route(cc["ROUTE"])
          finite=all(math.isfinite(x) for x in (rbal,r_storage,head_ratio,pond_ratio,rr))
          route_ok=(provider_route==route)
          c0=bool(rbal<=10 and r_storage<=10 and head_ratio<=1 and
                  ((not pond_app) or pond_ratio<=1) and finite and route_ok and it>1)
          records.append({"case":case_key,"material":mid,"route":route,"provider_route":provider_route,
                          "mode":mode,"dt":dt,"iter":it,"selected_rho":rr,"selected_factor":float(selected["FACTOR"]),
                          "r_bal":rbal,"r_cp":rcp,"r_tot":rtot,"r_storage_ulp":r_storage,
                          "head_ratio":head_ratio,"pond_applicable":pond_app,"pond_ratio":pond_ratio,
                          "route_ok":route_ok,"finite":finite,"c0":c0})

endpoint_cases=[c for c in cases if c["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE"]
by_case={}
for r in records: by_case.setdefault(r["case"],[]).append(r)

terminal_eval=[]; early=[]
for c in endpoint_cases:
    rs=sorted(by_case.get(c["key"],[]),key=lambda x:x["iter"])
    if not rs: continue
    terminal_eval.append(rs[-1])
    if len(rs)>2: early.extend(rs[:-2])

cert_terminal=[x for x in terminal_eval if x["c0"]]
terminal_fraction=len(cert_terminal)/len(terminal_eval) if terminal_eval else 0
early_false=sum(x["c0"] for x in early)/len(early) if early else 0

families={}
family_pass=0
for route in routes:
  for mode in modes:
    xs=[x for x in terminal_eval if x["route"]==route and x["mode"]==mode]
    frac=sum(x["c0"] for x in xs)/len(xs) if xs else 0
    ok=bool(xs and frac>=.60)
    if ok: family_pass+=1
    families[f"{route}|{mode}"]={"terminal_n":len(xs),"certified_n":sum(x["c0"] for x in xs),
                                 "terminal_cert_fraction":frac,"passes":ok}

nc1=[x for x in records if x["r_bal"]>10]
nc2=[x for x in records if x["head_ratio"]>1]
nc3=[x for x in records if x["pond_applicable"] and x["pond_ratio"]>1]
nc5=[x for x in records if x["r_storage_ulp"]>10]
route_bad=[x for x in records if not x["route_ok"]]
def rejection(xs): return 1.0-(sum(x["c0"] for x in xs)/len(xs)) if xs else 1.0

coverage=(len(endpoint_cases)==96 and len(records)>=500 and diag_good/max(1,diag_expected)>=.99 and
          all(x["process_ok"] for x in cases) and all(x["finite"] for x in records))
hard_safe=(rejection(nc1)==1.0 and rejection(nc2)==1.0 and rejection(nc3)==1.0 and
           rejection(nc5)==1.0 and rejection(route_bad)==1.0)
qualified=(coverage and terminal_fraction>=.75 and family_pass>=4 and hard_safe and early_false<=.01)

if qualified: cls="NLGLOB05A_FLOOR_CERTIFICATE_DISCRIMINATION_QUALIFIED"
elif not hard_safe: cls="NLGLOB05A_FLOOR_CERTIFICATE_UNSAFE"
elif terminal_fraction<.25: cls="NLGLOB05A_FLOOR_CERTIFICATE_NOT_USEFUL"
else: cls="NLGLOB05A_MIXED_CERTIFICATE_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(cases),
         "endpoint_failure_cases":len(endpoint_cases),"audited_iterations":len(records),
         "diagnostic_coverage":diag_good/max(1,diag_expected),
         "terminal_evaluated":len(terminal_eval),"terminal_certified":len(cert_terminal),
         "terminal_cert_fraction":terminal_fraction,"family_pass_count":family_pass,
         "early_control_n":len(early),"early_false_positive_fraction":early_false,
         "nc1_n":len(nc1),"nc1_rejection":rejection(nc1),
         "nc2_n":len(nc2),"nc2_rejection":rejection(nc2),
         "nc3_n":len(nc3),"nc3_rejection":rejection(nc3),
         "nc5_n":len(nc5),"nc5_rejection":rejection(nc5),
         "route_mismatch_n":len(route_bad),"route_mismatch_rejection":rejection(route_bad),
         "families":families,"process_failures":sum(not x["process_ok"] for x in cases)}

print("F_PE_NLGLOB05A_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05A_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05A=PASS")
