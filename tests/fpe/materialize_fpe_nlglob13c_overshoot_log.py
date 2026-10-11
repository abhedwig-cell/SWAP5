#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
      domain_fail=.true.
      return
    end if
"""
repl="""    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
      write(*,'(*(g0))') 'F_PE_NLGLOB13C_DOMAIN|STEP=',step_index,'|STEPDT=',stepdt, &
           '|THETA_MIN=',minval(theta_tg),'|THETA_MAX=',maxval(theta_tg),'|TR=',tr,'|TS=',ts, &
           '|NODE_MIN=',minloc(theta_tg,dim=1),'|NODE_MAX=',maxloc(theta_tg,dim=1), &
           '|PRE_MIN=',minval(state%water_content),'|PRE_MAX=',maxval(state%water_content), &
           '|PRE_SIG1=',sum(state%water_content),'|PRE_SIG2=', &
           sum(state%water_content*[(real(i,real64),i=1,numnod)]), &
           '|PRE_STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
           '|PRE_TOP_H=',state%pressure_head(1),'|PRE_POND=',state%ponding_depth,'|ROUTE=',trim(route_id)
      domain_fail=.true.
      return
    end if
"""
if needle not in src:
    raise SystemExit("NLGLOB13C domain-failure marker missing")
src=src.replace(needle,repl,1)
if "F_PE_NLGLOB13C_DOMAIN" not in src:
    raise SystemExit("NLGLOB13C injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13C_MATERIALIZER=PASS")
