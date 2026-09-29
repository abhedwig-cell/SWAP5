#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("B01","HEAD","KLAG",0.00025),
 ("B01","HEAD","TG",0.000125),
 ("B01","HEAD","KLAG",0.00003125),
 ("B01","RUNOFF","TG",0.0000625),
 ("B01","RUNOFF","KLAG",0.0000625),
 ("B12","HEAD","KLAG",0.0000625),
 ("O14","FLUX","TG",0.0000625),
 ("O14","RUNOFF","TG",0.0000625),
]
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
def term_segments(stdout):
    out=[];cur={}
    for line in stdout.splitlines():
        if not line.startswith("F_PE_NLGLOB04_TERM|"): continue
        d=fields(line); it=int(d["ITER"]); node=int(d["NODE"]); nn=int(d["NN"])
        if it==1 and node==1 and cur:
            out.append(cur);cur={}
        cur.setdefault(it,{"nn":nn,"nodes":{}})["nodes"][node]=d
    if cur: out.append(cur)
    return out

rows=[];proc=0
for mid,route,mode,dt in cases:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    if not res or res["TERMINAL_REASON"]!="ENDPOINT_SOLVE_FAILURE":
        rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"reproduced":False}); continue
    tss=term_segments(cp.stdout); css=segments(cp.stdout,"F_PE_NLGLOB05_CONTRACT|")
    ts=tss[-1] if tss else {}; cs=css[-1] if css else []
    if not ts or not cs:
        rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"reproduced":False}); continue
    it=max(ts); tr=ts[it]; cc=next((x for x in cs if int(x["ITER"])==it),cs[-1])
    sumr=0.; utot=0.; rlocal=0.
    for i in range(1,tr["nn"]+1):
        d=tr["nodes"][i]
        theta=float(d["THETA"]); tm1=float(d["THETAM1"]); frac=abs(float(d["FRAC"])); dz=abs(float(d["DZ"])); rr=float(d["RES"])
        u=(math.ulp(theta)+math.ulp(tm1))*frac*dz/dt
        sumr+=rr; utot+=abs(u); rlocal=max(rlocal,abs(rr)/max(abs(u),sys.float_info.min))
    rtot=abs(sumr)/max(utot,sys.float_info.min)
    head=float(cc["HEAD_RATIO"]); pond_app=int(cc["POND_APPLICABLE"])==1; pond=float(cc["POND_RATIO"])
    finite=all(math.isfinite(x) for x in (rtot,rlocal,head,pond))
    guards=head<=1 and ((not pond_app) or pond<=1)
    rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"reproduced":True,"r_total_ulp":rtot,
                 "r_local_ulp":rlocal,"head_ratio":head,"pond_applicable":pond_app,"pond_ratio":pond,
                 "finite":finite,"guards_ok":guards})

both=[x for x in rows if x.get("reproduced") and x["finite"] and x["guards_ok"] and x["r_total_ulp"]<=1 and x["r_local_ulp"]<=1]
if proc or sum(x.get("reproduced",False) for x in rows)!=8:
    cls="BLOCKED_NLGLOB12A_COVERAGE"
elif len(both)>=7:
    cls="NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED"
elif len(both)<4:
    cls="NLGLOB12A_AGGREGATE_STORAGE_FLOOR_NOT_SUPPORTED"
else:
    cls="NLGLOB12A_MIXED_AGGREGATE_STORAGE_FLOOR"
summary={"classification":cls,"case_count":len(rows),"reproduced":sum(x.get("reproduced",False) for x in rows),
         "both_representation_bounds":len(both),"process_failures":proc,
         "max_r_total_ulp":max((x.get("r_total_ulp",0) for x in rows),default=0),
         "max_r_local_ulp":max((x.get("r_local_ulp",0) for x in rows),default=0)}
print("F_PE_NLGLOB12A_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A=PASS")
