#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys
base=Path(__file__).with_name("f_pdi_vt04_case_host.py")
subprocess.run([sys.executable,str(base),*sys.argv[1:]],check=True)
case=Path(sys.argv[2])/"swap.swp"
text=case.read_text()
old="H = -1.0E5 -1.0E5"
if text.count(old)!=1:
    raise SystemExit("expected one VT04 dry-profile target")
case.write_text(text.replace(old,"H = -1.0E4 -1.0E4",1))
