#!/usr/bin/env python3
from pathlib import Path
import sys

p=Path(sys.argv[1])
lines=p.read_text().splitlines()
if not any(line.strip().startswith("CRITDEVMASBAL") for line in lines):
    out=[]
    inserted=False
    for line in lines:
        out.append(line)
        if line.strip().startswith("SWHEADER"):
            out.append("  CRITDEVMASBAL = 1.0E-6")
            inserted=True
    if not inserted:
        raise SystemExit("SWHEADER not found")
    p.write_text("\n".join(out)+"\n")
