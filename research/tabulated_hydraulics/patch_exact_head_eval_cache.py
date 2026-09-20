#!/usr/bin/env python3
"""Research-only exact-head cache for the direct x-map table evaluator.

This patch is applied after patch_piecewise_xmap_lookup.py.

It makes two changes without changing interpolation mathematics:
1. EvalTabulatedFunction caches transformed x and the resolved interval for the
   last exact pressure head per node/function family.
2. watcon/moiscap stop computing a duplicate log transform solely for the dry
   endpoint test. The evaluator now owns that endpoint test and returns the
   same endpoint values.

No tolerance is used: cache reuse requires exact floating-point equality.
"""
from pathlib import Path
import sys
if len(sys.argv)!=3:
    raise SystemExit("usage: patch_exact_head_eval_cache.py sptabulated.f90 soilhydraulicsutils.f90")

tab=Path(sys.argv[1]); util=Path(sys.argv[2])
s=tab.read_text()

old_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, ndry, nwet, ntotal"
new_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, ndry, nwet, ntotal, family"
if s.count(old_int)!=1:
    raise SystemExit(f"integer declaration mismatch: {s.count(old_int)}")
s=s.replace(old_int,new_int,1)

old_decl="integer ientrytab(macp,0:matabentries), node    
      ! SAVE removed - all local variables are temporary computation values"
new_decl="""integer ientrytab(macp,0:matabentries), node
      real(8), save :: cache_head(macp) = 1.0d300
      real(8), save :: cache_x(macp) = 0.0d0
      real(8), save :: cache_interval_head(2,macp) = 1.0d300
      integer, save :: cache_klo(2,macp) = 0
      ! Research-only exact-key cache. No tolerance or approximate reuse."""
if s.count(old_decl)!=1:
    raise SystemExit(f"cache declaration anchor mismatch: {s.count(old_decl)}")
s=s.replace(old_decl,new_decl,1)

old_block="""         if (do_ln_trans) then
            xe_local = -(dlog(-xe+1.0d0))
         else
            xe_local = xe
         end if

         ! TAB-HYD research candidate: preserve the proven log-head400 knots
         ! and accelerate only interval location.  The map is shared across
         ! theta/C and K/dKdh on rows 1..N-1.
         ntotal = ientrytab(node,0)
         tab_xend = sptab(ind1,node,ntotal-1)

         ! Theta alone owns the final wet interval to h=0.
         if (ind2 /= 3 .and. xe_local >= tab_xend) then
            klo = ntotal-1
            khi = ntotal
         else
            ndry = 10000
            nwet = matabentries-1-ndry
            tab_xsplit = -2.397895272798370544d0
            tab_invdry = sptab(5,node,ntotal)
            tab_invwet = sptab(7,node,ntotal)

            if (xe_local < tab_xsplit) then
               k = 1 + int((xe_local-sptab(ind1,node,1))*tab_invdry)
               k = max(1,min(ndry,k))
            else
               k = ndry + 1 + int((xe_local-tab_xsplit)*tab_invwet)
               k = max(ndry+1,min(matabentries-1,k))
            end if
            klo = ientrytab(node,k)

            ! A bin can straddle one knot. Correct locally without another
            ! transcendental function or global search.
            do while (klo > 1 .and. xe_local < sptab(ind1,node,klo))
               klo = klo - 1
            end do
            do while (klo < n-1 .and. xe_local >= sptab(ind1,node,klo+1))
               klo = klo + 1
            end do
            khi = klo + 1
         end if

         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)
"""
new_block="""         ! Exact-head transformed-coordinate cache.
         if (xe == cache_head(node)) then
            xe_local = cache_x(node)
         else
            if (do_ln_trans) then
               xe_local = -(dlog(-xe+1.0d0))
            else
               xe_local = xe
            end if
            cache_head(node) = xe
            cache_x(node) = xe_local
         end if

         ! Own the dry endpoint semantics here so callers do not need a
         ! duplicate logarithmic transform just to test the first knot.
         if (xe_local < sptab(ind1,node,1)) then
            if (iWhat == 1) then
               ye = sptab(2,node,1)
            else if (iWhat == 2) then
               ye = sptab(3,node,1)
               if (do_ln_trans) ye = dexp(ye)
            else
               dyedxe = 0.0d0
            end if
            return
         end if

         ntotal = ientrytab(node,0)
         tab_xend = sptab(ind1,node,ntotal-1)
         family = 1
         if (ind2 == 3) family = 2

         ! Reuse interval only for the same exact head and same function family.
         if (xe == cache_interval_head(family,node) .and. cache_klo(family,node) > 0) then
            klo = cache_klo(family,node)
            khi = klo + 1
         else
            ! Theta/C alone owns the final wet interval to h=0.
            if (family == 1 .and. xe_local >= tab_xend) then
               klo = ntotal-1
               khi = ntotal
            else
               ndry = 10000
               nwet = matabentries-1-ndry
               tab_xsplit = -2.397895272798370544d0
               tab_invdry = sptab(5,node,ntotal)
               tab_invwet = sptab(7,node,ntotal)

               if (xe_local < tab_xsplit) then
                  k = 1 + int((xe_local-sptab(ind1,node,1))*tab_invdry)
                  k = max(1,min(ndry,k))
               else
                  k = ndry + 1 + int((xe_local-tab_xsplit)*tab_invwet)
                  k = max(ndry+1,min(matabentries-1,k))
               end if
               klo = ientrytab(node,k)

               do while (klo > 1 .and. xe_local < sptab(ind1,node,klo))
                  klo = klo - 1
               end do
               do while (klo < n-1 .and. xe_local >= sptab(ind1,node,klo+1))
                  klo = klo + 1
               end do
               khi = klo + 1
            end if
            cache_interval_head(family,node) = xe
            cache_klo(family,node) = klo
         end if

         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)
"""
if s.count(old_block)!=1:
    raise SystemExit(f"x-map block mismatch: {s.count(old_block)}")
s=s.replace(old_block,new_block,1)
tab.write_text(s)

u=util.read_text()
old_w="""      else if (swsophy == 1) then
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
new_w="""      else if (swsophy == 1) then
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
      end if"""
if u.count(old_w)!=1:
    raise SystemExit(f"watcon table block mismatch: {u.count(old_w)}")
u=u.replace(old_w,new_w,1)

old_c="""      else if (swsophy == 1) then
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
new_c="""      else if (swsophy == 1) then
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, dummy, moiscap, 3)
         end if
      end if"""
if u.count(old_c)!=1:
    raise SystemExit(f"moiscap table block mismatch: {u.count(old_c)}")
u=u.replace(old_c,new_c,1)
util.write_text(u)
print(f"EXACT_HEAD_EVAL_CACHE_PATCH_APPLIED {tab} {util}")
