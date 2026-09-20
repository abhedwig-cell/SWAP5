#!/usr/bin/env python3
"""Direct two-segment arithmetic interval lookup for piecewise-x TAB-HYD tables."""
from pathlib import Path
import sys

if len(sys.argv)!=2:
    raise SystemExit("usage: patch_direct_piecewise_x_tspack.py sptabulated.f90")

path=Path(sys.argv[1])
lines=path.read_text().splitlines()
start=next(i for i,l in enumerate(lines) if "subroutine EvalTabulatedFunction" in l)
end=next(i for i,l in enumerate(lines[start+1:],start+1) if "subroutine PreProcTabulatedFunction" in l)

decl=next(i for i in range(start,end) if lines[i].lstrip().startswith("integer k, klo, khi"))
lines[decl]=lines[decl].replace("integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat",
                               "integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, ibreak, kend, nwet")

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
interp=[i for i in range(fidx,end) if "if (use_TSPACK) then" in lines[i]]
if len(interp)!=1:
    raise SystemExit(f"expected one TSPACK branch, found {len(interp)}")
iidx=interp[0]

base=lines[fidx][:-len(lines[fidx].lstrip())]
i1=base+"   "
i2=i1+"   "
block=[
    i1+"! TAB-HYD research-only direct lookup for the two-segment x grid.",
    i1+"if (xe .ge. -1.0d-9) stop 'Invalid call of Function EvalTabulatedFunction'",
    i1+"xe_local = -(dlog(-xe+1.0d0))",
    i1+"nwet = 128",
    i1+"if (ind2 == 3) then",
    i2+"kend = n",
    i2+"ibreak = n - nwet",
    i1+"else",
    i2+"kend = n - 1",
    i2+"ibreak = n - 1 - nwet",
    i2+"if (xe_local .ge. sptab(ind1,node,kend)) then",
    i2+"   klo = kend",
    i2+"   khi = kend + 1",
    i2+"   x1 = sptab(ind1,node,klo)",
    i2+"   x2 = sptab(ind1,node,khi)",
    i2+"   goto 1901",
    i2+"end if",
    i1+"end if",
    i1+"if (ibreak .lt. 2 .or. kend .le. ibreak) stop 'Invalid TAB-HYD piecewise grid metadata'",
    i1+"if (xe_local .lt. sptab(ind1,node,ibreak)) then",
    i2+"h = (sptab(ind1,node,ibreak)-sptab(ind1,node,1))/dble(ibreak-1)",
    i2+"klo = int((xe_local-sptab(ind1,node,1))/h)+1",
    i2+"klo = max(1,min(ibreak-1,klo))",
    i1+"else",
    i2+"h = (sptab(ind1,node,kend)-sptab(ind1,node,ibreak))/dble(kend-ibreak)",
    i2+"klo = ibreak + int((xe_local-sptab(ind1,node,ibreak))/h)",
    i2+"klo = max(ibreak,min(kend-1,klo))",
    i1+"end if",
    i1+"khi = klo + 1",
    i1+"x1 = sptab(ind1,node,klo)",
    i1+"x2 = sptab(ind1,node,khi)",
    i1+"goto 1901",
    ""
]
lines[fidx+1:fidx+1]=block
iidx += len(block)
lines[iidx:iidx]=[base+"1901 continue"]
path.write_text("\n".join(lines)+"\n")
print(f"DIRECT_PIECEWISE_X_TSPACK_PATCH_APPLIED forward_line={fidx+1}")
