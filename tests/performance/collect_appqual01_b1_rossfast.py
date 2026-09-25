from __future__ import annotations
import json,re,sys
from pathlib import Path
if len(sys.argv)!=4:
    raise SystemExit("usage: collect_appqual01_b1_rossfast.py <transcript> <source_commit> <output_json>")
text=Path(sys.argv[1]).read_text()
source=sys.argv[2]
out=Path(sys.argv[3])
pat=re.compile(r"^APPQUAL01_B1_PAIRED,route=(?P<route>[^,]+),n=(?P<n>\d+),init_seconds=\s*(?P<init>[^,]+),run_seconds=\s*(?P<run>[^,]+),ns_per_column=\s*(?P<ns>[^,]+),max_mass_residual=\s*(?P<mass>[^\n]+)$",re.M)
rows={}
for m in pat.finditer(text):
    key=(int(m.group("n")),m.group("route"))
    rows[key]={
      "init_seconds":float(m.group("init")),
      "run_seconds":float(m.group("run")),
      "ns_per_column":float(m.group("ns")),
      "max_mass_residual":float(m.group("mass"))
    }
records=[]
for n in (100,1000,10000):
    ref=rows.get((n,"REFERENCE")); ross=rows.get((n,"ROSSFAST"))
    if ref is None or ross is None: raise SystemExit(f"missing paired record n={n}")
    ratio=ross["run_seconds"]/ref["run_seconds"]
    records.append({
      "workload_id":f"B1-C1-B01-S{n}",
      "source_commit":source,
      "swap_columns":n,
      "reference":ref,
      "rossfast":ross,
      "rossfast_to_reference_ratio":ratio,
      "rossfast_speedup_factor":1.0/ratio,
      "rossfast_speedup_percent":(1.0-ratio)*100.0
    })
out.write_text(json.dumps({"schema":"swap5-appqual01-b1-rossfast-v1","records":records},indent=2,sort_keys=True)+"\n")
print("APPQUAL01_B1_ROSSFAST_RECORDS=PASS")
