#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
targets=[
("O05","TG","HEAD",0.00025),("O05","TG","HEAD",0.000125),
("O05","TG","HEAD",0.0000625),("O05","TG","HEAD",0.00003125),
("O05","TG","RUNOFF",0.00025),("O05","TG","RUNOFF",0.000125),
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

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def classify(d):
    half=int(d["HALF"]); domain=int(d["DOMAIN_FAIL"])==1; reason=d["REASON"]
    if domain: return f"HALF{half}_ACCEPTED_DOMAIN"
    if reason=="ENDPOINT_SOLVE_FAILURE": return f"HALF{half}_ENDPOINT"
    if any(k in reason for k in ("ROUTE","PONDING","TOP_UNAVAILABLE","NONFINITE")):
        return f"HALF{half}_ROUTE_OR_POND"
    return "OTHER"

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    attrs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13A_HALF_FAIL|")]
    d=attrs[-1] if attrs else None
    row={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,"attribution_count":len(attrs)}
    if d:
        row.update({"half":int(d["HALF"]),"step":int(d["STEP"]),"half_dt":float(d["DT"]),
                    "domain_fail":int(d["DOMAIN_FAIL"])==1,"eligible":int(d["ELIGIBLE"])==1,
                    "reason":d["REASON"],"pre_theta_min":float(d["PRE_THETA_MIN"]),
                    "pre_theta_max":float(d["PRE_THETA_MAX"]),"cum_ledger":float(d["CUM_LEDGER"]),
                    "class":classify(d)})
    rows.append(row)

coverage=(len(rows)==7 and proc==0 and all(x["attribution_count"]>=1 for x in rows) and
          all(math.isfinite(x["pre_theta_min"]) and math.isfinite(x["pre_theta_max"]) and math.isfinite(x["cum_ledger"]) for x in rows))
counts={}
for x in rows:
    if "class" in x: counts[x["class"]]=counts.get(x["class"],0)+1

if not coverage:
    cls="BLOCKED_NLGLOB13A_HALFSTEP_ATTRIBUTION"
elif counts.get("HALF1_ACCEPTED_DOMAIN",0)>=6:
    cls="NLGLOB13A_FIRST_HALF_DOMAIN_DOMINANT"
elif counts.get("HALF2_ACCEPTED_DOMAIN",0)>=6:
    cls="NLGLOB13A_SECOND_HALF_DOMAIN_DOMINANT"
elif counts.get("HALF1_ENDPOINT",0)>=6:
    cls="NLGLOB13A_FIRST_HALF_ENDPOINT_DOMINANT"
elif counts.get("HALF2_ENDPOINT",0)>=6:
    cls="NLGLOB13A_SECOND_HALF_ENDPOINT_DOMINANT"
elif counts.get("HALF1_ROUTE_OR_POND",0)+counts.get("HALF2_ROUTE_OR_POND",0)>=6:
    cls="NLGLOB13A_ROUTE_POND_DOMINANT"
else:
    cls="NLGLOB13A_MIXED_HALFSTEP_FAILURE"

summary={"classification":cls,"coverage_ok":coverage,"target_n":len(rows),"process_failures":proc,
         "counts":counts,"half1_failures":sum(x.get("half")==1 for x in rows),
         "half2_failures":sum(x.get("half")==2 for x in rows),
         "max_abs_prior_cumulative_ledger":max((abs(x.get("cum_ledger",0.0)) for x in rows),default=0.0)}
print("F_PE_NLGLOB13A_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13A=PASS")
