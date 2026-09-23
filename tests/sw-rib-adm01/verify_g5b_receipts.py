from __future__ import annotations
import csv
import subprocess
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("usage: verify_g5b_receipts.py <ribasim-output> <bridge-exe>")
log=Path(sys.argv[1])
exe=sys.argv[2]
rows=[]
for row in csv.reader(log.read_text().splitlines()):
    if row and row[0]=="G5B_RECEIPT":
        rows.append(row)
expected=["E1_POSITIVE_DRAINAGE","E2_NEGATIVE_INFILTRATION_SUFFICIENT","E3_NEGATIVE_INFILTRATION_LIMITED"]
assert [r[1] for r in rows]==expected, rows
for row in rows:
    _,case,head,requested,realized,residual=row
    subprocess.run([exe,case,head,requested,realized],check=True)
print("SW_RIB_ADM01_G5B_RECEIPT_TO_PRODUCTION_TRANSACTION=PASS")
