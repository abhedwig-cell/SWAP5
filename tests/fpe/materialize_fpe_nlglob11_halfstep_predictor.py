#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True); ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
patterns=[
("theta_tilde=state%water_content+dt*theta_dot_n","theta_tilde=state%water_content+0.5_real64*dt*theta_dot_n"),
("theta_tilde = state%water_content + dt*theta_dot_n","theta_tilde = state%water_content + 0.5_real64*dt*theta_dot_n"),
]
changed=0
for a,b in patterns:
    if a in src:
        src=src.replace(a,b)
        changed+=1
if changed==0:
    raise SystemExit("NLGLOB11 predictor assignment not found")
Path(args.output).write_text(src)
print("F_PE_NLGLOB11_HALFSTEP_MATERIALIZER=PASS")
