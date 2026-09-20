#!/usr/bin/env python3
"""Research-only linear K/dKdh evaluator on the proven log-head400 grid.

Theta and C retain TSPACK. Conductivity is stored as ln(K) under the existing
log transform, so K uses linear interpolation in x=-ln(1-h), ln(K). dK/dh is
the analytical derivative of that local linear log-K segment.
"""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_linear_k_eval.py sptabulated.f90")
p=Path(sys.argv[1]); s=p.read_text()

start=s.index("subroutine EvalTabulatedFunction")
end=s.index("subroutine PreProcTabulatedFunction",start)
ev=s[start:end]
needle="""         if (use_TSPACK) then
            x(1:2)   = sptab(ind1,node,klo:khi)"""
insert="""         ! TAB-HYD research candidate: theta/C keep TSPACK, while K and
         ! dK/dh use the local secant in transformed x and ln(K).
         if (iWhat == 2 .or. iWhat == 4) then
            f1 = sptab(ind2,node,klo)
            f2 = sptab(ind2,node,khi)
            delta = (f2-f1)/(x2-x1)
            ye = f1 + (xe_local-x1)*delta
            if (do_ln_trans) then
               ye = dexp(ye)
               if (iWhat == 4) dyedxe = delta*ye/(-xe+1.0d0)
            else
               if (iWhat == 4) dyedxe = delta
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
print(f"LINEAR_K_EVAL_PATCH_APPLIED {p}")
