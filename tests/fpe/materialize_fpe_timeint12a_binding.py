#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
ap.add_argument("--adapter-module",default="mod_fpe_timeint12a_dynamic_top_boundary_solver_adapter")
args=ap.parse_args()
src=Path(args.source).read_text()
old="mod_reference_richards_legacy_binding"
new="mod_fpe_timeint12a_reference_binding"
src=src.replace(f"module {old}",f"module {new}",1)
src=src.replace(f"end module {old}",f"end module {new}",1)
old_guard="""    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
"""
new_guard="""    if (request%numerical%conductivity_implicit_mode < 0 .or. &
        request%numerical%conductivity_implicit_mode > 1) then
       route = 'timeint12a-conductivity-mode-invalid'
       return
    end if
"""
if old_guard not in src: raise SystemExit("implicit-k guard patch point missing")
src=src.replace(old_guard,new_guard,1)
Path(args.output).write_text(src)
print("F_PE_TIMEINT12A_BINDING_MATERIALIZER=PASS")
