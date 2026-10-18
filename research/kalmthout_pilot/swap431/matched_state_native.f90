program matched_state_native
use MOD_grid, only: numnod,z,dz,disnod
use variables
use MOD_top, only: boundtop, ftoph,hsurf
use MOD_meteo, only: nraidt,epond,peva,empreva
use MOD_frost, only: rfcp
use MOD_irrigation,only:nird,qssdi
use MOD_swap_mp,only:frarmtrx,armpss
use MOD_snow,only:melt
use MOD_swap_base,only:swmacro
implicit none
interface
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap)
   !!!subroutine SWAP(iCaller, iTask, tstart_in, tend_in, toswap, fromswap)
      use swap_exchange
      use MOD_arrays, only: fillen
      integer,                intent(in)              :: iCaller, iTask
      real(8),                intent(inout)           :: tstart_in, tend_in
      character(len=fillen),  intent(in),    optional :: swp_file
      character(len=fillen),  intent(in),    optional :: outfile
      type(swap_input),       intent(in),    optional :: toswap
      type(swap_output),      intent(out),   optional :: fromswap
   end subroutine SWAP
end interface
real(8) :: ts,te,telapsed,trialdt,res,evsum,rosum,qsum,startstore,oldh(4),oldt(4),oldpond
integer :: j,naccept,nreject
call swap(0,1,ts,te)
numnod=4
z(1:4)=[-.25d0,-.75d0,-1.5d0,-2.5d0]
dz(1:4)=[.5d0,.5d0,1.d0,1.d0]
! Diagnostic numerical replay preserves the original inconsistent pilot distances.
disnod(1:5)=1.d0
h(1:4)=[1.0008476271206002d0,2.0008476271206002d0,3.0008476271206002d0,4.0008476271206002d0]
theta(1:4)=.423d0;pond=.00084762712060012352d0
gwl=-2.d0;swbotb=6;qbot=0.d0;nraidt=0.d0;nird=0.d0;melt=0.d0;runon=0.d0
qssdi=0.d0;qrot=0.d0;rfcp=1.d0;frarmtrx=1.d0;armpss=0.d0;swmacro=0
swkimpl=0;swkmean=1;swredu=0
peva=.16670095072250193d0;epond=.29208623054557664d0;empreva=peva
maxit=40;maxbacktr=32;CritDevBalCp=1.d-12;CritDevBalTot=1.d-12
critdevh1cp=1.d-12;critdevh2cp=1.d-12;critdevponddt=1.d-12
fldtmin=.false.;fldaystart=.true.;dtmin=1.d-15
call boundtop(1)
startstore=sum(theta(1:4)*dz(1:4))+pond
telapsed=0.d0;trialdt=1.d0/2400.d0;evsum=0;rosum=0;qsum=0;naccept=0;nreject=0
write(*,*) 'NATIVE_MATCH_BEGIN',startstore,1.d0/24.d0
 do while(telapsed<1.d0/24.d0)
  oldh=h(1:4);oldt=theta(1:4);oldpond=pond
  hm1(1:4)=h(1:4);thetm1(1:4)=theta(1:4);pondm1=pond;gwlm1=gwl
  dt=min(trialdt,1.d0/24.d0-telapsed);dtold=dt;fldecdt=.false.
  call headcalc
  res=sum((theta(1:4)-oldt)*dz(1:4))+pond-oldpond+(reva+epd)*dt+runots
  if(fldecdt.or.abs(res)>1.d-10)then
   h(1:4)=oldh;theta(1:4)=oldt;pond=oldpond
   trialdt=dt/2;nreject=nreject+1
   if(trialdt<1.d-14.or.nreject>1000)then
    write(*,*) 'NATIVE_MATCH_FAILED',telapsed,trialdt,res;stop 1
   end if
  else
   telapsed=telapsed+dt;naccept=naccept+1
   evsum=evsum+(reva+epd)*dt;rosum=rosum+runots;qsum=qsum+qtop*dt
   trialdt=min(1.d0/2400.d0,trialdt*1.25d0)
  end if
 end do
write(*,*) 'NATIVE_MATCH_END',telapsed,naccept,nreject,evsum,rosum,qsum,pond
write(*,*) 'NATIVE_MATCH_BALANCE',sum(theta(1:4)*dz(1:4))+pond-startstore+evsum+rosum
write(*,*) 'NATIVE_MATCH_HEAD',h(1:4)
write(*,*) 'NATIVE_MATCH_THETA',theta(1:4)
end program
