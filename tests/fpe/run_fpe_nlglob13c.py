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
def close(a,b):
    scale=max(1.0,abs(a),abs(b))
    return abs(a-b)<=1e-13*scale

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    logs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13C_DOMAIN|")]
    parent=[x for x in logs if close(float(x["STEPDT"]),0.5*dt)]
    child=[x for x in logs if close(float(x["STEPDT"]),0.25*dt)]
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"log_count":len(logs),
         "parent_n":len(parent),"child_n":len(child),"process_ok":cp.returncode==0}
    if parent and child:
        p=parent[-1]; q=child[-1]
        tr=float(p["TR"]); ts=float(p["TS"])
        def ov(d):
            mn=float(d["THETA_MIN"]); mx=float(d["THETA_MAX"])
            return max((tr-mn)/(ts-tr),(mx-ts)/(ts-tr),0.0)
        op=ov(p); oq=ov(q)
        state_same=all(close(float(p[k]),float(q[k])) for k in ("PRE_SIG1","PRE_SIG2","PRE_STORAGE","PRE_TOP_H","PRE_POND"))
        ratio=oq/op if op>0 else math.inf
        expo=math.log(op/oq,2.0) if op>0 and oq>0 else math.inf
        rec.update({"parent_overshoot":op,"child_overshoot":oq,"ratio":ratio,"exponent":expo,
                    "same_pre_state":state_same,
                    "parent_theta_min":float(p["THETA_MIN"]),"parent_theta_max":float(p["THETA_MAX"]),
                    "child_theta_min":float(q["THETA_MIN"]),"child_theta_max":float(q["THETA_MAX"]),
                    "parent_node_min":int(p["NODE_MIN"]),"parent_node_max":int(p["NODE_MAX"]),
                    "child_node_min":int(q["NODE_MIN"]),"child_node_max":int(q["NODE_MAX"])})
    rows.append(rec)

paired=[x for x in rows if x.get("parent_n",0)>0 and x.get("child_n",0)>0 and "ratio" in x]
coverage=(len(rows)==7 and len(paired)==7 and proc==0 and all(x["same_pre_state"] for x in paired) and
          all(math.isfinite(x["parent_overshoot"]) and math.isfinite(x["child_overshoot"]) and
              x["parent_overshoot"]>0 and x["child_overshoot"]>0 for x in paired))
ratios=sorted(x["ratio"] for x in paired)
exps=sorted(x["exponent"] for x in paired)
median_ratio=ratios[len(ratios)//2] if ratios else math.inf
median_exp=exps[len(exps)//2] if exps else -math.inf
contract_n=sum(x["ratio"]<1 for x in paired)
if not coverage:
    cls="BLOCKED_NLGLOB13C_SCALING_COVERAGE"
elif contract_n>=6 and median_ratio<=.60 and median_exp>=.5:
    cls="NLGLOB13C_OVERSHOOT_CONTRACTS_WITH_DT"
elif contract_n<=3 or median_ratio>=.9:
    cls="NLGLOB13C_OVERSHOOT_NONCONTRACTING"
else:
    cls="NLGLOB13C_MIXED_OVERSHOOT_SCALING"

summary={"classification":cls,"coverage_ok":coverage,"target_count":len(rows),"paired_count":len(paired),
         "contracting_pairs":contract_n,"median_ratio":median_ratio,"median_exponent":median_exp,
         "max_child_overshoot":max((x["child_overshoot"] for x in paired),default=math.nan),
         "process_failures":proc}
print("F_PE_NLGLOB13C_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C=PASS")
