#!/usr/bin/env python3
"""Research-only cheap Hermite evaluation using TSPACK-precomputed knot slopes.

Modes:
- theta: theta and C use cubic Hermite with TSPACK knot slopes; K stays TSPACK.
- all:   theta/C and K/dKdh all use cubic Hermite with TSPACK knot slopes.

TSPACK preprocessing is unchanged in both modes. Only interval evaluation is
simplified by ignoring the TSPACK tension sigma while retaining its knot slopes.
"""
from pathlib import Path
import sys
if len(sys.argv)!=3 or sys.argv[2] not in ("theta","all"):
    raise SystemExit("usage: patch_hermite_tspack_slopes.py sptabulated.f90 {theta|all}")
p=Path(sys.argv[1]); mode=sys.argv[2]; s=p.read_text()

start=s.index("subroutine EvalTabulatedFunction")
end=s.index("subroutine PreProcTabulatedFunction",start)
ev=s[start:end]
needle="""         if (use_TSPACK) then
            x(1:2)   = sptab(ind1,node,klo:khi)"""
cond="(iWhat == 1 .or. iWhat == 3)" if mode=="theta" else "(iWhat >= 1 .and. iWhat <= 4)"
insert=f"""         ! TAB-HYD research candidate: use the TSPACK-precomputed endpoint
         ! slopes in a cheap local cubic Hermite evaluator; preprocessing and
         ! knot geometry remain unchanged. mode={mode}
         if {cond} then
            f1 = sptab(ind2,node,klo)
            f2 = sptab(ind2,node,khi)
            d1 = sptab(ind3,node,klo)
            d2 = sptab(ind3,node,khi)
            h = x2 - x1
            delta = (f2-f1)/h
            del1 = (d1-delta)/h
            del2 = (d2-delta)/h
            c2 = -(del1+del1+del2)
            c2t2 = c2+c2
            c3 = (del1+del2)/h
            c3t3 = c3+c3+c3
            xx = xe_local-x1
            ye = f1 + xx*(d1 + xx*(c2 + xx*c3))
            dyedxe = d1 + xx*(c2t2 + xx*c3t3)

            if (iWhat == 3 .and. do_ln_trans) then
               dyedxe = dyedxe/(-xe+1.0d0)
            else if (iWhat == 2 .and. do_ln_trans) then
               ye = dexp(ye)
            else if (iWhat == 4 .and. do_ln_trans) then
               ye = dexp(ye)
               dyedxe = dyedxe*ye/(-xe+1.0d0)
            end if
            return
         end if

         if (use_TSPACK) then
            x(1:2)   = sptab(ind1,node,klo:khi)"""
if ev.count(needle)!=1:
    raise SystemExit(f"Eval insertion point mismatch: {ev.count(needle)}")
ev=ev.replace(needle,insert,1)
s=s[:start]+ev+s[end:]
p.write_text(s)
print(f"HERMITE_TSPACK_SLOPES_PATCH_APPLIED mode={mode} {p}")
