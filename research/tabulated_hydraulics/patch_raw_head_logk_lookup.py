#!/usr/bin/env python3
"""Research-only raw-head interpolation with log(K) retained.

Apply after plateau-split and wet-theta patches, before any transformed-x lookup
patch. Table knots remain the same physical log-head400 knots. The independent
spline coordinate becomes raw pressure head h, while K is still stored and
interpolated as ln(K). Forward interval location uses a per-node/family last
interval hint with binary-search fallback, avoiding runtime log(head).
"""
from pathlib import Path
import sys

if len(sys.argv)!=4:
    raise SystemExit("usage: patch_raw_head_logk_lookup.py sptabulated.f90 readswap.f90 soilhydraulicsutils.f90")
tab=Path(sys.argv[1]); reader=Path(sys.argv[2]); util=Path(sys.argv[3])

r=reader.read_text()
old="""            ! ln-transformation of h and K if global flag do_ln_trans = true
            ! works only if all headtab values are < 0
            if (do_ln_trans) then
               do i = 1, numtablay(lay)
                  headtab(i)   = -dlog(-headtab(i)+1.0d0)     ! minus, so that table remains in stricly increasing order
                  conductab(i) =  dlog(conductab(i))
               end do
            end if"""
new="""            ! TAB-HYD research: keep raw h as spline coordinate while still
            ! storing conductivity in ln(K) for dynamic-range conditioning.
            if (do_ln_trans) then
               do i = 1, numtablay(lay)
                  conductab(i) = dlog(conductab(i))
               end do
            end if"""
if r.count(old)!=1: raise SystemExit(f"readswap transform block mismatch: {r.count(old)}")
r=r.replace(old,new,1)

old="""              if (do_ln_trans) then
                  dummy = -(dexp(-headtab(i))-1.0d0)
              else
                  dummy = headtab(i)
              end if"""
new="""              ! raw-head candidate: headtab remains in physical cm
              dummy = headtab(i)"""
if r.count(old)!=1: raise SystemExit(f"readswap lookup dummy mismatch: {r.count(old)}")
r=r.replace(old,new,1)
reader.write_text(r)

s=tab.read_text()
old_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat"
new_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, family, klast"
if s.count(old_int)!=1: raise SystemExit(f"Eval integer declaration mismatch: {s.count(old_int)}")
s=s.replace(old_int,new_int,1)

old_decl="""      integer ientrytab(macp,0:matabentries), node    
      ! SAVE removed - all local variables are temporary computation values"""
new_decl="""      integer ientrytab(macp,0:matabentries), node
      integer, save :: raw_last_klo(2,macp) = 0
      ! TAB-HYD research: exact interval hint state only."""
if s.count(old_decl)!=1: raise SystemExit(f"Eval save anchor mismatch: {s.count(old_decl)}")
s=s.replace(old_decl,new_decl,1)

start=s.index("      if(inverse .eq. 0)then")
end=s.index("         if (use_TSPACK) then",start)
old_lookup=s[start:end]
new_lookup="""      if(inverse .eq. 0)then
         if(xe.ge.-1.0d-9) then
            stop 'Invalid call of Function EvalTabulatedFunction'
         end if

         xe_local = xe
         family = 1
         if (ind2 == 3) family = 2

         ! Constant dry endpoint.  Conductivity is stored as ln(K).
         if (xe_local < sptab(ind1,node,1)) then
            if (iWhat == 1) then
               ye = sptab(2,node,1)
            else if (iWhat == 2) then
               ye = dexp(sptab(3,node,1))
            else
               dyedxe = 0.0d0
            end if
            return
         end if

         ! Last-interval hint: h usually moves only locally between nonlinear
         ! iterations. Fall back to a bounded binary search on raw h.
         klast = raw_last_klo(family,node)
         if (klast >= 1 .and. klast < n .and. &
     &       xe_local >= sptab(ind1,node,klast) .and. &
     &       xe_local <  sptab(ind1,node,klast+1)) then
            klo = klast
            khi = klo + 1
         else
            klo = 1
            khi = n
            do while (khi-klo > 1)
               k = (khi+klo)/2
               if (sptab(ind1,node,k) > xe_local) then
                  khi = k
               else
                  klo = k
               end if
            end do
            raw_last_klo(family,node) = klo
         end if

         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)

"""
s=s[:start]+new_lookup+s[end:]

old_t="""               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)      ! back transformation for K
            else
               ! C = dWC/dh (3) or dK/dh (4)
               dyedxe = my_HPVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (125,*) IER
               if (do_ln_trans .and. iWhat == 3) dyedxe =  dyedxe/(-xe+1.0d0)           ! back transformation for C
               if (do_ln_trans .and. iWhat == 4) then
                  ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
                  ye = dexp(ye)                          ! back transformation for K
                  dyedxe =  dyedxe*ye/(-xe+1.0d0)        ! back transformation for dK/dh
               end if"""
new_t="""               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (iWhat == 2) ye = dexp(ye)
            else
               ! Raw h means HPVAL is already d()/dh. K remains ln(K).
               dyedxe = my_HPVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (125,*) IER
               if (iWhat == 4) then
                  ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
                  ye = dexp(ye)
                  dyedxe = dyedxe*ye
               end if"""
if s.count(old_t)!=1: raise SystemExit(f"TSPACK transform branch mismatch: {s.count(old_t)}")
s=s.replace(old_t,new_t,1)

old_h="""            ye = f1 + xx*(d1 + xx*(c2 + xx*c3))
            if (do_ln_trans .and. ind2 == 3) ye = dexp(ye)      ! back transformation for K"""
new_h="""            ye = f1 + xx*(d1 + xx*(c2 + xx*c3))
            if (ind2 == 3) ye = dexp(ye)"""
if s.count(old_h)!=1: raise SystemExit(f"Hermite K transform mismatch: {s.count(old_h)}")
s=s.replace(old_h,new_h,1)

# Inverse path is dormant for this research envelope; keep raw h if exercised.
s=s.replace("         if (do_ln_trans) xe = -(dexp(-xe)-1.0d0)","         ! raw-head candidate: xe already is physical h",1)
s=s.replace("      if (do_ln_trans .and. ind2 == 2) dyedxe =  dyedxe/(-xe+1.0d0)           ! back transformation for C\n      if (do_ln_trans .and. ind2 == 3) dyedxe =  dyedxe*ye/(-xe+1.0d0)        ! back transformation for K",
"""      if (ind2 == 3) dyedxe = dyedxe*ye""",1)
tab.write_text(s)

u=util.read_text()
# Wet theta/C wrapper: raw h table means no caller transform for dry endpoint.
u=u.replace("""         dum = head
         if (do_ln_trans .and. head < 0.0_real64) dum = -dlog(-head + 1.0_real64)
         if (head >= -1.0d-9) then""","""         dum = head
         if (head >= -1.0d-9) then""",2)

# K plateau threshold is now the raw penultimate head directly.
old_thr="head > 1.0_real64 - dexp(-sptab(1,node,numtab(node)-1))"
if u.count(old_thr)!=2: raise SystemExit(f"plateau threshold mismatch: {u.count(old_thr)}")
u=u.replace(old_thr,"head > sptab(1,node,numtab(node)-1)")

util.write_text(u)
print("RAW_HEAD_LOGK_LOOKUP_PATCH_APPLIED")
