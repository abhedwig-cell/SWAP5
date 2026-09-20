#!/usr/bin/env python3
"""Research-only two-range x-map lookup for the proven log-head400 table.

The table representation and TSPACK interpolation are left unchanged.
Only forward interval location changes:
- rows 1..N-1 use one shared map for theta/C and K/dKdh;
- h >= the penultimate theta knot uses the final theta interval directly;
- the map is dense in transformed x=-ln(1-h), with 10k dry bins and the
  remaining bins concentrated over h=-10..the K-branch threshold;
- per-table inverse bin widths are stored in the otherwise unused final
  conductivity derivative/tension slots.
"""
from pathlib import Path
import sys

if len(sys.argv)!=3:
    raise SystemExit("usage: patch_piecewise_xmap_lookup.py sptabulated.f90 readswap.f90")

tab=Path(sys.argv[1]); reader=Path(sys.argv[2])
s=tab.read_text()

old_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat"
new_int="integer k, klo, khi, n, inverse, maxtry, ntry, ind1, ind2, ind3, iWhat, ndry, nwet, ntotal"
if s.count(old_int)!=1:
    raise SystemExit(f"Eval integer declaration mismatch: {s.count(old_int)}")
s=s.replace(old_int,new_int,1)

old_real="real(8) xlow, xhigh, xtry, ytry, xe_local"
new_real="real(8) xlow, xhigh, xtry, ytry, xe_local, tab_xsplit, tab_xend, tab_invdry, tab_invwet"
if s.count(old_real)!=1:
    raise SystemExit(f"Eval real declaration mismatch: {s.count(old_real)}")
s=s.replace(old_real,new_real,1)

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
if s.count(old)!=1:
    raise SystemExit(f"legacy forward lookup block mismatch: {s.count(old)}")
tab.write_text(s.replace(old,new,1))

r=reader.read_text()
start=r.index("            ientrytablay(lay,0)=numtablay(lay)")
end_marker="""            call PreProcTabulatedFunction(1,                            &
     &                       numtablay(lay),headtab,thetatab,dydx,sigma)"""
end=r.index(end_marker,start)

new_read="""            ! TAB-HYD research candidate: dense two-range x map for the
            ! already-proven log-head400 representation.  The dry part spans
            ! x(h=-1e7)..x(h=-10); the wet part spans x(h=-10)..x(row N-1).
            ientrytablay(lay,:) = 0
            ientrytablay(lay,0)=numtablay(lay)
            do i = 1,numtablay(lay)
              sptablay(1,lay,i) = headtab(i)
              sptablay(2,lay,i) = thetatab(i)
              sptablay(3,lay,i) = conductab(i)
            enddo

            dum = -2.397895272798370544d0
            if (.not. (headtab(1) .lt. dum .and. dum .lt. headtab(numtablay(lay)-1))) then
              messag = ' TAB-HYD x-map split outside continuous table range'
              call fatalerr('Readswap',messag)
            endif

            sptablay(5,lay,numtablay(lay)) = 10000.d0 / (dum-headtab(1))
            sptablay(7,lay,numtablay(lay)) = dble(matabentries-1-10000) / &
     &        (headtab(numtablay(lay)-1)-dum)

            i = 1
            do j = 1,10000
              dummy = headtab(1) + (dum-headtab(1)) * dble(j-1) / 10000.d0
              do while (i .lt. numtablay(lay)-2 .and. headtab(i+1) .le. dummy)
                i = i + 1
              enddo
              ientrytablay(lay,j) = i
            enddo

            i = 1
            do j = 10001,matabentries-1
              dummy = dum + (headtab(numtablay(lay)-1)-dum) * &
     &          dble(j-10001) / dble(matabentries-1-10000)
              do while (i .lt. numtablay(lay)-2 .and. headtab(i+1) .le. dummy)
                i = i + 1
              enddo
              ientrytablay(lay,j) = i
            enddo
"""
r=r[:start]+new_read+r[end:]
reader.write_text(r)
print(f"PIECEWISE_XMAP_LOOKUP_PATCH_APPLIED {tab} {reader}")
