#!/usr/bin/env python3
import csv, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
src=Path(sys.argv[2])
rows=list(csv.DictReader(src.open()))
if len(rows)!=36:
    raise SystemExit("F_PE_ELASTIC05_FAIL expected 36 Staringreeks materials")

for r in rows:
    args=[r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"]]
    cp=subprocess.run([str(exe),"check",*args],text=True,capture_output=True)
    if cp.returncode or "F_PE_ELASTIC05_PROVIDER=PASS" not in cp.stdout:
        print("F_PE_ELASTIC05_MATERIAL_FAIL="+r["name"])
        print(cp.stdout); print(cp.stderr)
        raise SystemExit(1)

# Fail-closed API probes need only one valid material.
r=rows[0]
args=[r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"]]
for mode in ("invalid-missing","invalid-inactive-values","invalid-negative","invalid-ksatexm","invalid-nan","invalid-shape"):
    cp=subprocess.run([str(exe),mode,*args],text=True,capture_output=True)
    if cp.returncode==0:
        raise SystemExit("F_PE_ELASTIC05_FAIL expected nonzero for "+mode)

print("F_PE_ELASTIC05_MATERIALS=36")
print("F_PE_ELASTIC05_FAIL_CLOSED=PASS")
print("F_PE_ELASTIC05_PROVIDER_MATRIX=PASS")
