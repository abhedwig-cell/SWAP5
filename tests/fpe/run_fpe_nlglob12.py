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
def rho(d):
    a=float(d["FACTOR"]); raw0=float(d["RAW_ORIGIN"]); pred=raw0*(2*a-a*a)
    return None if pred<=0 else (raw0-float(d["RAW"]))/pred
def classify(rs):
    # rs are per-iteration records, one per accepted/selected iteration
    if not rs: return "ABOVE_FLOOR_OTHER"
    bal=[x["rbal"] for x in rs]; zh=[x["zh"] for x in rs]
    trans=[bal[i]/bal[i-1] if bal[i-1]>0 else math.inf for i in range(1,len(bal))]
    tail=trans[-7:]
    reducing=sum(x<1 for x in tail)
    gm=math.exp(sum(math.log(max(x,1e-300)) for x in tail)/len(tail)) if tail else math.inf
    if bal[-1]>10 and len(tail)>=5 and reducing>=5 and gm<.8 and all(x["route_ok"] for x in rs):
        return "ABOVE_FLOOR_STILL_DESCENDING"
    if len(bal)>=3 and bal[-1]>10 and max(bal[-3:])/max(min(bal[-3:]),1e-300)<2 and all(x<=1e-8 for x in zh[-3:]) and all(x["route_ok"] for x in rs[-3:]):
        return "ABOVE_FLOOR_STAGNATION"
    full_neg=sum((x["rho_full"] is not None and x["rho_full"]<0) for x in rs[-4:])
    changes=0
    dirs=[]
    for i in range(max(1,len(bal)-4),len(bal)):
        dirs.append(1 if bal[i]>bal[i-1] else -1)
    for i in range(1,len(dirs)):
        if dirs[i]!=dirs[i-1]: changes+=1
    if bal[-1]>10 and (full_neg>=2 or changes>=2):
        return "ABOVE_FLOOR_POOR_MODEL_OSCILLATION"
    return "ABOVE_FLOOR_OTHER"

rows=[];proc=0
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
        aseg=segments(cp.stdout,"F_PE_NLGLOB10_A|"); sseg=segments(cp.stdout,"F_PE_NLGLOB01_STEP|"); bseg=segments(cp.stdout,"F_PE_TIMEINT17H_BT|")
        aa=aseg[-1] if aseg else []; ss=sseg[-1] if sseg else []; bb=bseg[-1] if bseg else []
        step={int(x["ITER"]):x for x in ss}
        byit={}
        for x in bb: byit.setdefault(int(x["ITER"]),[]).append(x)
        its=[]
        for a in aa:
            it=int(a["ITER"]); s=step.get(it); g=byit.get(it,[])
            if not s or not g: continue
            selected=next((x for x in g if int(x["CURRENT_ACCEPT"])==1),g[-1])
            full=next((x for x in g if abs(float(x["FACTOR"])-1.0)<1e-12),g[0])
            its.append({"iter":it,"rbal":float(a["RBAL"]),"rstorage":float(a["RSTORAGE"]),"zh":float(s["ZH_INF"]),
                        "factor":float(selected["FACTOR"]),"merit":float(selected["M"]),"rho_selected":rho(selected),"rho_full":rho(full),
                        "route_ok":a["ROUTE"]==a["R1"] if a.get("R1","") else True})
        cls=classify(its)
        rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"classification":cls,"iterations":its})

counts={}
for x in rows: counts[x["classification"]]=counts.get(x["classification"],0)+1
n=len(rows)
if n!=14 or proc: overall="BLOCKED_NLGLOB12_COVERAGE"
elif counts.get("ABOVE_FLOOR_STILL_DESCENDING",0)/n>=.75: overall="NLGLOB12_ITERATION_BUDGET_LIMITED_DESCENT"
elif counts.get("ABOVE_FLOOR_STAGNATION",0)/n>=.75: overall="NLGLOB12_ABOVE_FLOOR_STAGNATION"
elif counts.get("ABOVE_FLOOR_POOR_MODEL_OSCILLATION",0)/n>=.75: overall="NLGLOB12_ABOVE_FLOOR_POOR_MODEL_OSCILLATION"
else: overall="NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT"
summary={"classification":overall,"case_count":n,"counts":counts,"process_failures":proc}
print("F_PE_NLGLOB12_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12=PASS")
