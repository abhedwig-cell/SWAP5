#!/usr/bin/env python3
import sys,json
from pathlib import Path
lines=Path(sys.argv[1]).read_text().splitlines();header=None;finals=[];tr={}
for line in lines:
 if line.startswith("Q4B,soil,"):header=line.split(",")
 elif line.startswith("Q4B30EXACT,"):finals.append(dict(zip(header,line.split(","))))
 elif line.startswith("HEADTRACE,"):
  z=line.split(",");tr.setdefault((z[1],z[2]),[]).append(tuple(map(float,z[5:8])))
if len(finals)!=4:raise SystemExit(f"expected 4 cases got {len(finals)}")
bad=[(r["soil"],r["geom"],r["status"],r["fail_step"]) for r in finals if r["completed"]!="1"]
if bad:raise SystemExit(f"exact fixture incomplete {bad}")
if max(abs(float(r["max_mass_resid_cm"])) for r in finals)>1e-6:raise SystemExit("mass gate")
out={}
for k,v in tr.items():
 cols=list(zip(*v));info=[]
 for col in cols:
  c30=sum((a<-30)!=(b<-30) for a,b in zip(col,col[1:]))
  info.append({"min":min(col),"max":max(col),"cross30":c30})
 out[str(k)]=info
print(json.dumps(out,indent=2))
for k,info in out.items():
 if info[0]["cross30"]<20:raise SystemExit(f"insufficient -30 surface cycling {k}: {info[0]}")
print("A28_Q4B_MINUS30_STAGE_A=PASS")
