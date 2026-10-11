#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

for half in (1,2):
    marker=f"|HALF={half}|QUARTER=2|EIGHTH=1|"
    pos=src.find(marker)
    if pos<0:
        raise SystemExit(f"NLGLOB13D quarter2 marker missing for half {half}")
    ifpos=src.rfind("      if(qfail)then",0,pos)
    if ifpos<0:
        raise SystemExit(f"NLGLOB13D quarter2 qfail block missing for half {half}")
    guard=f"""      if(qfail)then
        write(*,'(*(g0))') 'F_PE_NLGLOB13D_Q2_FAILCLOSED|STEP=',step_index,'|HALF={half}|QUARTER=2|DT=',dt
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_QUARTER2_FAILED'; transition_step=step_index; return
      end if
"""
    src=src[:ifpos]+guard+src[ifpos:]

if src.count("F_PE_NLGLOB13D_Q2_FAILCLOSED")!=2:
    raise SystemExit("NLGLOB13D expected two quarter2 failclosed guards")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13D_Q2_FAILCLOSED_MATERIALIZER=PASS")
