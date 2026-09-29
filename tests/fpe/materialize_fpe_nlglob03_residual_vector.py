#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="""              '|RES_INF=',maxval(dabs(fsi_ws%residual(1:NN))), &
              '|RES_SUM=',dabs(sum(fsi_ws%residual(1:NN))), &
              '|TOL_CP=',CritDevBalCp,'|TOL_TOT=',CritDevBalTot, &
"""
if marker not in src:
    raise SystemExit("NLGLOB03 floor-log marker missing")

needle="""              '|BOTTOM_DH=',dabs(fsi_ws%delta_head(NN)),'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if
"""
repl="""              '|BOTTOM_DH=',dabs(fsi_ws%delta_head(NN)),'|ROUTE=',trim(provider_dynamic_top_result%route)
         write(*,'(*(g0))') 'F_PE_NLGLOB03_RES|ITER=',state%numbit,'|NN=',NN,'|R=', &
              (fsi_ws%residual(i),i=1,NN)
      end if
"""
if needle not in src:
    raise SystemExit("NLGLOB03 vector injection marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB03_RES" not in src:
    raise SystemExit("NLGLOB03 injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB03_MATERIALIZER=PASS")
