#!/usr/bin/env python3
"""Research-only O(1) interval selection for adaptive log10(-h) TAB-HYD tables.

Assumptions are deliberately narrow:
- raw table heads start at -1e7 cm;
- rows 1..N-1 are uniform in log10(-h), including the generated K-branch threshold;
- row N is the saturated h=0 endpoint;
- patch_table_ksat_plateau_split.py has already limited K preprocessing to N-1.

The inverse log-head spacing is stored once in the otherwise unused final K
sigma slot sptab(7,node,N). TSPACK interpolation itself is unchanged.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_direct_loghead_tspack.py sptabulated.f90 readswap.f90")

tab=Path(sys.argv[1])
reader=Path(sys.argv[2])

s=tab.read_text()
old_decl="real(8) xlow, xhigh, xtry, ytry, xe_local"
new_decl="real(8) xlow, xhigh, xtry, ytry, xe_local, tab_u, tab_invdu"
if s.count(old_decl)!=1:
    raise SystemExit(f"expected one Eval declaration, found {s.count(old_decl)}")
s=s.replace(old_decl,new_decl,1)

start=s.index("subroutine EvalTabulatedFunction")
end=s.index("else if(inverse.eq.1)then",start)
forward=s[start:end]

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

         ! TAB-HYD research candidate: direct interval selection on the
         ! generated log10(-h) grid. For K, n is N-1 because the saturated
         ! plateau endpoint is excluded from TSPACK preprocessing.
         tab_u = log10(-xe)
         if (ind2 == 3) then
            tab_invdu = sptab(7,node,n+1)
            klo = int((tab_u-7.0d0)*tab_invdu) + 1
            klo = max(1,min(n-1,klo))
            khi = klo + 1
         else
            tab_invdu = sptab(7,node,n)
            if (xe_local >= sptab(ind1,node,n-1)) then
               klo = n-1
               khi = n
            else
               klo = int((tab_u-7.0d0)*tab_invdu) + 1
               klo = max(1,min(n-2,klo))
               khi = klo + 1
            end if
         end if
         x1 = sptab(ind1,node,klo)
         x2 = sptab(ind1,node,khi)
"""
if forward.count(old)!=1:
    raise SystemExit(f"expected one legacy forward lookup block, found {forward.count(old)}")
s=s[:start]+forward.replace(old,new,1)+s[end:]
tab.write_text(s)

r=reader.read_text()
needle="""            do i = 1,numtablay(lay)-1
              sptablay(5,lay,i) = dydx(i)
              sptablay(7,lay,i) = sigma(i)   !## MH: new
            enddo"""
insert="""            do i = 1,numtablay(lay)-1
              sptablay(5,lay,i) = dydx(i)
              sptablay(7,lay,i) = sigma(i)   !## MH: new
            enddo
            ! TAB-HYD research metadata: inverse spacing of rows 1..N-1
            ! in the generated log10(-h) coordinate. headtab is already
            ! stored in x=-ln(1-h), so recover raw h only once at input.
            sptablay(7,lay,numtablay(lay)) = dble(numtablay(lay)-2) / &
     &        (log10(dexp(-headtab(numtablay(lay)-1))-1.0d0) - &
     &         log10(dexp(-headtab(1))-1.0d0))"""
if r.count(needle)!=1:
    raise SystemExit(f"expected branch-aware K preprocessing block, found {r.count(needle)}")
r=r.replace(needle,insert,1)
reader.write_text(r)
print(f"DIRECT_LOGHEAD_TSPACK_PATCH_APPLIED {tab} {reader}")
