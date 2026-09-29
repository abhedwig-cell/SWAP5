#!/usr/bin/env python3
import csv,subprocess,sys
from pathlib import Path
exe=Path(sys.argv[1]);src=Path(sys.argv[2])
rows=list(csv.DictReader(src.open()))
for r in rows:
 cmd=[str(exe),r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"],"1e-6"]
 cp=subprocess.run(cmd,text=True,capture_output=True)
 if cp.returncode or "F_PE_ELASTIC04_PROVIDER=PASS" not in cp.stdout:
  print("F_PE_ELASTIC04_MATERIAL_FAIL="+r["name"]);print(cp.stdout);print(cp.stderr);raise SystemExit(1)
print("F_PE_ELASTIC04_MATERIALS=36")
print("F_PE_ELASTIC04_PROVIDER_MATRIX=PASS")
