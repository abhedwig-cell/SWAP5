#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    phi_hi=huge(1.0_real64)
"""
repl="""    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    write(*,'(*(g0))') 'F_PE_NLGLOB14E1_ROOT_ATTEMPT|STEP=',step_index,'|ROUTE=',trim(route_id)
    phi_hi=huge(1.0_real64)
"""
if needle not in src:
    raise SystemExit("NLGLOB14E1 root-attempt marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB14E1_ROOT_ATTEMPT" not in src:
    raise SystemExit("NLGLOB14E1 injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14E1_MATERIALIZER=PASS")
