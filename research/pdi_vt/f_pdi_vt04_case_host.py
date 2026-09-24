#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

base=Path(__file__).with_name("f_pdi_vt04_case_v2.py")
subprocess.run([sys.executable,str(base),*sys.argv[1:]],check=True)
case=Path(sys.argv[2])/"swap.swp"
lines=case.read_text().splitlines()
if not any(x.strip().startswith("CRITDEVMASBAL") for x in lines):
    out=[]
    done=False
    for x in lines:
        out.append(x)
        if x.strip().startswith("SWHEADER"):
            out.append("  CRITDEVMASBAL = 1.0E-6")
            done=True
    if not done:
        raise SystemExit("SWHEADER not found")
    case.write_text("\n".join(out)+"\n")
