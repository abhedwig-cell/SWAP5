#!/usr/bin/env python3
"""Research-only split of generated table K at its constant-Ksat plateau."""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_table_ksat_plateau_split.py soilhydraulicsutils.f90 readswap.f90")

hyd = Path(sys.argv[1])
reader = Path(sys.argv[2])
s = hyd.read_text()

old_d = """      else if (swsophy == 1) then
         if (theta >= sptab(2,node,numtab(node)) - 1.0d-9) then
            dhconduc = 1.0d+08
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 3, 5, node, sptab, ientrytab, head, dummy, dhconduc, 4)
         end if
      end if"""
new_d = """      else if (swsophy == 1) then
         ! TAB-HYD research candidate: final K knot is the constant-Ksat branch. The generated penultimate head is the exact residual-branch threshold.
         if (head > 1.0_real64 - dexp(-sptab(1,node,numtab(node)-1))) then
            dhconduc = 0.0_real64
         else if (theta <= sptab(2,node,1) + 1.0d-9) then
            dhconduc = 0.0_real64
         else
            call EvalTabulatedFunction(0, numtab(node)-1, 1, 3, 5, node, sptab, ientrytab, head, dummy, dhconduc, 4)
         end if
      end if"""
if s.count(old_d) != 1:
    raise SystemExit(f"expected one original table dhconduc block, found {s.count(old_d)}")
s = s.replace(old_d, new_d, 1)

old_k = """      else if (swsophy == 1) then
         if (theta >= sptab(2,node,numtab(node)) - 1.0d-9) then
            hconduc = sptab(3,node,numtab(node))
            if (do_ln_trans) hconduc = dexp(hconduc)
         else if (theta <= sptab(2,node,1) + 1.0d-9) then
            hconduc = sptab(3,node,1)            
            if (do_ln_trans) hconduc = dexp(hconduc)
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 3, 5, node, sptab, ientrytab, head, hconduc, dummy, 2)
         end if
      end if"""
new_k = """      else if (swsophy == 1) then
         ! TAB-HYD research candidate: split the finite Ksat jump explicitly at the generated head threshold.
         if (head > 1.0_real64 - dexp(-sptab(1,node,numtab(node)-1))) then
            hconduc = sptab(3,node,numtab(node))
            if (do_ln_trans) hconduc = dexp(hconduc)
         else if (theta <= sptab(2,node,1) + 1.0d-9) then
            hconduc = sptab(3,node,1)
            if (do_ln_trans) hconduc = dexp(hconduc)
         else
            call EvalTabulatedFunction(0, numtab(node)-1, 1, 3, 5, node, sptab, ientrytab, head, hconduc, dummy, 2)
         end if
      end if"""
if s.count(old_k) != 1:
    raise SystemExit(f"expected one original table hconduc block, found {s.count(old_k)}")
s = s.replace(old_k, new_k, 1)
hyd.write_text(s)

r = reader.read_text()
old_p = """            call PreProcTabulatedFunction(2,                            &
     &                      numtablay(lay),headtab,conductab,dydx,sigma)
            do i = 1,numtablay(lay)
              sptablay(5,lay,i) = dydx(i)
              sptablay(7,lay,i) = sigma(i)   !## MH: new
            enddo"""
new_p = """            ! TAB-HYD research candidate: preprocess K only on the
            ! continuous sub-threshold branch; final h=0 K is the plateau.
            call PreProcTabulatedFunction(2,                            &
     &                      numtablay(lay)-1,headtab,conductab,dydx,sigma)
            do i = 1,numtablay(lay)-1
              sptablay(5,lay,i) = dydx(i)
              sptablay(7,lay,i) = sigma(i)   !## MH: new
            enddo"""
if r.count(old_p) != 1:
    raise SystemExit(f"expected one conductivity preprocessing block, found {r.count(old_p)}")
r = r.replace(old_p, new_p, 1)
reader.write_text(r)

print(f"TABLE_KSAT_PLATEAU_SPLIT_PATCH_APPLIED {hyd} {reader}")
