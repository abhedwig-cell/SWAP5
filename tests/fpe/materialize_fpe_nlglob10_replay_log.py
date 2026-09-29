#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser(); ap.add_argument("--source",required=True); ap.add_argument("--output",required=True)
args=ap.parse_args(); src=Path(args.source).read_text()
needle="""      if (nl09_s0 .and. flnonconv) then
"""
repl="""      write(*,'(*(g0))') 'F_PE_NLGLOB10_A|ITER=',state%numbit,'|RBAL=',nl09_rbal, &
           '|RSTORAGE=',nl09_rstorage,'|RHEAD=',nl09_rhead,'|POND_APP=',merge(1,0,nl09_pond_app), &
           '|RPOND=',nl09_rpond,'|HIST=',nl09_hist,'|DINF1=',nl09_dinf1,'|DINF2=',nl09_dinf2, &
           '|DS1=',nl09_ds1,'|DS2=',nl09_ds2,'|GUARD=',merge(1,0,nl09_guard), &
           '|S0=',merge(1,0,nl09_s0),'|ROUTE=',trim(provider_dynamic_top_result%route), &
           '|R0=',trim(nl09_route0),'|R1=',trim(nl09_route1)
      if (nl09_s0 .and. flnonconv) then
"""
if needle not in src: raise SystemExit("NLGLOB10 A marker missing")
src=src.replace(needle,repl,1)
Path(args.output).write_text(src)
print("F_PE_NLGLOB10_A_MATERIALIZER=PASS")
