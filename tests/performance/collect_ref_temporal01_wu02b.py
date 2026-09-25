from __future__ import annotations
import json,re,sys
from pathlib import Path
if len(sys.argv)!=3:
    raise SystemExit("usage: collect_ref_temporal01_wu02b.py <transcript> <output_json>")
text=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])
valid=re.compile(r"^REF_TEMPORAL01_WU02B_ROW,case=(?P<case>\d+),mat=(?P<mat>\d+),profile=(?P<profile>\d+),boundary=(?P<boundary>\d+),qfac=\s*(?P<qfac>[^,]+),dt=\s*(?P<dt>[^,]+),bound=\s*(?P<bound>[^,]+),head_err=\s*(?P<err>[^,]+),ratio=\s*(?P<ratio>[^,]+),route=(?P<route>[^,]+),classification=(?P<classification>\S+)\s*$",re.M)
invalid=re.compile(r"^REF_TEMPORAL01_WU02B_INVALID,case=(?P<case>\d+),mat=(?P<mat>\d+),profile=(?P<profile>\d+),boundary=(?P<boundary>\d+),qfac=\s*(?P<qfac>[^,]+),dt=\s*(?P<dt>[^,]+),classification=(?P<classification>\S+)\s*$",re.M)
rows=[]
for m in valid.finditer(text):
    d=m.groupdict()
    for k in ("case","mat","profile","boundary"): d[k]=int(d[k])
    for k in ("qfac","dt","bound","err","ratio"): d[k]=float(d[k])
    rows.append(d)
for m in invalid.finditer(text):
    d=m.groupdict()
    for k in ("case","mat","profile","boundary"): d[k]=int(d[k])
    for k in ("qfac","dt"): d[k]=float(d[k])
    d.update({"bound":None,"err":None,"ratio":None,"route":None})
    rows.append(d)
rows=sorted(rows,key=lambda r:r["case"])
if len(rows)!=32 or [r["case"] for r in rows]!=list(range(1,33)):
    raise SystemExit(f"incomplete matrix rows={len(rows)} cases={[r['case'] for r in rows]}")
classes={}
for r in rows: classes[r["classification"]]=classes.get(r["classification"],0)+1
ratios=[r["ratio"] for r in rows if r["ratio"] is not None]
mode5=[r["ratio"] for r in rows if r["ratio"] is not None and r["boundary"]==2]
summary={"schema":"swap5-ref-temporal01-wu02b-v1","rows":rows,"counts":classes,
         "min_bound_to_error_ratio":min(ratios) if ratios else None,
         "min_mode5_bound_to_error_ratio":min(mode5) if mode5 else None,
         "max_bound_to_error_ratio":max(ratios) if ratios else None}
out.write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
print("REF_TEMPORAL01_WU02B_COLLECTOR=PASS")
for k in sorted(classes): print(f"REF_TEMPORAL01_WU02B_{k}={classes[k]}")
if ratios: print(f"REF_TEMPORAL01_WU02B_MIN_RATIO={min(ratios):.17g}")
if mode5: print(f"REF_TEMPORAL01_WU02B_MODE5_MIN_RATIO={min(mode5):.17g}")
