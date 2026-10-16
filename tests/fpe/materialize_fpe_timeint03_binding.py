#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()
old_module="mod_reference_richards_legacy_binding"
new_module="mod_fpe_timeint03_reference_binding"
if f"module {old_module}" not in src:
    raise SystemExit("source module marker missing")
src=src.replace(f"module {old_module}",f"module {new_module}",1)
src=src.replace(f"end module {old_module}",f"end module {new_module}",1)

old="""    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
"""
new="""    if (request%numerical%conductivity_implicit_mode < 0 .or. &
        request%numerical%conductivity_implicit_mode > 1) then
       route = 'timeint03-conductivity-mode-invalid'
       return
    end if
"""
if old not in src:
    raise SystemExit("implicit-k guard patch point missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT03_BINDING_MATERIALIZER=PASS")
