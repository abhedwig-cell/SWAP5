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
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        ts=tss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and tss else {}
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}
        cases.append({"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,
                      "process_ok":cp.returncode==0})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); tr=ts.get(it)
          expected+=1
          if s is None or tr is None or sorted(tr["nodes"])!=list(range(1,tr["nn"]+1)): continue
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          good+=1
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp; rtot=float(s["RES_SUM"])/tol_tot
          node=max(tr["nodes"],key=lambda i:abs(tr["nodes"][i]["res"])); n=tr["nodes"][node]
          ulp_rate=(math.ulp(n["theta"])+math.ulp(n["thetam1"]))*abs(n["frac"])*abs(n["dz"])/dt
          r_storage=abs(n["res"])/max(ulp_rate,sys.float_info.min)
          zh=float(s["ZH_INF"])
          selected_m=float(selected["M"]); mh=float(selected["M_H"])
          all_m=[float(x["M"]) for x in g if math.isfinite(float(x["M"]))]
          best_m=min(all_m) if all_m else math.inf
          no_material_improvement=bool(math.isfinite(selected_m) and math.isfinite(best_m) and best_m>=0.90*selected_m)
          provider_route=norm_route(selected["ROUTE"])
          finite=all(math.isfinite(x) for x in (rcp,rtot,r_storage,zh,selected_m,best_m,mh,rr))
          route_ok=(provider_route==route and terminal=="ENDPOINT_SOLVE_FAILURE")
          c0=bool(rcp<=10 and rtot<=10 and r_storage<=10 and zh<=1e-8 and mh<=1 and
                  no_material_improvement and finite and route_ok)
          primary=bool(rr<.25 and max(rcp,rtot)<=10)
          records.append({"material":mid,"route":route,"provider_route":provider_route,"mode":mode,"dt":dt,"iter":it,
                          "selected_rho":rr,"r_cp":rcp,"r_tot":rtot,"r_storage_ulp":r_storage,
                          "z_h_inf":zh,"m_h":mh,"selected_m":selected_m,"best_tested_m":best_m,
                          "no_material_improvement":no_material_improvement,"finite":finite,"route_ok":route_ok,
                          "primary":primary,"c0":c0})

primary=[x for x in records if x["primary"]]
n1=[x for x in records if x["selected_rho"]>=.25]
n2=[x for x in records if x["r_cp"]>10 or x["r_tot"]>10]
n3=[x for x in records if x["r_storage_ulp"]>10]
n4=[x for x in records if x["m_h"]>1]
n5=[x for x in records if not x["route_ok"] or not x["finite"]]
cert=[x for x in primary if x["c0"]]

def fp(xs): return sum(x["c0"] for x in xs)/len(xs) if xs else 0.0

families={}
cert_modes={"TG":0,"KLAG":0}; cert_routes=set(); cert_mats=set()
for x in cert:
    cert_modes[x["mode"]]+=1; cert_routes.add(x["route"]); cert_mats.add(x["material"])
for route in routes:
  for mode in modes:
    ps=[x for x in primary if x["route"]==route and x["mode"]==mode]
    cs=[x for x in ps if x["c0"]]
    families[f"{route}|{mode}"]={"primary_n":len(ps),"certified_n":len(cs),
                                 "cert_fraction":len(cs)/len(ps) if ps else 0.0}

coverage=(len(cases)==96 and len(records)>=500 and len(primary)>=100 and good/max(1,expected)>=.99 and
          all(x["process_ok"] for x in cases) and all(x["finite"] for x in records))
hard_unsafe=(fp(n2)>0 or fp(n3)>0 or fp(n4)>0 or fp(n5)>0)
qualified=(coverage and len(cert)/len(primary)>=.50 and cert_modes["TG"]>=25 and cert_modes["KLAG"]>=25 and
           len(cert_routes)==3 and len(cert_mats)>=3 and fp(n1)<=.05 and not hard_unsafe)

if not coverage: cls="BLOCKED_NLGLOB05_CERTIFICATE_COVERAGE"
elif hard_unsafe: cls="NLGLOB05_CERTIFICATE_UNSAFE"
elif fp(n1)>.05: cls="NLGLOB05_CERTIFICATE_NONSPECIFIC"
elif len(cert)/len(primary)<.50: cls="NLGLOB05_CERTIFICATE_TOO_NARROW"
elif qualified: cls="NLGLOB05_FLOOR_CERTIFICATE_DISCRIMINATOR_QUALIFIED"
else: cls="NLGLOB05_CERTIFICATE_TOO_NARROW"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(cases),"audited_iterations":len(records),
 "primary_n":len(primary),"certified_primary_n":len(cert),"certified_primary_fraction":len(cert)/len(primary) if primary else 0,
 "certified_tg":cert_modes["TG"],"certified_klag":cert_modes["KLAG"],
 "certified_routes":sorted(cert_routes),"certified_materials":sorted(cert_mats),
 "n1_n":len(n1),"n1_false_positive_rate":fp(n1),
 "n2_n":len(n2),"n2_false_positive_rate":fp(n2),
 "n3_n":len(n3),"n3_false_positive_rate":fp(n3),
 "n4_n":len(n4),"n4_false_positive_rate":fp(n4),
 "n5_n":len(n5),"n5_false_positive_rate":fp(n5),
 "diagnostic_coverage":good/max(1,expected),"families":families,
 "process_failures":sum(not x["process_ok"] for x in cases)}

print("F_PE_NLGLOB05_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB05=PASS")
