#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True); ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
old="req%numerical%max_iterations=8; req%numerical%max_backtracking=8"
new="req%numerical%max_iterations=16; req%numerical%max_backtracking=8"
if old not in src:
    raise SystemExit("NLGLOB12B max-iteration marker missing")
src=src.replace(old,new)
Path(args.output).write_text(src)
print("F_PE_NLGLOB12B_MATERIALIZER=PASS")
