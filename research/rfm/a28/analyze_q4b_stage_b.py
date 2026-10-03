#!/usr/bin/env python3
import sys,json
from pathlib import Path
lines=Path(sys.argv[1]).read_text().splitlines()
header=None;rows=[];cycles={}
for line in lines:
 if line.startswith("Q4,soil,") or line.startswith("Q4B,soil,"):header=line.split(",")
 elif line.startswith(("Q4BEXACT,","Q4BAPPROX,")):rows.append(dict(zip(header,line.split(","))))
 elif line.startswith("CYCLE,"):
  z=line.split(",");k=(z[1],z[2],z[3],z[5]);cycles.setdefault(k,{})[z[4]]=list(map(float,z[6:13]))
def key(r):return (r["soil"],r["geom"],r["history"])
e={key(r):r for r in rows if r["Q4B"]=="Q4BEXACT"};a={key(r):r for r in rows if r["Q4B"]=="Q4BAPPROX"}
if set(e)!=set(a) or len(e)!=4:raise SystemExit("frozen case mismatch")
mx={"storage":0.,"bottom":0.,"theta":0.,"mass":0.,"endpoint":0.}
for k in e:
 x,y=e[k],a[k]
 if x["completed"]!="1" or y["completed"]!="1":raise SystemExit(f"completion failure {k}")
 mx["storage"]=max(mx["storage"],abs(float(x["total_storage_cm"])-float(y["total_storage_cm"])))
 mx["bottom"]=max(mx["bottom"],abs(float(x["bottom_out_cm"])-float(y["bottom_out_cm"])))
 mx["mass"]=max(mx["mass"],abs(float(y["max_mass_resid_cm"])))
 for q in ("theta1","theta5","theta10"):mx["theta"]=max(mx["theta"],abs(float(x[q])-float(y[q])))
for k,v in cycles.items():
 if "0" not in v or "1" not in v:raise SystemExit("missing cycle pair")
 x,y=v["0"],v["1"];mx["storage"]=max(mx["storage"],abs(x[0]-y[0]));mx["endpoint"]=max(mx["endpoint"],abs(x[4]-y[4]))
 mx["theta"]=max(mx["theta"],max(abs(x[i]-y[i]) for i in (1,2,3)))
print(json.dumps({"cases":len(e),"cycle_pairs":len(cycles),"max":mx},indent=2))
if mx["mass"]>1e-6 or mx["storage"]>0.02 or mx["bottom"]>0.02 or mx["theta"]>0.01 or mx["endpoint"]>0.02:raise SystemExit("Q4B gate")
print("A28_Q4B_MINUS3_STAGE_B=PASS")
