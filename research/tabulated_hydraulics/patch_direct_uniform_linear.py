#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

start = next(i for i, line in enumerate(lines) if "subroutine EvalTabulatedFunction" in line)
end = next(
    i for i, line in enumerate(lines[start + 1 :], start + 1)
    if "subroutine PreProcTabulatedFunction" in line
)
hits = [
    i for i in range(start, end)
    if "if(inverse .eq. 0)then" in line.replace(" ", "")
]
if not hits:
    hits = [
        i for i in range(start, end)
        if "if(inverse.eq.0)then" in lines[i].replace(" ", "")
    ]
if len(hits) != 1:
    # robust fallback to semantic tokens, because historical formatting differs
    hits = [
        i for i in range(start, end)
        if "inverse" in lines[i].lower()
        and ".eq." in lines[i].lower()
        and "0" in lines[i]
        and "then" in lines[i].lower()
        and lines[i].lstrip().lower().startswith("if")
    ]
if len(hits) != 1:
    raise SystemExit(f"expected one forward inverse=0 branch, found {len(hits)}")

idx = hits[0] + 1
base = lines[hits[0]][:-len(lines[hits[0]].lstrip())]
indent = base + "   "
i2 = indent + "   "
i3 = i2 + "   "

block = [
    indent + "! TAB-HYD research-only direct-index uniform-x table route.",
    indent + "! Contract: entries 1..n-1 are uniform in x=-log(1-h); entry n is h=0.",
    indent + "if (xe .ge. -1.0d-9) stop 'Invalid call of Function EvalTabulatedFunction'",
    indent + "xe_local = -(dlog(-xe+1.0d0))",
    indent + "if (xe_local .ge. sptab(ind1,node,n-1)) then",
    i2 + "klo = n-1",
    i2 + "khi = n",
    indent + "else",
    i2 + "h = (sptab(ind1,node,n-1)-sptab(ind1,node,1))/dble(n-2)",
    i2 + "klo = int((xe_local-sptab(ind1,node,1))/h) + 1",
    i2 + "klo = max(1,min(n-2,klo))",
    i2 + "khi = klo+1",
    indent + "end if",
    indent + "x1 = sptab(ind1,node,klo)",
    indent + "x2 = sptab(ind1,node,khi)",
    indent + "f1 = sptab(ind2,node,klo)",
    indent + "f2 = sptab(ind2,node,khi)",
    indent + "delta = (f2-f1)/(x2-x1)",
    indent + "xx = xe_local-x1",
    indent + "if (iWhat <= 2) then",
    i2 + "ye = f1 + xx*delta",
    i2 + "if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)",
    indent + "else if (iWhat == 3) then",
    i2 + "dyedxe = delta",
    i2 + "if (do_ln_trans) dyedxe = dyedxe/(-xe+1.0d0)",
    indent + "else if (iWhat == 4) then",
    i2 + "ye = f1 + xx*delta",
    i2 + "if (do_ln_trans) then",
    i3 + "ye = dexp(ye)",
    i3 + "dyedxe = delta*ye/(-xe+1.0d0)",
    i2 + "else",
    i3 + "dyedxe = delta",
    i2 + "end if",
    indent + "end if",
    indent + "return",
    "",
]
lines[idx:idx] = block
path.write_text("\n".join(lines) + "\n")
print(f"DIRECT_UNIFORM_LINEAR_PATCH_APPLIED after_line={hits[0]+1}")
