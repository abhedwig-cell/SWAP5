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
def key(r):return (r["soil"],r["geom"],r["regime"])
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
out={"joint":joint,"failures":failures,"max":mx}
print(json.dumps(out,indent=2))
if failures:raise SystemExit("completion regression")
if mx["mass"]>1e-6:raise SystemExit("mass gate")
if mx["storage"]>0.02 or mx["bottom"]>0.02:raise SystemExit("water gate")
if mx["theta"]>0.01:raise SystemExit("theta gate")
print("A28_Q4_LONG_HISTORY_ENDSTATE=PASS")
