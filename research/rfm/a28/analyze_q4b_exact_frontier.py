#!/usr/bin/env python3
import sys,json
from pathlib import Path
lines=Path(sys.argv[1]).read_text().splitlines()
done={}; heads={}
for line in lines:
 z=line.split(",")
 if line.startswith("Q4BEXACT,"):
  k=(z[1],z[2],z[3]);done[k]=(z[5]=="1",int(z[6]),int(z[7]),float(z[13]))
 elif line.startswith("FRONTIER,"):
  k=(z[1],z[2],z[3]);heads.setdefault(k,[]).extend(map(float,z[5:8]))
out=[]
for k in sorted(done):
 vals=heads.get(k,[])
 bands={"dry64":sum(x < -30 for x in vals),"mid32":sum(-30 <= x < -3 for x in vals),"wet16":sum(x >= -3 for x in vals)}
 crossings=0
 if vals:
  cls=lambda x:0 if x < -30 else (1 if x < -3 else 2)
  crossings=sum(cls(a)!=cls(b) for a,b in zip(vals,vals[1:]))
 out.append({"case":k,"completed":done[k][0],"status":done[k][1],"fail_step":done[k][2],"mass":done[k][3],"bands":bands,"crossings":crossings})
print(json.dumps(out,indent=2))
eligible=[x for x in out if x["completed"] and x["mass"]<=1e-6 and x["bands"]["dry64"] and x["bands"]["mid32"] and x["crossings"]>=20]
if not eligible:raise SystemExit("NO_Q4B_EXACT_THRESHOLD_FIXTURE")
print("Q4B_EXACT_ELIGIBLE",json.dumps(eligible))
print("A28_Q4B_STAGE_A=PASS")
