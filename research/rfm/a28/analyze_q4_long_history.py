#!/usr/bin/env python3
import csv,sys,json
from pathlib import Path
p=Path(sys.argv[1])
lines=p.read_text().splitlines()
header=None; rows=[]
for line in lines:
    if line.startswith("Q4,soil,"): header=line.split(",");continue
    if line.startswith(("Q4EXACT,","Q4APPROX,")):
        vals=line.split(",")
        rows.append(dict(zip(header,vals)))
def key(r):return (r["soil"],r["geom"],r["history"])
exact={key(r):r for r in rows if r["Q4"]=="Q4EXACT"}
approx={key(r):r for r in rows if r["Q4"]=="Q4APPROX"}
if set(exact)!=set(approx):raise SystemExit("case key mismatch")
mx={"storage":0.0,"theta":0.0,"mass":0.0,"bottom":0.0}; joint=0; failures=[]
for k in sorted(exact):
 x,y=exact[k],approx[k]
 if x["completed"]!="1" or y["completed"]!="1":
  failures.append((k,x["completed"],y["completed"],x["status"],y["status"]));continue
 joint+=1
 mx["storage"]=max(mx["storage"],abs(float(x["total_storage_cm"])-float(y["total_storage_cm"])))
 mx["bottom"]=max(mx["bottom"],abs(float(x["bottom_out_cm"])-float(y["bottom_out_cm"])))
 mx["mass"]=max(mx["mass"],abs(float(y["max_mass_resid_cm"])))
 for q in ("theta1","theta5","theta10"):mx["theta"]=max(mx["theta"],abs(float(x[q])-float(y[q])))
cycles={}
for line in lines:
    if not line.startswith("CYCLE,"):continue
    z=line.split(",")
    k=(z[1],z[2],z[3],z[5])
    rec={"storage":float(z[6]),"theta":[float(z[7]),float(z[8]),float(z[9])],
         "endpoint":float(z[10]),"wall_age":float(z[11]),"wall_s":float(z[12])}
    cycles.setdefault(k,{})[z[4]]=rec
cycle_max={"storage":0.0,"theta":0.0,"endpoint":0.0}
missing=[]
for k,v in cycles.items():
    if "0" not in v or "1" not in v:missing.append(k);continue
    x,y=v["0"],v["1"]
    cycle_max["storage"]=max(cycle_max["storage"],abs(x["storage"]-y["storage"]))
    cycle_max["endpoint"]=max(cycle_max["endpoint"],abs(x["endpoint"]-y["endpoint"]))
    cycle_max["theta"]=max(cycle_max["theta"],max(abs(a-b) for a,b in zip(x["theta"],y["theta"])))
    if min(x["wall_age"],y["wall_age"],x["wall_s"],y["wall_s"])<0:raise SystemExit("negative wall history")
if len(cycles)<240:raise SystemExit(f"insufficient cycle samples {len(cycles)}")
if missing:raise SystemExit(f"missing exact/approx cycle pairs {missing[:4]}")
if cycle_max["storage"]>0.02 or cycle_max["endpoint"]>0.02:raise SystemExit("cycle water gate")
if cycle_max["theta"]>0.01:raise SystemExit("cycle theta gate")
out={"joint":joint,"failures":failures,"max":mx,"cycle_max":cycle_max,"cycle_pairs":len(cycles)}
print(json.dumps(out,indent=2))
if failures:raise SystemExit("completion regression")
if mx["mass"]>1e-6:raise SystemExit("mass gate")
if mx["storage"]>0.02 or mx["bottom"]>0.02:raise SystemExit("water gate")
if mx["theta"]>0.01:raise SystemExit("theta gate")
print("A28_Q4_LONG_HISTORY_ENDSTATE=PASS")
