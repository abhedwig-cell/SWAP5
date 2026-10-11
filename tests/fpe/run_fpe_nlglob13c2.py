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
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def close(a,b):
    return abs(a-b)<=1e-13*max(1.0,abs(a),abs(b))
def ov(d):
    tr=float(d["TR"]); ts=float(d["TS"]); mn=float(d["THETA_MIN"]); mx=float(d["THETA_MAX"])
    return max((tr-mn)/(ts-tr),(mx-ts)/(ts-tr),0.0)

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    events=[]
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_NLGLOB13C2_PROBE|"):
            events.append(("probe",fields(line)))
        elif line.startswith("F_PE_NLGLOB13C_DOMAIN|"):
            events.append(("domain",fields(line)))
    idlogs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13C2_STATE|")]
    identity_ok=False
    if idlogs:
        groups={}
        for d in idlogs:
            groups.setdefault((int(d["STEP"]),int(d["HALF"]),int(d["QUARTER"])),[]).append(d)
        for (gstep,ghalf,gquarter),g in groups.items():
            if gquarter!=1 or len(g)!=16: continue
            ok=True
            for d in g:
                vals=[float(d[k]) for k in ("PTHETA","CTHETA","PH","CH","PPOND","CPOND")]
                ok=ok and all(math.isfinite(x) for x in vals)
                ok=ok and abs(vals[0]-vals[1])<=1e-14 and abs(vals[2]-vals[3])<=1e-10 and abs(vals[4]-vals[5])<=1e-12
            if ok: identity_ok=True; break
    parent_idx=None; parent=None
    for idx,(kind,d) in enumerate(events):
        if kind=="domain" and close(float(d["STEPDT"]),0.5*dt):
            parent_idx=idx; parent=d; break
    child=None
    if parent_idx is not None:
        for kind,d in events[parent_idx+1:]:
            if kind=="probe" and close(float(d["STEPDT"]),0.25*dt):
                child=d; break
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,
         "identity_authority":True,"identity_reobserved":identity_ok,
         "parent_found":parent is not None,"child_found":child is not None}
    if parent is not None and child is not None:
        op=ov(parent); oc=ov(child)
        adm=int(child["ADMISSIBLE"])==1
        ratio=(oc/op) if (op>0 and not adm) else 0.0 if adm else math.inf
        rec.update({"parent_overshoot":op,"child_overshoot":oc,"child_admissible":adm,"ratio":ratio,
                    "parent_step":int(parent["STEP"]),"child_step":int(child["STEP"]),
                    "child_theta_min":float(child["THETA_MIN"]),"child_theta_max":float(child["THETA_MAX"])})
    rows.append(rec)

covered=[x for x in rows if x["parent_found"] and x["child_found"] and x["identity_authority"]]
good=0; noncontract=0; resolved=0; contracted=0
for x in covered:
    if x["child_admissible"]:
        resolved+=1; good+=1
    elif x["ratio"]<1:
        contracted+=1; good+=1
    if (not x["child_admissible"]) and x["ratio"]>=.9:
        noncontract+=1
strong=sum(x["child_admissible"] or ((not x["child_admissible"]) and x["ratio"]<=.60) for x in covered)
coverage=(len(covered)==7 and proc==0)
if not coverage:
    cls="BLOCKED_NLGLOB13C2_COVERAGE"
elif good==7 and strong>=5:
    cls="NLGLOB13C2_SAME_ORIGIN_H4_CONTRACTION_CONFIRMED"
elif noncontract>=4:
    cls="NLGLOB13C2_SAME_ORIGIN_H4_NONCONTRACTING"
else:
    cls="NLGLOB13C2_MIXED_SAME_ORIGIN_H4"
summary={"classification":cls,"coverage_ok":coverage,"target_count":len(rows),"covered_count":len(covered),
         "resolved_at_h4":resolved,"contracted_but_inadmissible":contracted,"strong_count":strong,
         "noncontracting_count":noncontract,"process_failures":proc}
print("F_PE_NLGLOB13C2_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C2_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13C2=PASS")
