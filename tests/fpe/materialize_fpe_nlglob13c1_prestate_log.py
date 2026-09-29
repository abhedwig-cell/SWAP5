#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="""    integer::saved_transition

    saved_state=state
"""
insert="""    integer::saved_transition,nl13c1_i

    saved_state=state
"""
if marker not in src:
    raise SystemExit("NLGLOB13C1 declaration marker missing")
src=src.replace(marker,insert,1)

needle="""      call advance_tg_core(step_index,dt,qfail)
"""
parts=src.split(needle)
if len(parts)!=5:
    raise SystemExit(f"NLGLOB13C1 expected exactly four quarter calls, found {len(parts)-1}")

def logblock(half,quarter):
    return f"""      do nl13c1_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB13C1_STATE|STEP=',step_index,'|HALF={half}|QUARTER={quarter}|NODE=',nl13c1_i, &
             '|PTHETA=',half_state%water_content(nl13c1_i),'|CTHETA=',state%water_content(nl13c1_i), &
             '|PH=',half_state%pressure_head(nl13c1_i),'|CH=',state%pressure_head(nl13c1_i), &
             '|PPOND=',half_state%ponding_depth,'|CPOND=',state%ponding_depth,'|DZ=',p%dz(nl13c1_i), &
             '|ROUTE=',trim(route_id)
      end do
      call advance_tg_core(step_index,dt,qfail)
"""

labels=((1,1),(1,2),(2,1),(2,2))
out=parts[0]
for i,(half,quarter) in enumerate(labels):
    out+=logblock(half,quarter)+parts[i+1]
src=out

if src.count("F_PE_NLGLOB13C1_STATE") != 4:
    raise SystemExit("NLGLOB13C1 expected four state log sites")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13C1_MATERIALIZER=PASS")
