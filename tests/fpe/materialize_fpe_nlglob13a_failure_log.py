#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

block1="""    if(half_fail .or. .not.eligible)then
      state=saved_state
"""
repl1="""    if(half_fail .or. .not.eligible)then
      write(*,'(*(g0))') 'F_PE_NLGLOB13A_FAIL|STEP=',step_index,'|HALF=1|DOMAIN=',merge(1,0,half_fail), &
           '|UNDERLYING=',trim(terminal_reason),'|HALF_DT=',dt,'|PRE_MIN=',minval(state%water_content), &
           '|PRE_MAX=',maxval(state%water_content),'|PRE_TOP_H=',state%pressure_head(1),'|PRE_POND=',state%ponding_depth, &
           '|FINITE=',merge(1,0,all(ieee_is_finite(state%water_content)) .and. &
           all(ieee_is_finite(state%pressure_head)) .and. ieee_is_finite(state%ponding_depth)), &
           '|ROUTE=',trim(route_id),'|CUM_LEDGER_BEFORE=',saved_cumledger
      state=saved_state
"""
if block1 not in src:
    raise SystemExit("NLGLOB13A half1 marker missing")
src=src.replace(block1,repl1,1)

block2="""    if(half_fail .or. .not.eligible)then
      state=saved_state
"""
repl2="""    if(half_fail .or. .not.eligible)then
      write(*,'(*(g0))') 'F_PE_NLGLOB13A_FAIL|STEP=',step_index,'|HALF=2|DOMAIN=',merge(1,0,half_fail), &
           '|UNDERLYING=',trim(terminal_reason),'|HALF_DT=',dt,'|PRE_MIN=',minval(state%water_content), &
           '|PRE_MAX=',maxval(state%water_content),'|PRE_TOP_H=',state%pressure_head(1),'|PRE_POND=',state%ponding_depth, &
           '|FINITE=',merge(1,0,all(ieee_is_finite(state%water_content)) .and. &
           all(ieee_is_finite(state%pressure_head)) .and. ieee_is_finite(state%ponding_depth)), &
           '|ROUTE=',trim(route_id),'|CUM_LEDGER_BEFORE=',saved_cumledger
      state=saved_state
"""
if block2 not in src:
    raise SystemExit("NLGLOB13A half2 marker missing")
src=src.replace(block2,repl2,1)

if src.count("F_PE_NLGLOB13A_FAIL")!=2:
    raise SystemExit("NLGLOB13A expected two failure diagnostics")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13A_MATERIALIZER=PASS")
