#!/usr/bin/env python3
import csv,sys
from pathlib import Path
base=Path(sys.argv[1]);new=Path(sys.argv[2])
def rows(path):
    with path.open(newline="") as f:return list(csv.DictReader(f))
a=rows(base/"abc_raw.csv");b=rows(new/"abc_raw.csv")
if len(a)!=len(b):raise SystemExit(f"raw row count {len(a)} != {len(b)}")
ignore={"wall_seconds"}
c_checked=0
for i,(x,y) in enumerate(zip(a,b),1):
    if x["arm"]!="3": continue
    c_checked+=1
    xx={k:v for k,v in x.items() if k not in ignore}
    yy={k:v for k,v in y.items() if k not in ignore}
    if xx!=yy:
        diff=[k for k in xx if xx[k]!=yy.get(k)]
        raise SystemExit(f"RFM C mismatch row {i} keys={diff}: "+str([(k,xx[k],yy.get(k)) for k in diff[:8]]))
print(f"PERF02_RFM_C_NON_TIMING_IDENTITY=PASS rows={c_checked}")
comp=rows(new/"abc_comparison.csv")
e1=sum(r["classification"]=="E1" for r in comp)
bc=sum(r["B_completed"]=="1" and r["C_completed"]=="1" for r in comp)
rawB=sum(r["arm"]=="2" and r["completed"]=="1" for r in b)
rawC=sum(r["arm"]=="3" and r["completed"]=="1" for r in b)
if (rawB,rawC,bc,e1)!=(29,30,29,29):
    raise SystemExit(f"current-canonical envelope mismatch B={rawB} C={rawC} joint={bc} E1={e1}")
print("PERF02_CURRENT_CANONICAL_E1_GATE=PASS B=29 C=30 joint=29 E1=29")
t=rows(new/"abc_timing.csv")
rat=[]
for r in t:
    if r.get("B_complete")=="True" and r.get("C_complete")=="True":
        rat.append((int(r["case_id"]),float(r["B_over_C_speed_ratio"]),float(r["B_median_s"]),float(r["C_median_s"])))
print("PERF02_TIMING",rat)
