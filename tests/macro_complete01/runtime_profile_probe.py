"""Read-only timing inside existing Jac37; no physical or solver changes."""
from donor_sources import replace

def render(s):
 s=s.replace('\r\n','\n')
 s=replace(s,'integer,save::tu,systems_unit=0,active_count=0', '''integer,save::tu,systems_unit=0,active_count=0
integer(8)::pr0,pr1,pr2,pr3,prate
integer(8),save::pfirst=0,plast=0
real(8),save::pterms=0d0,psolve=0d0,plog=0d0,poutside=0d0
real(8)::pcpu
real(8),save::pcpufirst=0d0
integer,save::pcount=0,punit=0,pzero=0
call system_clock(pr0,prate)
call cpu_time(pcpu)
if(pcount==0)then
 pfirst=pr0;pcpufirst=pcpu
else
 poutside=poutside+dble(pr0-plast)/dble(prate)
end if''')
 s=replace(s,'call jac37_terms(n,uu,vv,bl,bd,diag_extra,meta,handled)', '''call jac37_terms(n,uu,vv,bl,bd,diag_extra,meta,handled)
call system_clock(pr1)''')
 s=replace(s,'if(.not.opened)then', 'call system_clock(pr2)\nif(.not.opened)then')
 s=replace(s,"end subroutine\n\n! Stop an initial",'''call system_clock(pr3)
pterms=pterms+dble(pr1-pr0)/dble(prate)
psolve=psolve+dble(pr2-pr1)/dble(prate)
plog=plog+dble(pr3-pr2)/dble(prate)
pcount=pcount+1
if(handled.and.all(uu(1:n,1:NumDm+1)==0d0))pzero=pzero+1
if(mod(pcount,64)==0.or.pcount==1)then
 if(punit==0)open(newunit=punit,file='macro_runtime_profile.txt',status='replace')
 call cpu_time(pcpu)
 write(punit,*)pcount,t1900,dt,numbit,dble(pr3-pfirst)/dble(prate),pterms,psolve,plog,poutside,pcpu-pcpufirst,pzero
 flush(punit)
end if
call system_clock(plast)
end subroutine

! Stop an initial''')
 return s
