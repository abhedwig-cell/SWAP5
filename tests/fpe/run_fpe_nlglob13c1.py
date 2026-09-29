#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
targets=[
 ("O05","TG","HEAD",0.00025),
 ("O05","TG","HEAD",0.000125),
 ("O05","TG","HEAD",0.0000625),
 ("O05","TG","HEAD",0.00003125),
 ("O05","TG","RUNOFF",0.00025),
 ("O05","TG","RUNOFF",0.000125),
 ("O05","TG","RUNOFF",0.00003125),
]
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="HEAD":
        h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
    elif r=="RUNOFF":
        h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
    else:
        raise ValueError(r)
    return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

rows=[];proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    logs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13C1_STATE|")]
    qfails=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13B_QFAIL|")]
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,
         "log_rows":len(logs),"qfail_count":len(qfails)}
    if qfails:
        qf=qfails[-1]
        fstep=int(qf["STEP"]); fhalf=int(qf["HALF"]); fquarter=int(qf["QUARTER"])
        g=[d for d in logs if int(d["STEP"])==fstep and int(d["HALF"])==fhalf and int(d["QUARTER"])==fquarter]
        rec.update({"step":fstep,"half":fhalf,"quarter":fquarter,"group_rows":len(g)})
        if len(g)==16:
            g=sorted(g,key=lambda x:int(x["NODE"]))
            dtheta_abs=0.; dtheta_ulp=0.; dh_abs=0.; dh_ulp=0.; storage=0.; pond=0.; finite=True; route_ok=True
            for d in g:
                pt=float(d["PTHETA"]); ct=float(d["CTHETA"]); ph=float(d["PH"]); ch=float(d["CH"]); dz=abs(float(d["DZ"]))
                pp=float(d["PPOND"]); cpnd=float(d["CPOND"])
                vals=(pt,ct,ph,ch,pp,cpnd,dz)
                finite=finite and all(math.isfinite(x) for x in vals)
                route_ok=route_ok and d["ROUTE"]==route
                dtabs=abs(pt-ct); dh=abs(ph-ch)
                dtheta_abs=max(dtheta_abs,dtabs); dh_abs=max(dh_abs,dh)
                dtheta_ulp=max(dtheta_ulp,dtabs/max(math.ulp(pt)+math.ulp(ct),sys.float_info.min))
                dh_ulp=max(dh_ulp,dh/max(math.ulp(ph)+math.ulp(ch),sys.float_info.min))
                storage+=dz*dtabs
                pond=max(pond,abs(pp-cpnd))
            identical=bool(finite and route_ok and dtheta_abs<=1e-14 and storage<=1e-12 and dh_abs<=1e-10 and pond<=1e-12)
            rec.update({"dtheta_abs":dtheta_abs,"dtheta_ulp":dtheta_ulp,
                        "dh_abs":dh_abs,"dh_ulp":dh_ulp,"storage_abs":storage,"pond_abs":pond,
                        "finite":finite,"route_ok":route_ok,"nodewise_identical":identical})
    rows.append(rec)

covered=[x for x in rows if x.get("group_rows",0)==16 and "nodewise_identical" in x]
identical=sum(x.get("nodewise_identical",False) for x in covered)
defect=any((x.get("storage_abs",0)>5e-8 or x.get("dh_abs",0)>1e-6 or not x.get("route_ok",True) or not x.get("finite",True)) for x in covered)
if len(covered)!=7 or proc:
    cls="BLOCKED_NLGLOB13C1_IDENTITY_COVERAGE"
elif defect:
    cls="NLGLOB13C1_PRESTATE_RESTORATION_DEFECT"
elif identical==7:
    cls="NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED"
else:
    cls="NLGLOB13C1_PRESTATE_IDENTITY_MIXED"

summary={"classification":cls,"target_count":len(rows),"covered_pairs":len(covered),"identical_pairs":identical,
         "max_dtheta_abs":max((x.get("dtheta_abs",0) for x in covered),default=math.nan),
         "max_dtheta_ulp":max((x.get("dtheta_ulp",0) for x in covered),default=math.nan),
         "max_dh_abs":max((x.get("dh_abs",0) for x in covered),default=math.nan),
         "max_dh_ulp":max((x.get("dh_ulp",0) for x in covered),default=math.nan),
         "max_storage_abs":max((x.get("storage_abs",0) for x in covered),default=math.nan),
         "max_pond_abs":max((x.get("pond_abs",0) for x in covered),default=math.nan),
         "process_failures":proc}
print("F_PE_NLGLOB13C1_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C1=PASS")
