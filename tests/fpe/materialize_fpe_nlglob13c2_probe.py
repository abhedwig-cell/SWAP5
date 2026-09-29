#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""    theta_tg=state%water_content+0.5_real64*stepdt*(theta_dot_n+theta_dot_p)
    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
"""
repl="""    theta_tg=state%water_content+0.5_real64*stepdt*(theta_dot_n+theta_dot_p)
    write(*,'(*(g0))') 'F_PE_NLGLOB13C2_PROBE|STEP=',step_index,'|STEPDT=',stepdt, &
         '|THETA_MIN=',minval(theta_tg),'|THETA_MAX=',maxval(theta_tg),'|TR=',tr,'|TS=',ts, &
         '|NODE_MIN=',minloc(theta_tg,dim=1),'|NODE_MAX=',maxloc(theta_tg,dim=1), &
         '|ADMISSIBLE=',merge(1,0,all(theta_tg>tr) .and. all(theta_tg<ts)), &
         '|PRE_MIN=',minval(state%water_content),'|PRE_MAX=',maxval(state%water_content), &
         '|PRE_STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth,'|ROUTE=',trim(route_id)
    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
"""
if needle not in src:
    raise SystemExit("NLGLOB13C2 accepted-state marker missing")
src=src.replace(needle,repl,1)
if "F_PE_NLGLOB13C2_PROBE" not in src:
    raise SystemExit("NLGLOB13C2 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13C2_MATERIALIZER=PASS")
