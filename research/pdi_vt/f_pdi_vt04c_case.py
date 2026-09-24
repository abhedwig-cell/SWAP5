#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys
base=Path(__file__).with_name("f_pdi_vt04_case_host.py")
subprocess.run([sys.executable,str(base),*sys.argv[1:]],check=True)
case=Path(sys.argv[2])/"swap.swp"
text=case.read_text()
old="SWHEA = 0"
if text.count(old)!=1:
    raise SystemExit("expected one SWHEA=0 target")
text=text.replace(old,"SWHEA = 1",1)
for key in ("SWVAP","SWWBA","SWINC"):
    old_key=f"{key} = 0"
    if text.count(old_key)!=1:
        raise SystemExit(f"expected one {old_key} output switch")
    text=text.replace(old_key,f"{key} = 1",1)
case.write_text(text)
