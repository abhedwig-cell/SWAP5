#!/usr/bin/env python3
from pathlib import Path
import sys

path=Path(sys.argv[1])
lines=path.read_text().splitlines()

start=next(i for i,l in enumerate(lines) if "subroutine EvalTabulatedFunction" in l)
end=next(i for i,l in enumerate(lines[start+1:],start+1) if "subroutine PreProcTabulatedFunction" in l)

forward=[
    i for i in range(start,end)
    if "inverse" in lines[i].lower()
    and ".eq." in lines[i].lower()
    and "0" in lines[i]
    and "then" in lines[i].lower()
    and lines[i].lstrip().lower().startswith("if")
]
if len(forward)!=1:
    raise SystemExit(f"expected one forward branch, found {len(forward)}")
fidx=forward[0]
interp=[
    i for i in range(fidx,end)
    if "if (use_TSPACK) then" in lines[i]
]
if len(interp)!=1:
    raise SystemExit(f"expected one TSPACK evaluation branch, found {len(interp)}")
iidx=interp[0]

base=lines[fidx][:-len(lines[fidx].lstrip())]
i1=base+"   "
i2=i1+"   "

block=[
    i1+"! TAB-HYD research-only uniform-x direct interval lookup.",
    i1+"! Keep the existing TSPACK interpolation unchanged after interval selection.",
    i1+"if (xe .ge. -1.0d-9) stop 'Invalid call of Function EvalTabulatedFunction'",
    i1+"xe_local = -(dlog(-xe+1.0d0))",
    i1+"if (xe_local .ge. sptab(ind1,node,n-1)) then",
    i2+"klo = n-1",
    i2+"khi = n",
    i1+"else",
    i2+"h = (sptab(ind1,node,n-1)-sptab(ind1,node,1))/dble(n-2)",
    i2+"klo = int((xe_local-sptab(ind1,node,1))/h)+1",
    i2+"klo = max(1,min(n-2,klo))",
    i2+"khi = klo+1",
    i1+"end if",
    i1+"x1 = sptab(ind1,node,klo)",
    i1+"x2 = sptab(ind1,node,khi)",
    i1+"goto 1901",
    "",
]
lines[fidx+1:fidx+1]=block
# interp index shifts by insertion length
iidx += len(block)
lines[iidx:iidx]=[base+"1901 continue"]
path.write_text("\n".join(lines)+"\n")
print(f"DIRECT_UNIFORM_TSPACK_LOOKUP_PATCH_APPLIED forward_line={fidx+1}")
