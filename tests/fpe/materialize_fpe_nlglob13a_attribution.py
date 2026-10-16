#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""    if(half_fail .or. .not.eligible)then
      state=saved_state
"""
repl1="""    if(half_fail .or. .not.eligible)then
      write(*,'(*(g0))') 'F_PE_NLGLOB13A_HALF_FAIL|HALF=1|STEP=',step_index,'|DT=',dt, &
           '|DOMAIN_FAIL=',merge(1,0,half_fail),'|ELIGIBLE=',merge(1,0,eligible), &
           '|REASON=',trim(terminal_reason),'|PRE_THETA_MIN=',minval(state%water_content), &
           '|PRE_THETA_MAX=',maxval(state%water_content),'|ROUTE=',trim(route_id),'|CUM_LEDGER=',cumledger
      state=saved_state
"""
if needle not in src:
    raise SystemExit("NLGLOB13A first half marker missing")
src=src.replace(needle,repl1,1)

if needle not in src:
    raise SystemExit("NLGLOB13A second half marker missing")
repl2="""    if(half_fail .or. .not.eligible)then
      write(*,'(*(g0))') 'F_PE_NLGLOB13A_HALF_FAIL|HALF=2|STEP=',step_index,'|DT=',dt, &
           '|DOMAIN_FAIL=',merge(1,0,half_fail),'|ELIGIBLE=',merge(1,0,eligible), &
           '|REASON=',trim(terminal_reason),'|PRE_THETA_MIN=',minval(state%water_content), &
           '|PRE_THETA_MAX=',maxval(state%water_content),'|ROUTE=',trim(route_id),'|CUM_LEDGER=',cumledger
      state=saved_state
"""
src=src.replace(needle,repl2,1)

if src.count("F_PE_NLGLOB13A_HALF_FAIL") != 2:
    raise SystemExit("NLGLOB13A attribution injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB13A_MATERIALIZER=PASS")
