#!/usr/bin/env python3
import csv,sys
from pathlib import Path
base=Path(sys.argv[1]);new=Path(sys.argv[2])
def rows(path):
    with path.open(newline="") as f:return list(csv.DictReader(f))
a=rows(base/"abc_raw.csv");b=rows(new/"abc_raw.csv")
if len(a)!=len(b):raise SystemExit(f"raw row count {len(a)} != {len(b)}")
ignore={"wall_seconds"}
for i,(x,y) in enumerate(zip(a,b),1):
    if {k:v for k,v in x.items() if k not in ignore}!={k:v for k,v in y.items() if k not in ignore}:
        diff=[k for k in x if k not in ignore and x[k]!=y.get(k)]
        raise SystemExit(f"raw mismatch row {i} keys={diff}: "+str([(k,x[k],y.get(k)) for k in diff[:8]]))
print(f"PERF02_RAW_NON_TIMING_IDENTITY=PASS rows={len(a)}")
t=rows(new/"abc_timing.csv")
rat=[]
for r in t:
    if r.get("B_complete")=="True" and r.get("C_complete")=="True":
        rat.append((int(r["case_id"]),float(r["B_over_C_speed_ratio"]),float(r["B_median_s"]),float(r["C_median_s"])))
print("PERF02_TIMING",rat)
