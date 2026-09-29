#!/usr/bin/env python3
import csv, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
src=Path(sys.argv[2])
rows=list(csv.DictReader(src.open()))
if len(rows)!=36:
    raise SystemExit("F_PE_ELASTIC08_FAIL expected 36 Staringreeks materials")

for r in rows:
    args=[r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"]]
    for mode in ("off","on"):
        cp=subprocess.run([str(exe),mode,*args],text=True,capture_output=True)
        marker="F_PE_ELASTIC08_PREPARE=PASS "+mode
        if cp.returncode or marker not in cp.stdout:
            print("F_PE_ELASTIC08_MATERIAL_FAIL="+r["name"]+"|MODE="+mode)
            print(cp.stdout); print(cp.stderr)
            raise SystemExit(1)

r=rows[0]
args=[r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"]]
for mode in ("invalid-negative","invalid-nan","invalid-ksatexm","invalid-direct","invalid-tabulated","invalid-hysteresis"):
    cp=subprocess.run([str(exe),mode,*args],text=True,capture_output=True)
    marker="F_PE_ELASTIC08_PREPARE=PASS "+mode
    if cp.returncode or marker not in cp.stdout:
        print("F_PE_ELASTIC08_FAIL_CLOSED_CASE="+mode)
        print(cp.stdout); print(cp.stderr)
        raise SystemExit(1)

print("F_PE_ELASTIC08_MATERIALS=36")
print("F_PE_ELASTIC08_R1_PREPARATION=PASS")
print("F_PE_ELASTIC08_R2_HETEROGENEOUS=PASS")
print("F_PE_ELASTIC08_R4_FAIL_CLOSED=PASS")
