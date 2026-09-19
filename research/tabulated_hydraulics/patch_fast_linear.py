#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

start = next(
    i for i, line in enumerate(lines)
    if "subroutine EvalTabulatedFunction" in line
)
end = next(
    i for i, line in enumerate(lines[start + 1 :], start + 1)
    if "subroutine PreProcTabulatedFunction" in line
)
hits = [
    i for i in range(start, end)
    if "if (use_TSPACK) then" in lines[i]
]
if len(hits) != 1:
    raise SystemExit(
        f"expected one forward use_TSPACK branch in EvalTabulatedFunction, found {len(hits)}"
    )

idx = hits[0]
indent = lines[idx][:-len(lines[idx].lstrip())]
body = indent + "   "
body2 = body + "   "

injection = [
    indent + "! TAB-HYD research-only fast linear interpolation in transformed x.",
    indent + "! theta is linear in x; log(K) is linear in x.",
    indent + "f1 = sptab(ind2,node,klo)",
    indent + "f2 = sptab(ind2,node,khi)",
    indent + "delta = (f2-f1)/(x2-x1)",
    indent + "xx = xe_local-x1",
    indent + "if (iWhat <= 2) then",
    body + "ye = f1 + xx*delta",
    body + "if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)",
    indent + "else if (iWhat == 3) then",
    body + "dyedxe = delta",
    body + "if (do_ln_trans) dyedxe = dyedxe/(-xe+1.0d0)",
    indent + "else if (iWhat == 4) then",
    body + "ye = f1 + xx*delta",
    body + "if (do_ln_trans) then",
    body2 + "ye = dexp(ye)",
    body2 + "dyedxe = delta*ye/(-xe+1.0d0)",
    body + "else",
    body2 + "dyedxe = delta",
    body + "end if",
    indent + "end if",
    indent + "return",
    "",
]

lines[idx:idx] = injection
path.write_text("\n".join(lines) + "\n")
print(f"FAST_LINEAR_PATCH_APPLIED line={idx + 1}")
