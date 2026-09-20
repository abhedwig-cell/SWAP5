#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

start = next(i for i,line in enumerate(lines) if "subroutine EvalTabulatedFunction" in line)
end = next(i for i,line in enumerate(lines[start+1:],start+1) if "subroutine PreProcTabulatedFunction" in line)

hits=[
    i for i in range(start,end)
    if "inverse" in lines[i].lower()
    and ".eq." in lines[i].lower()
    and "0" in lines[i]
    and "then" in lines[i].lower()
    and lines[i].lstrip().lower().startswith("if")
]
if len(hits) != 1:
    raise SystemExit(f"expected one forward inverse=0 branch, found {len(hits)}")

idx=hits[0]+1
base=lines[hits[0]][:-len(lines[hits[0]].lstrip())]
i1=base+"   "
i2=i1+"   "
i3=i2+"   "

block=[
    i1+"! TAB-HYD research-only direct-index cubic-Hermite route.",
    i1+"! Negative knots 1..n-1 are uniform in x=-log(1-h); n is h=0.",
    i1+"! Uses the already preprocessed endpoint slopes stored in sptab(ind3).",
    i1+"if (xe .ge. -1.0d-9) stop 'Invalid call of Function EvalTabulatedFunction'",
    i1+"xe_local = -(dlog(-xe+1.0d0))",
    i1+"if (xe_local .ge. sptab(ind1,node,n-1)) then",
    i2+"klo = n-1",
    i2+"khi = n",
    i1+"else",
    i2+"h = (sptab(ind1,node,n-1)-sptab(ind1,node,1))/dble(n-2)",
    i2+"klo = int((xe_local-sptab(ind1,node,1))/h) + 1",
    i2+"klo = max(1,min(n-2,klo))",
    i2+"khi = klo+1",
    i1+"end if",
    i1+"x1 = sptab(ind1,node,klo)",
    i1+"x2 = sptab(ind1,node,khi)",
    i1+"f1 = sptab(ind2,node,klo)",
    i1+"f2 = sptab(ind2,node,khi)",
    i1+"d1 = sptab(ind3,node,klo)",
    i1+"d2 = sptab(ind3,node,khi)",
    i1+"h = x2-x1",
    i1+"delta = (f2-f1)/h",
    i1+"del1 = (d1-delta)/h",
    i1+"del2 = (d2-delta)/h",
    i1+"c2 = -(del1+del1+del2)",
    i1+"c2t2 = c2+c2",
    i1+"c3 = (del1+del2)/h",
    i1+"c3t3 = c3+c3+c3",
    i1+"xx = xe_local-x1",
    i1+"if (iWhat <= 2) then",
    i2+"ye = f1 + xx*(d1 + xx*(c2 + xx*c3))",
    i2+"if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)",
    i1+"else",
    i2+"dyedxe = d1 + xx*(c2t2 + xx*c3t3)",
    i2+"if (do_ln_trans .and. iWhat == 3) dyedxe = dyedxe/(-xe+1.0d0)",
    i2+"if (do_ln_trans .and. iWhat == 4) then",
    i3+"ye = f1 + xx*(d1 + xx*(c2 + xx*c3))",
    i3+"ye = dexp(ye)",
    i3+"dyedxe = dyedxe*ye/(-xe+1.0d0)",
    i2+"end if",
    i1+"end if",
    i1+"return",
    "",
]
lines[idx:idx]=block
path.write_text("\n".join(lines)+"\n")
print(f"DIRECT_UNIFORM_CUBIC_PATCH_APPLIED after_line={hits[0]+1}")
