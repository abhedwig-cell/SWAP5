#!/usr/bin/env python3
"""Research-only transformed-x bin accelerator for nonuniform TAB-HYD grids."""
from pathlib import Path
import sys
if len(sys.argv)!=3:
    raise SystemExit("usage: patch_xbin_lookup.py sptabulated.f90 readswap.f90")
tab=Path(sys.argv[1]); reader=Path(sys.argv[2])
s=tab.read_text()

old_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat"
new_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, nbins, kbase"
if s.count(old_int)!=1: raise SystemExit("Eval integer declaration mismatch")
s=s.replace(old_int,new_int,1)

old="""         k   = int(1000*(log10(-xe)+1.d0))+4001
         if(k.lt.1) k=1
         klo = ientrytab(node,k) 
         khi = klo + 1

         if (do_ln_trans) then
            xe_local = -(dlog(-xe+1.0d0))
         else
            xe_local = xe
         end if
         if (xe < -16.5d0) then
            continue
         end if
!     bounds of interval
         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)

!         write (234,'(I5,4F20.10)') klo, xe, xe_local, x1, x2

         
         if( (xe_local-x1) .lt. 0.0d0 )then
            klo = klo -1
            khi = khi -1
            x1 = sptab(ind1,node,klo)
            x2 = sptab(ind1,node,khi)
         else if( (xe_local-x1) .ge. (x2-x1) )then
            klo = klo +1
            khi = khi +1
            x1 = sptab(ind1,node,klo)
            x2 = sptab(ind1,node,khi)
         end if
"""
new="""         if (do_ln_trans) then
            xe_local = -(dlog(-xe+1.0d0))
         else
            xe_local = xe
         end if

         ! TAB-HYD research candidate: address a precomputed uniform-x map.
         ! First half maps theta rows 1..N; second half maps branch-aware
         ! conductivity rows 1..N-1. No log10(-h) is required here.
         nbins = (matabentries-1)/2
         if (ind2 == 3) then
            kbase = nbins + 1
         else
            kbase = 1
         end if
         xlow = sptab(ind1,node,1)
         xhigh = sptab(ind1,node,n)
         k = kbase + int((xe_local-xlow)/(xhigh-xlow)*dble(nbins-1))
         k = max(kbase,min(kbase+nbins-1,k))
         klo = ientrytab(node,k)
         do while (klo > 1 .and. xe_local < sptab(ind1,node,klo))
            klo = klo - 1
         end do
         do while (klo < n-1 .and. xe_local >= sptab(ind1,node,klo+1))
            klo = klo + 1
         end do
         khi = klo + 1
         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)
"""
if s.count(old)!=1: raise SystemExit("legacy forward lookup block mismatch")
tab.write_text(s.replace(old,new,1))

r=reader.read_text()
start=r.index("            ientrytablay(lay,0)=numtablay(lay)")
end_marker="""            call PreProcTabulatedFunction(1,                            &
     &                       numtablay(lay),headtab,thetatab,dydx,sigma)"""
end=r.index(end_marker,start)
new_read="""            ! TAB-HYD research candidate: two dense uniform-x interval maps.
            ientrytablay(lay,:) = 0
            ientrytablay(lay,0)=numtablay(lay)
            do i = 1,numtablay(lay)
              sptablay(1,lay,i) = headtab(i)
              sptablay(2,lay,i) = thetatab(i)
              sptablay(3,lay,i) = conductab(i)
            enddo

            i = 1
            do j = 1,(matabentries-1)/2
              dummy = headtab(1) + (headtab(numtablay(lay))-headtab(1)) * &
     &          dble(j-1) / dble((matabentries-1)/2-1)
              do while (i .lt. numtablay(lay)-1 .and. headtab(i+1) .le. dummy)
                i = i + 1
              enddo
              ientrytablay(lay,j) = i
            enddo

            i = 1
            do j = (matabentries-1)/2+1,matabentries-1
              dummy = headtab(1) + (headtab(numtablay(lay)-1)-headtab(1)) * &
     &          dble(j-((matabentries-1)/2+1)) / dble((matabentries-1)/2-1)
              do while (i .lt. numtablay(lay)-2 .and. headtab(i+1) .le. dummy)
                i = i + 1
              enddo
              ientrytablay(lay,j) = i
            enddo
"""
r=r[:start]+new_read+r[end:]
reader.write_text(r)
print("XBIN_LOOKUP_PATCH_APPLIED")
