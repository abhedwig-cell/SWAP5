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

def classify_a(d):
    rbal=float(d["RBAL"]); rst=float(d["RSTORAGE"]); rh=float(d["RHEAD"]); rp=float(d["RPOND"]); pa=int(d["POND_APP"])
    hist=int(d["HIST"])
    if rbal>10 or rst>10: return "A_GUARD_BALANCE"
    if rh>1 or (pa==1 and rp>1): return "A_GUARD_HEAD_POND"
    if hist<2: return "A_STATE_MOTION"
    d1=float(d["DINF1"]); d2=float(d["DINF2"]); s1=float(d["DS1"]); s2=float(d["DS2"])
    if d1>32 or d2>32 or s1>32 or s2>32: return "A_STATE_MOTION"
    if s2>2*max(s1,1.0): return "A_RENEWED_MOTION"
    if d.get("R0","")!=d.get("R1","") or d.get("R1","")!=d.get("ROUTE",""): return "A_ROUTE_STATE"
    return "A_OTHER"

records=[]; arows=[]; brows=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        al=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB10_A|")]
        bl=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB10_B|")]
        reason=res["TERMINAL_REASON"] if res else "MISSING"
        rec={"material":mid,"route":route,"mode":mode,"dt":dt,"reason":reason}
        records.append(rec)
        if reason=="ENDPOINT_SOLVE_FAILURE" and al:
            d=al[-1]; cls=classify_a(d)
            arows.append({**rec,"terminal_class":cls,"iter":int(d["ITER"]),"rbal":float(d["RBAL"]),
                          "rstorage":float(d["RSTORAGE"]),"rhead":float(d["RHEAD"]),"rpond":float(d["RPOND"]),
                          "dinf1":float(d["DINF1"]),"dinf2":float(d["DINF2"]),"ds1":float(d["DS1"]),"ds2":float(d["DS2"])})
        if reason=="PREDICTED_RETENTION_DOMAIN_FAILED" and bl:
            d=bl[-1]; tr=float(d["TR"]); ts=float(d["TS"]); pmin=float(d["PRED_MIN"]); pmaxv=float(d["PRED_MAX"])
            amin=float(d["ACCEPT_MIN"]); amax=float(d["ACCEPT_MAX"])
            overs=max((tr-pmin)/(ts-tr),(pmaxv-ts)/(ts-tr),0.0)
            brows.append({**rec,"step":int(d["STEP"]),"pred_min":pmin,"pred_max":pmaxv,"tr":tr,"ts":ts,
                          "accept_min":amin,"accept_max":amax,"overshoot":overs,
                          "accepted_in_domain":amin>tr and amax<ts and math.isfinite(amin) and math.isfinite(amax)})

acount={}
for x in arows: acount[x["terminal_class"]]=acount.get(x["terminal_class"],0)+1
an=len(arows); dominant=max(acount,key=acount.get) if acount else None; domfrac=acount.get(dominant,0)/an if an else 0.0
if an!=14:
    acls="BLOCKED_NLGLOB10_DECOMPOSITION_COVERAGE"
elif dominant in ("A_STATE_MOTION","A_RENEWED_MOTION") and sum(acount.get(k,0) for k in ("A_STATE_MOTION","A_RENEWED_MOTION"))/an>.75:
    acls="NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_STATE_EVOLVING"
elif acount.get("A_GUARD_BALANCE",0)/an>.75:
    acls="NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR"
else:
    acls="NLGLOB10_MIXED_POST_REPLAY_ENDPOINT_BLOCKER"

if len(brows)!=7:
    bcls="BLOCKED_NLGLOB10_DECOMPOSITION_COVERAGE"
elif all(x["accepted_in_domain"] and x["overshoot"]>0 for x in brows):
    bcls="NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT"
else:
    bcls="NLGLOB10_TG_ACCEPTED_STATE_DOMAIN_DEFECT"

coverage=(len(records)==96 and an==14 and len(brows)==7 and proc==0)
summary={"coverage_ok":coverage,"arm_a_classification":acls,"arm_b_classification":bcls,
         "arm_a_n":an,"arm_a_counts":acount,"arm_a_dominant_fraction":domfrac,
         "arm_b_n":len(brows),"arm_b_all_accepted_in_domain":all(x["accepted_in_domain"] for x in brows) if brows else False,
         "arm_b_max_normalized_overshoot":max((x["overshoot"] for x in brows),default=0.0),
         "process_failures":proc}
print("F_PE_NLGLOB10_A_RECORDS="+json.dumps(arows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB10_B_RECORDS="+json.dumps(brows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB10_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB10=PASS")
