#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); phase=sys.argv[3]
materials={x["id"]:x for x in bank["materials"]}
patterns=["R1","R1P5","R2"]; base_dts=[0.01,0.005]
if phase=="p0":
    cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
    min_points=80; min_overall=0.85; min_pattern=0.80; min_coverage=0.30; max_incomplete=99
elif phase=="holdout":
    cases=[("B12",1.0),("B12",3.0),("B12",5.0),("O14",1.0),("O14",3.0),("O14",5.0)]
    min_points=130; min_overall=0.80; min_pattern=0.75; min_coverage=0.30; max_incomplete=2
else:
    raise SystemExit("phase must be p0 or holdout")

def run(mid,rain,dt,pattern):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),pattern]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    pts=[]; unavailable=[]
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT10_POINT|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            e10=float(d["E10"]); eh=float(d["EHEAD"])
            pts.append({"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
                "step":int(d["STEP"]),"dt":float(d["DT"]),"ratio":float(d["RATIO"]),
                "e3":float(d["E3"]),"e8":float(d["E8"]),"e9":float(d["E9"]),"e10":e10,"ehead":eh,
                "etheta":float(d["ETHETA"]),"estorage":float(d["ESTORAGE"]),
                "alt":int(d["ALT"]),"pred_safe":e10<=0.01,"actual_safe":eh<=0.01})
        elif line.startswith("F_PE_TIMEINT10_LABEL_UNAVAILABLE|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            unavailable.append({"material":d["MATERIAL"],"rain":float(d["RAIN"]),"pattern":d["PATTERN"],
                "step":int(d["STEP"]),"dt":float(d["DT"]),"ratio":float(d["RATIO"]),
                "e9_ok":int(d.get("E9_OK","0")),"e10_ok":int(d.get("E10_OK","0")),"half1_ok":int(d["HALF1_OK"]),"half2_ok":int(d["HALF2_OK"])})
    ok=cp.returncode==0 and "F_PE_TIMEINT10=PASS" in cp.stdout
    return {"ok":ok,"material":mid,"rain":rain,"base_dt":dt,"pattern":pattern,"points":len(pts),
            "unavailable":len(unavailable),"stdout_tail":cp.stdout[-1200:] if not ok else "",
            "stderr_tail":cp.stderr[-1200:] if not ok else ""},pts,unavailable

def ranks(v):
    order=sorted(range(len(v)),key=lambda i:v[i]); r=[0.0]*len(v); i=0
    while i<len(order):
        j=i+1
        while j<len(order) and v[order[j]]==v[order[i]]: j+=1
        q=0.5*(i+j-1)+1.0
        for k in range(i,j): r[order[k]]=q
        i=j
    return r
def pearson(a,b):
    if len(a)<2:return None
    ma=sum(a)/len(a); mb=sum(b)/len(b)
    da=[x-ma for x in a]; db=[x-mb for x in b]
    va=sum(x*x for x in da); vb=sum(x*x for x in db)
    if va<=0 or vb<=0:return None
    return sum(x*y for x,y in zip(da,db))/math.sqrt(va*vb)
def spear(a,b): return pearson(ranks(a),ranks(b))

runs=[]; pts=[]; unavailable=[]
for p in patterns:
  for mid,rain in cases:
    for dt in base_dts:
      rr,pp,uu=run(mid,rain,dt,p); runs.append(rr); pts+=pp; unavailable+=uu

overall=spear([x["e10"] for x in pts],[x["ehead"] for x in pts])
per={p:spear([x["e10"] for x in pts if x["pattern"]==p],[x["ehead"] for x in pts if x["pattern"]==p]) for p in patterns}
ratios=sorted([x["ehead"]/x["e10"] for x in pts if x["e10"]>0 and x["ehead"]>0])
median=ratios[len(ratios)//2] if ratios else None
inside=sum(0.25<=x<=2.0 for x in ratios)/len(ratios) if ratios else 0.0
false_safe=[x for x in pts if x["pred_safe"] and not x["actual_safe"]]
actual_safe=[x for x in pts if x["actual_safe"]]
true_safe=[x for x in pts if x["pred_safe"] and x["actual_safe"]]
coverage=len(true_safe)/len(actual_safe) if actual_safe else 0.0
incomplete=sum(r["unavailable"]>0 for r in runs)
runs_ok=all(r["ok"] for r in runs)
finite=all(math.isfinite(x["e10"]) and x["e10"]>=0 and math.isfinite(x["ehead"]) for x in pts)
no_alt=all(x["alt"]==0 for x in pts)
qualifies=(runs_ok and len(pts)>=min_points and incomplete<=max_incomplete and finite and no_alt and
           overall is not None and overall>=min_overall and
           all(per[p] is not None and per[p]>=min_pattern for p in patterns) and
           len(false_safe)==0 and coverage>=min_coverage)

summary={"phase":phase,"runs_ok":runs_ok,"trajectories":len(runs),"points":len(pts),
 "unavailable_labels":len(unavailable),"incomplete_label_trajectories":incomplete,
 "finite":finite,"no_alternative_solver":no_alt,"spearman_overall":overall,"spearman_by_pattern":per,
 "median_actual_over_e10":median,"fraction_ratio_0p25_to_2":inside,
 "min_actual_over_e10":min(ratios) if ratios else None,"max_actual_over_e10":max(ratios) if ratios else None,
 "false_safe":len(false_safe),"actual_safe":len(actual_safe),"true_safe":len(true_safe),
 "safe_coverage":coverage,"qualifies":qualifies}
tag="F_PE_TIMEINT10" if phase=="p0" else "F_PE_TIMEINT10A"
print(tag+"_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print(tag+"_UNAVAILABLE="+json.dumps(unavailable,separators=(",",":"),sort_keys=True))
print(tag+"_FALSE_SAFE="+json.dumps(false_safe,separators=(",",":"),sort_keys=True))
print(tag+"_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not runs_ok: raise SystemExit("one or more full BDF2 trajectories failed")
print(tag+"=PASS")
