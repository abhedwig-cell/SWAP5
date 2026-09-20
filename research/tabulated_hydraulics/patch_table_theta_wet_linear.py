#!/usr/bin/env python3
"""Research-only preservation of the default-MvG wet theta/C linear branch.

This is a diagnostic candidate for generated acceleration tables. It leaves
interior tabulated theta/C unchanged, but for -0.01 < h < 0 reconstructs the
same linear wet-end branch used by the analytical default-MvG residual. The
theta value at h=-0.01 is obtained from the existing table evaluator so the
candidate does not require MvG parameters at evaluation time.
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_table_theta_wet_linear.py soilhydraulicsutils.f90")

path=Path(sys.argv[1])
s=path.read_text()

old_w = """      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .and. head < 0.0_real64) dum = -dlog(-head + 1.0_real64)
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else if (dum < sptab(1,node,1)) then
            watcon = sptab(2,node,1)
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
      end if"""
new_w = """      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .and. head < 0.0_real64) dum = -dlog(-head + 1.0_real64)
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else if (head > h_crit) then
            ! TAB-HYD research candidate: preserve the analytical default-MvG
            ! linear wet theta branch instead of accepting the spline endpoint slope.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, help, moiscap, 1)
            watcon = help + (sptab(2,node,numtab(node)) - help) / (-h_crit) * (head - h_crit)
            watcon = min(watcon, sptab(2,node,numtab(node)))
         else if (dum < sptab(1,node,1)) then
            watcon = sptab(2,node,1)
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
      end if"""
if s.count(old_w) != 1:
    raise SystemExit(f"expected one watcon table branch, found {s.count(old_w)}")
s=s.replace(old_w,new_w,1)

old_c = """      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .and. head < 0.0_real64) dum = -dlog(-head + 1.0_real64)
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (dum < sptab(1,node,1)) then
            moiscap = 0.0_real64
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, dummy, moiscap, 3)
         end if
      end if"""
new_c = """      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .and. head < 0.0_real64) dum = -dlog(-head + 1.0_real64)
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (head > h_crit) then
            ! TAB-HYD research candidate: derivative of the same explicit
            ! linear wet theta branch used by the table watcon candidate.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, term1, dummy, 1)
            moiscap = (sptab(2,node,numtab(node)) - term1) / (-h_crit)
            if (head > -1.0_real64 .and. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7
         else if (dum < sptab(1,node,1)) then
            moiscap = 0.0_real64
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, dummy, moiscap, 3)
         end if
      end if"""
if s.count(old_c) != 1:
    raise SystemExit(f"expected one moiscap table branch, found {s.count(old_c)}")
s=s.replace(old_c,new_c,1)

path.write_text(s)
print(f"TABLE_THETA_WET_LINEAR_PATCH_APPLIED {path}")
