#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser(); ap.add_argument("--source",required=True); ap.add_argument("--output",required=True)
args=ap.parse_args(); src=Path(args.source).read_text()
needle="""    if(any(theta_tilde<=tr) .or. any(theta_tilde>=ts))then
      terminal_reason='PREDICTED_RETENTION_DOMAIN_FAILED'
"""
repl="""    if(any(theta_tilde<=tr) .or. any(theta_tilde>=ts))then
      write(*,'(*(g0))') 'F_PE_NLGLOB10_B|STEP=',step_index,'|PRED_MIN=',minval(theta_tilde), &
           '|PRED_MAX=',maxval(theta_tilde),'|TR=',tr,'|TS=',ts,'|ACCEPT_MIN=',minval(state%water_content), &
           '|ACCEPT_MAX=',maxval(state%water_content),'|ROUTE=',trim(route_id),'|DT=',dt
      terminal_reason='PREDICTED_RETENTION_DOMAIN_FAILED'
"""
if needle not in src: raise SystemExit("NLGLOB10 B marker missing")
src=src.replace(needle,repl,1)
Path(args.output).write_text(src)
print("F_PE_NLGLOB10_B_MATERIALIZER=PASS")
