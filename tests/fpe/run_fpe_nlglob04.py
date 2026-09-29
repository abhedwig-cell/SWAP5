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

def term_segments(stdout):
    out=[]; cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB04_TERM|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur); cur={}
        rec=cur.setdefault(it,{"nn":nn,"nodes":{}})
        rec["nodes"][node]={
            "storage":float(d["STORAGE"]),"upper":float(d["UPPER"]),"lower":float(d["LOWER"]),
            "bc":float(d["BC"]),"ss":float(d["SS"]),"theta":float(d["THETA"]),
            "thetam1":float(d["THETAM1"]),"frac":float(d["FRAC"]),"dz":float(d["DZ"]),
            "res":float(d["RES"]),"swbotb":int(d["SWBOTB"])
        }
    if cur: out.append(cur)
    return out

audit=[]; cases=[]; term_expected=0; term_good=0; recon_good=0
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
        bts=segments(cp.stdout,"F_PE_TIMEINT17H_BT|"); sts=segments(cp.stdout,"F_PE_NLGLOB01_STEP|"); tss=term_segments(cp.stdout)
        bt=bts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and bts else []
        st=sts[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and sts else []
        ts=tss[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and tss else {}
        groups=split_bt(bt); step_by_iter={int(x["ITER"]):x for x in st}
        cases.append({"material":mid,"route":route,"mode":mode,"dt":dt,"terminal_reason":terminal,
                      "process_ok":cp.returncode==0,"iterations":len(groups)})
        for g in groups:
          if not g: continue
          it=int(g[0]["ITER"]); s=step_by_iter.get(it); rec=ts.get(it)
          if s is None: continue
          term_expected+=1
          if rec is None or sorted(rec["nodes"])!=list(range(1,rec["nn"]+1)): continue
          if any(v["swbotb"]!=2 for v in rec["nodes"].values()): continue
          term_good+=1
          selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
          rr=rho(selected)
          if rr is None or not math.isfinite(rr): continue
          tol_cp=float(s["TOL_CP"]); tol_tot=float(s["TOL_TOT"])
          rcp=float(s["RES_INF"])/tol_cp; rtot=float(s["RES_SUM"])/tol_tot; rbal=max(rcp,rtot)
          node=max(rec["nodes"],key=lambda i:abs(rec["nodes"][i]["res"])); n=rec["nodes"][node]
          terms=[n["storage"],n["upper"],n["lower"],n["bc"],n["ss"]]
          naive=sum(terms); fs=math.fsum(terms); res=n["res"]
          err=min(abs(naive-res),abs(fs-res)); recon_tol=max(1e-13,1e-12*abs(res))
          if err<=recon_tol: recon_good+=1
          naive_ratio=abs(naive)/tol_cp; fsum_ratio=abs(fs)/tol_cp
          move=abs(naive-fs)/max(abs(naive),tol_cp)
          cross=(naive_ratio>1 and fsum_ratio<=1)
          ulp_rate=(math.ulp(n["theta"])+math.ulp(n["thetam1"]))*abs(n["frac"])*abs(n["dz"])/dt
          r_ulp=abs(res)/max(ulp_rate,sys.float_info.min)
          term_abs=math.fsum(abs(x) for x in terms)
          audit.append({"material":mid,"route":route,"provider_route":norm_route(s["ROUTE"]),"mode":mode,"dt":dt,"iter":it,
                        "selected_rho":rr,"r_bal":rbal,"r_cp":rcp,"r_tot":rtot,"node":node,
                        "res":res,"storage":n["storage"],"upper":n["upper"],"lower":n["lower"],"bc":n["bc"],"ss":n["ss"],
                        "naive_ratio":naive_ratio,"fsum_ratio":fsum_ratio,"local_move":move,"cross_to_floor":cross,
                        "storage_ulp_rate":ulp_rate,"r_storage_ulp":r_ulp,
                        "storage_abs":abs(n["storage"]),"flux_abs_sum":abs(n["upper"])+abs(n["lower"])+abs(n["bc"]),
                        "kappa_local":term_abs/max(abs(res),tol_cp),"reconstruction_error":err})

finite=sum(all(math.isfinite(x[k]) for k in ("r_bal","r_cp","r_tot","local_move","r_storage_ulp","kappa_local")) for x in audit)
primary=[x for x in audit if x["selected_rho"]<.25 and x["r_bal"]<=10]
adequate=[x for x in audit if x["selected_rho"]>=.25]
term_cov=term_good/max(1,term_expected); recon_cov=recon_good/max(1,term_good)
coverage=(sorted({x["provider_route"] for x in audit})==["FLUX","HEAD","RUNOFF"] and
          len({x["material"] for x in audit})==4 and len({x["dt"] for x in audit})==4 and
          sorted({x["mode"] for x in audit})==["KLAG","TG"] and len(audit)>=500 and len(primary)>=100 and
          finite/max(1,len(audit))>=.99 and term_cov>=.99 and recon_cov>=.99)

move25=sum(x["local_move"]>=.25 for x in primary)/len(primary) if primary else 0
move10=sum(x["local_move"]>=.10 for x in primary)/len(primary) if primary else 0
crossfrac=sum(x["cross_to_floor"] for x in primary)/len(primary) if primary else 0
p_storage=sum(x["r_storage_ulp"]<=10 for x in primary)/len(primary) if primary else 0
a_storage=sum(x["r_storage_ulp"]<=10 for x in adequate)/len(adequate) if adequate else 0

family_sum_dir=0; family_storage_dir=0; families={}
for route in routes:
  for mode in modes:
    ps=[x for x in primary if x["provider_route"]==route and x["mode"]==mode]
    ads=[x for x in adequate if x["provider_route"]==route and x["mode"]==mode]
    mna=med([x["naive_ratio"] for x in ps]); mfs=med([x["fsum_ratio"] for x in ps])
    cf=sum(x["cross_to_floor"] for x in ps)/len(ps) if ps else 0
    sumdir=bool(ps and mna is not None and mfs is not None and mfs<mna and cf>=.10)
    pf=sum(x["r_storage_ulp"]<=10 for x in ps)/len(ps) if ps else 0
    af=sum(x["r_storage_ulp"]<=10 for x in ads)/len(ads) if ads else 0
    sep=(pf>0 if af==0 else pf>=1.5*af)
    storagedir=bool(ps and pf>=.5 and sep)
    if sumdir: family_sum_dir+=1
    if storagedir: family_storage_dir+=1
    families[f"{route}|{mode}"]={"primary_n":len(ps),"adequate_n":len(ads),
      "median_naive_local_ratio":mna,"median_fsum_local_ratio":mfs,"cross_fraction":cf,
      "summation_direction":sumdir,"primary_storage_near_fraction":pf,
      "adequate_storage_near_fraction":af,"storage_direction":storagedir}

local_signal=(coverage and move25>=.25 and crossfrac>=.10 and family_sum_dir>=4)
storage_sep=(p_storage>0 if a_storage==0 else a_storage<=.5*p_storage)
storage_signal=(coverage and not local_signal and p_storage>=.5 and storage_sep and
                med([x["r_storage_ulp"] for x in primary]) is not None and
                med([x["r_storage_ulp"] for x in primary])<=10 and family_storage_dir>=4)
mixed=(coverage and not local_signal and not storage_signal and (move10>=.10 or p_storage>=.25))

if not coverage: cls="BLOCKED_NLGLOB04_TERM_DECOMPOSITION_COVERAGE"
elif local_signal: cls="NLGLOB04_LOCAL_TERM_SUMMATION_SIGNAL"
elif storage_signal: cls="NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL"
elif mixed: cls="NLGLOB04_MIXED_TERM_FLOOR_SIGNAL"
else: cls="NLGLOB04_NO_LOCAL_ARITHMETIC_FLOOR_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":len(audit),
 "primary_iterations":len(primary),"adequate_iterations":len(adequate),
 "term_coverage":term_cov,"reconstruction_coverage":recon_cov,"finite_fraction":finite/max(1,len(audit)),
 "local_move_ge_25_fraction":move25,"local_move_ge_10_fraction":move10,"local_cross_fraction":crossfrac,
 "summation_family_direction_count":family_sum_dir,
 "primary_storage_near_fraction":p_storage,"adequate_storage_near_fraction":a_storage,
 "median_primary_r_storage_ulp":med([x["r_storage_ulp"] for x in primary]),
 "storage_family_direction_count":family_storage_dir,
 "median_primary_kappa_local":med([x["kappa_local"] for x in primary]),
 "families":families,"process_failures":sum(not x["process_ok"] for x in cases)}

print("F_PE_NLGLOB04_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB04=PASS")
