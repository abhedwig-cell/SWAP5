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
insert="""    integer::saved_transition,nl13c2_i

    saved_state=state
"""
if marker not in src:
    raise SystemExit("NLGLOB13C2 identity declaration marker missing")
src=src.replace(marker,insert,1)

needle="""      call advance_tg_core(step_index,dt,qfail)
"""
parts=src.split(needle)
if len(parts)!=5:
    raise SystemExit(f"NLGLOB13C2 expected four quarter calls, found {len(parts)-1}")

labels=((1,1),(1,2),(2,1),(2,2))
out=parts[0]
for idx,(half,quarter) in enumerate(labels):
    log=f"""      do nl13c2_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB13C2_STATE|STEP=',step_index,'|HALF={half}|QUARTER={quarter}|NODE=',nl13c2_i, &
             '|PTHETA=',half_state%water_content(nl13c2_i),'|CTHETA=',state%water_content(nl13c2_i), &
             '|PH=',half_state%pressure_head(nl13c2_i),'|CH=',state%pressure_head(nl13c2_i), &
             '|PPOND=',half_state%ponding_depth,'|CPOND=',state%ponding_depth,'|DZ=',p%dz(nl13c2_i), &
             '|ROUTE=',trim(route_id)
      end do
"""
    out+=log+needle+parts[idx+1]
src=out

if src.count("F_PE_NLGLOB13C2_STATE")!=4:
    raise SystemExit("NLGLOB13C2 expected four distinct state log sites")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13C2_IDENTITY_MATERIALIZER=PASS")
