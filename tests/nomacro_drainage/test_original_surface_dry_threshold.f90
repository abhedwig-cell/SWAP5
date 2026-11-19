program original_extended_drain_contract
use iso_fortran_env,only:real64
use ieee_arithmetic,only:ieee_is_finite
use MOD_swap_base,only:swdra,swmacro
use MOD_grid,only:numnod,dz
use MOD_swap_mp,only:qrapdra
use variables,only:gwl,pond,pondmx,dt,t1900,tcum,t,fldecdt,fldtmin,rsro,theta,thetas,h
use MOD_drain
implicit none
integer::i
real(8)::before,expected
swdra=2;swmacro=0;numnod=2;dz(1:2)=50d0
nrlevs=2;nrpri=1;nrsec=1;swsrf=3;swsec=1;swdivd=0
swdtyp(1:2)=2;zbotdr(1:2)=[-100d0,-80d0]
widthr(1:2)=100d0;taludr(1:2)=1d0;lspacing(1:2)=1000d0
rdrain(1:2)=100d0;rinfi(1:2)=200d0;rentry(1:2)=0d0;rexit(1:2)=0d0
gwlinf(1:2)=-150d0;swnrsrf=0;pond=0d0;pondmx=10d0;dt=.25d0;t1900=40000d0
fldecdt=.false.;fldtmin=.false.;qrapdra=0d0
wlp=-60d0;wls=-40d0;gwl=-20d0
call drain(2)
call check('drainage',.6d0,.2d0)
wlp=-20d0;wls=-40d0;gwl=-70d0
call drain(2)
call check('infiltration',-.4d0,-.15d0)
wlp=-101d0;wls=-81d0;gwl=-120d0
call drain(2)
call check('dry',0d0,0d0)
! Actual extended storage task: no supply, fixed high weir, all drainage
! enters the real secondary store. The soil and store transfer must cancel.
swsrf=2;swsec=2;nrpri=0;nrsec=2;nmper=1;impend(1)=40010d0
swman(1)=1;hbweir(1)=-10d0;wscap(1)=0d0;wldip(1)=0d0
swqhr=1;alphaw(1)=1d0;betaw(1)=1d0;osswlm=10d0
wls=-60d0;wlstar=-10d0;wlsbak=-60d0;swst=4d0
! Monotone descending original storage table, with explicit units cm.
do i=1,22
 sttab(i,1)=10d0-110d0*dble(i-1)/21d0
 sttab(i,2)=(sttab(i,1)+100d0)*.1d0
end do
theta(1:2)=.3d0;thetas(1:2)=.4d0;h(1:2)=-20d0
rsro=1d0;tcum=.25d0;t=0d0;gwl=-20d0
before=swst
call drain(2)
expected=before+qdrd*dt
call drain(3)
if(fldecdt)error stop 'unexpected original rejected surface trial'
if(abs(swst-expected)>1d-12)error stop 'soil-surface transfer does not cancel'
if(.not.ieee_is_finite(wls))error stop 'nonfinite actual surface level'
write(*,'(a,5(1x,es25.17e3))')'ACTUAL_ORIGINAL_SURFACE_STORAGE',before,qdrd,dt,swst,wls
! Actual original rejected surfacewater trial modifies committed-dependent
! storage before the original main loop requests soil-only rollback.
wls=-60d0;swst=4d0;wlstar=-10d0;wlsbak=-60d0
pond=.2d0;pondmx=.1d0;fldecdt=.false.;dt=.25d0
before=swst
call drain(2)
expected=qdrd
call drain(3)
if(.not.fldecdt)error stop 'original retry trigger not reached'
if(swst==before)error stop 'original surface rejection unexpectedly atomic'
write(*,'(a,5(1x,es25.17e3))')'ACTUAL_ORIGINAL_REJECTED_SURFACE_MUTATION',before,expected,dt,swst,wls
! Original tiny positive surface storage must not disappear with zero flux.
fldecdt=.false.;pond=0d0;pondmx=10d0;dt=.25d0
wls=-100d0+5d-7;gwl=wls;swst=5d-8;wlstar=-10d0;wlsbak=wls
before=swst
call drain(2)
if(qdrd/=0d0)error stop 'nonzero flux in original tiny storage fixture'
call drain(3)
if(fldecdt.or.swst/=0d0)error stop 'original dry cutoff not reached'
if(abs(swst-before-qdrd*dt)<=1d-10)error stop 'original defect not discriminated'
write(*,'(a,4(1x,es25.17e3))')'ACTUAL_ORIGINAL_POSITIVE_STORAGE_LOSS',before,qdrd,swst,swst-before-qdrd*dt
contains
subroutine check(label,total,secondary)
character(*),intent(in)::label
real(8),intent(in)::total,secondary
if(.not.all(ieee_is_finite(qdrain(1:2))))error stop 'nonfinite original drain flux'
if(abs(qdrtot-total)>1d-14.or.abs(qdrd-secondary)>1d-14)error stop 'signed drain contract'
if(abs(sum(qdra(1:2,1:2))-qdrtot)>1d-14)error stop 'partition contract'
write(*,'(a,1x,a,5(1x,es25.17e3))')'ACTUAL_ORIGINAL_EXTENDED_DRAIN',label,gwl,qdrain(1:2),qdrtot,qdrd
end subroutine
end program
