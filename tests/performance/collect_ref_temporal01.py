from __future__ import annotations
import json,re,sys
from pathlib import Path
if len(sys.argv)!=3:
    raise SystemExit("usage: collect_ref_temporal01.py <transcript> <output_json>")
text=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])
pat=re.compile(r"^REF_TEMPORAL01_ROW,case=(?P<case>\d+),h0=\s*(?P<h0>[^,]+),qfac=\s*(?P<qfac>[^,]+),dt=\s*(?P<dt>[^,]+),bound=\s*(?P<bound>[^,]+),head_err=\s*(?P<err>[^,]+),ratio=\s*(?P<ratio>[^,]+),route=(?P<route>\S+)\s*$",re.M)
rows=[]
for m in pat.finditer(text):
    d={k:(int(v) if k=="case" else v) for k,v in m.groupdict().items()}
    for k in ("h0","qfac","dt","bound","err","ratio"): d[k]=float(d[k])
    d["classification"]="BOUND_VALID_CONSERVATIVE" if d["bound"]+1e-15>=d["err"] else "BOUND_VALID_NONCONSERVATIVE"
    rows.append(d)
if len(rows)!=12: raise SystemExit(f"expected 12 rows got {len(rows)}")
summary={
  "schema":"swap5-ref-temporal01-wu01-v1",
  "rows":rows,
  "conservative_count":sum(r["classification"]=="BOUND_VALID_CONSERVATIVE" for r in rows),
  "nonconservative_count":sum(r["classification"]=="BOUND_VALID_NONCONSERVATIVE" for r in rows),
  "min_bound_to_error_ratio":min(r["ratio"] for r in rows),
  "max_bound_to_error_ratio":max(r["ratio"] for r in rows)
}
out.write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
print("REF_TEMPORAL01_COLLECTOR=PASS")
print(f"REF_TEMPORAL01_CONSERVATIVE={summary['conservative_count']}")
print(f"REF_TEMPORAL01_NONCONSERVATIVE={summary['nonconservative_count']}")
print(f"REF_TEMPORAL01_MIN_RATIO={summary['min_bound_to_error_ratio']:.17g}")
