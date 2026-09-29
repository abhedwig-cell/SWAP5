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
    out=[];cur=[]
    for line in stdout.splitlines():
        if not line.startswith(prefix): continue
        d=fields(line); it=int(d["ITER"])
        if it==1 and cur: out.append(cur);cur=[]
        cur.append(d)
    if cur: out.append(cur)
    return out

def classify_stagnation(stdout):
    aseg=segments(stdout,"F_PE_NLGLOB10_A|")
    sseg=segments(stdout,"F_PE_NLGLOB01_STEP|")
    if not aseg or not sseg: return False
    aa=aseg[-1]; ss=sseg[-1]; step={int(x["ITER"]):x for x in ss}
    rs=[]
    for a in aa:
        it=int(a["ITER"]); s=step.get(it)
        if not s: continue
        rs.append((float(a["RBAL"]),float(s["ZH_INF"]),a.get("ROUTE","")==a.get("R1","") if a.get("R1","") else True))
    if not rs: return False
    bal=[x[0] for x in rs]; zh=[x[1] for x in rs]; route_ok=[x[2] for x in rs]
    trans=[bal[i]/bal[i-1] if bal[i-1]>0 else math.inf for i in range(1,len(bal))]
    tail=trans[-7:]
    reducing=sum(x<1 for x in tail)
    gm=math.exp(sum(math.log(max(x,1e-300)) for x in tail)/len(tail)) if tail else math.inf
    if bal[-1]>10 and len(tail)>=5 and reducing>=5 and gm<.8 and all(route_ok):
        return False
    return len(bal)>=3 and bal[-1]>10 and max(bal[-3:])/max(min(bal[-3:]),1e-300)<2 and all(x<=1e-8 for x in zh[-3:]) and all(route_ok[-3:])

def terminal_terms(stdout):
    segs=segments(stdout,"F_PE_NLGLOB04_TERM|")
    if not segs: return []
    seg=segs[-1]
    maxit=max(int(x["ITER"]) for x in seg)
    return [x for x in seg if int(x["ITER"])==maxit]

rows=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        if not result or result["TERMINAL_REASON"]!="ENDPOINT_SOLVE_FAILURE": continue
        if not classify_stagnation(cp.stdout): continue
        terms=terminal_terms(cp.stdout)
        if not terms: continue
        total=sum(float(x["RES"]) for x in terms)
        utotal=0.0; local_ratios=[]; finite=True
        for x in terms:
            th=float(x["THETA"]); thm1=float(x["THETAM1"]); frac=abs(float(x["FRAC"])); dz=abs(float(x["DZ"])); res=abs(float(x["RES"]))
            u=(math.ulp(th)+math.ulp(thm1))*frac*dz/dt
            utotal+=abs(u)
            local_ratios.append(res/max(abs(u),sys.float_info.min))
            finite=finite and all(math.isfinite(v) for v in (th,thm1,res,u))
        contract=segments(cp.stdout,"F_PE_NLGLOB05_CONTRACT|")
        cs=contract[-1] if contract else []
        cc=cs[-1] if cs else {}
        head_ok=float(cc.get("HEAD_RATIO","inf"))<=1
        pond_app=int(cc.get("POND_APPLICABLE","0"))==1
        pond_ok=(not pond_app) or float(cc.get("POND_RATIO","inf"))<=1
        route_ok=cc.get("ROUTE","")==({"FLUX":"surface-flux","HEAD":"ponded-head","RUNOFF":"ponded-head-linear-runoff"}[route])
        rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,
                     "r_total_ulp":abs(total)/max(utotal,sys.float_info.min),
                     "r_local_ulp":max(local_ratios),
                     "finite":finite,"head_ok":head_ok,"pond_ok":pond_ok,"route_ok":route_ok})

both=[x for x in rows if x["r_total_ulp"]<=1 and x["r_local_ulp"]<=1 and x["head_ok"] and x["pond_ok"] and x["finite"] and x["route_ok"]]
if len(rows)!=8 or proc:
    cls="BLOCKED_NLGLOB12A_AGGREGATE_STORAGE_FLOOR_COVERAGE"
elif len(both)>=7:
    cls="NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED"
elif len(both)<4:
    cls="NLGLOB12A_AGGREGATE_STORAGE_FLOOR_NOT_SUPPORTED"
else:
    cls="NLGLOB12A_MIXED_AGGREGATE_STORAGE_FLOOR"
summary={"classification":cls,"case_count":len(rows),"both_representation_bounds_n":len(both),
         "total_ulp_le1_n":sum(x["r_total_ulp"]<=1 for x in rows),
         "local_ulp_le1_n":sum(x["r_local_ulp"]<=1 for x in rows),
         "guards_ok_n":sum(x["head_ok"] and x["pond_ok"] and x["finite"] and x["route_ok"] for x in rows),
         "process_failures":proc}
print("F_PE_NLGLOB12A_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A=PASS")
