#!/usr/bin/env python3
import sys,json,math
from pathlib import Path
lines=Path(sys.argv[1]).read_text().splitlines()
summary={}
for line in lines:
 if line.startswith("Q4BEXACT,"):
  z=line.split(","); summary[(z[1],z[2])]={"completed":z[5],"status":z[6],"fail_step":z[7],"mass":float(z[13])}
tr={}
for line in lines:
 if not line.startswith("HEADTRACE,"):continue
 z=line.split(",");k=(z[1],z[2]);tr.setdefault(k,[]).append(tuple(map(float,z[5:8])))
out={}
for k,v in summary.items():
 vals=tr.get(k,[])
 if v["completed"]!="1":raise SystemExit(f"exact fixture incomplete {k} {v}")
 if v["mass"]>1e-6:raise SystemExit(f"mass gate {k}")
 if len(vals)<2400:raise SystemExit(f"head trace incomplete {k} n={len(vals)}")
 cols=list(zip(*vals)); metrics=[]
 for a in cols:
  crossings30=sum((a[i-1] < -30) != (a[i] < -30) for i in range(1,len(a)))
  crossings3=sum((a[i-1] < -3) != (a[i] < -3) for i in range(1,len(a)))
  metrics.append({"min":min(a),"max":max(a),"cross30":crossings30,"cross3":crossings3})
 out[str(k)]=metrics
print(json.dumps(out,indent=2))
total30=sum(x["cross30"] for vv in out.values() for x in vv)
total3=sum(x["cross3"] for vv in out.values() for x in vv)
for k,metrics in out.items():
 for j in (0,1):
  bands=set()
  if metrics[j]["min"] < -30: bands.add(0)
  if metrics[j]["min"] < -3 and metrics[j]["max"] >= -30: bands.add(1)
  if metrics[j]["max"] >= -3: bands.add(2)
  if len(bands)<2 or metrics[j]["cross30"]+metrics[j]["cross3"]<20:
   raise SystemExit(f"insufficient threshold cycling {k} consumer={j}: {metrics[j]}")
if total30<20:raise SystemExit(f"insufficient -30 crossings {total30}")
if total3<20:raise SystemExit(f"insufficient -3 crossings {total3}")
print(f"A28_Q4B_STAGE_A=PASS cross30={total30} cross3={total3}")
