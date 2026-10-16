#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old="""              '|NODE_DTHETA=',nlglob01_node_dtheta,'|NODE_RES=',nlglob01_node_res, &
              '|TOP_DH=',dabs(fsi_ws%delta_head(1)), &
"""
new="""              '|NODE_DTHETA=',nlglob01_node_dtheta,'|NODE_RES=',nlglob01_node_res, &
              '|RES_INF=',maxval(dabs(fsi_ws%residual(1:NN))), &
              '|RES_SUM=',dabs(sum(fsi_ws%residual(1:NN))), &
              '|TOL_CP=',CritDevBalCp,'|TOL_TOT=',CritDevBalTot, &
              '|TOP_DH=',dabs(fsi_ws%delta_head(1)), &
"""
if old not in src:
    raise SystemExit("NLGLOB02 scaling-log marker missing")
src=src.replace(old,new,1)
if "|RES_INF=" not in src or "|TOL_TOT=" not in src:
    raise SystemExit("NLGLOB02 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB02_MATERIALIZER=PASS")
