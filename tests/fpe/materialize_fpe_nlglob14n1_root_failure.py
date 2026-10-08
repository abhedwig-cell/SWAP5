#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old="""      if(.not.eligible)then
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        eligible=.false.
        terminal_reason='SATURATION_ROOT_TRIAL_OTHER_FAILED'
"""
new="""      if(.not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14N1_ROOT_FAIL|STEP=',step_index,'|ITER=',ibis, &
             '|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|PHI_MID=',phi_mid,'|TRIAL_DT=',trial_dt, &
             '|UNDERLYING=',trim(terminal_reason),'|ORIGIN_ROUTE=',last_origin_route, &
             '|PRED_ROUTE=',last_pred_route,'|ENDPOINT_ROUTE=',last_endpoint_route, &
             '|ACCEPT_ROUTE=',last_accept_route,'|SOLVER_STATUS=',last_solver_status
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        eligible=.false.
        terminal_reason='SATURATION_ROOT_TRIAL_OTHER_FAILED'
"""
if old not in src:
    raise SystemExit("NLGLOB14N1 root failure marker missing")
src=src.replace(old,new,1)
if "F_PE_NLGLOB14N1_ROOT_FAIL" not in src:
    raise SystemExit("NLGLOB14N1 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14N1_MATERIALIZER=PASS")
