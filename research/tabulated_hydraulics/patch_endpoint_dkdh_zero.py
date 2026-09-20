#!/usr/bin/env python3
from pathlib import Path
import sys

path=Path(sys.argv[1])
lines=path.read_text().splitlines()
hits=[i for i,line in enumerate(lines) if "dhconduc = 1.0d+08" in line]
if len(hits)!=1:
    raise SystemExit(f"expected one saturated table sentinel in {path}, found {len(hits)}")
idx=hits[0]
lines[idx]=lines[idx].replace("dhconduc = 1.0d+08","dhconduc = 0.0_real64")
else_idx=next(i for i in range(idx+1,min(idx+8,len(lines))) if lines[i].strip()=="else")
indent=lines[else_idx][:-len(lines[else_idx].lstrip())]
body=indent+"   "
lines[else_idx:else_idx+1]=[
    indent+"else if (theta <= sptab(2,node,1) + 1.0d-9) then",
    body+"dhconduc = 0.0_real64",
    indent+"else",
]
path.write_text("\n".join(lines)+"\n")
print(f"ENDPOINT_DKDH_ZERO_PATCH_APPLIED {path}")
