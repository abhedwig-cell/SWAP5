#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys
base=Path(__file__).with_name("f_pdi_vt04c_case.py")
subprocess.run([sys.executable,str(base),*sys.argv[1:]],check=True)
dst=Path(sys.argv[2]); swp=dst/"swap.swp"; text=swp.read_text()
for old,new in {
" -10.0   15.0":" -10.0   10.0",
" -40.0   12.0":" -40.0    9.0",
" -70.0   10.0":" -70.0    8.0",
" -95.0    9.0":" -95.0    7.0",
}.items():
    if text.count(old)!=1: raise SystemExit(f"expected one TSOIL row: {old}")
    text=text.replace(old,new,1)
swp.write_text(text)
met=dst/"pdi.met"; m=met.read_text(); m=m.replace(",15.0,28.0,",",10.0,15.0,")
if m.count(",10.0,15.0,")!=2: raise SystemExit("cold meteo replacement count mismatch")
met.write_text(m)
