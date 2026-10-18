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
real(8) :: ts,te,telapsed,trialdt,res,evsum,rosum,qsum,startstore,oldpond
real(8),allocatable::oldh(:),oldt(:)
character(len=256)::mode,statefile,arg
character(len=100)::inputswp='swap.swp',outstem='match'
real(8)::requested_rain,requested_peva,requested_epond
integer :: j,naccept,nreject
ts=0.d0;te=0.d0
call swap(0,1,ts,te,swp_file=inputswp,outfile=outstem)
call get_command_argument(1,mode)
if(trim(mode)/='matched200')then
numnod=4
z(1:numnod)=[-.25d0,-.75d0,-1.5d0,-2.5d0]
dz(1:numnod)=[.5d0,.5d0,1.d0,1.d0]
! Diagnostic numerical replay preserves the original inconsistent pilot distances.
disnod(1:5)=1.d0
h(1:numnod)=[1.0008476271206002d0,2.0008476271206002d0,3.0008476271206002d0,4.0008476271206002d0]
theta(1:numnod)=.423d0;pond=.00084762712060012352d0
end if
call get_command_argument(2,statefile)
if(len_trim(statefile)>0)then
 open(99,file=trim(statefile),status='old');read(99,*)ts,pond
 do j=1,numnod
  read(99,*)h(j),theta(j)
 end do
 close(99)
end if
allocate(oldh(numnod),oldt(numnod))
gwl=-2.d0;swbotb=6;qbot=0.d0;nraidt=0.d0;nird=0.d0;melt=0.d0;runon=0.d0
qssdi=0.d0;qrot=0.d0;rfcp=1.d0;frarmtrx=1.d0;armpss=0.d0;swmacro=0
swkimpl=0;swkmean=1;swredu=0
peva=.16670095072250193d0;epond=.29208623054557664d0;empreva=peva
call get_command_argument(3,arg)
if(len_trim(arg)>0)read(arg,*)peva
call get_command_argument(4,arg)
if(len_trim(arg)>0)read(arg,*)epond
call get_command_argument(5,arg)
if(len_trim(arg)>0)read(arg,*)nraidt
empreva=peva
call get_command_argument(6,arg)
if(trim(arg)/='historical')then
maxit=40;maxbacktr=32;CritDevBalCp=1.d-12;CritDevBalTot=1.d-12
critdevh1cp=1.d-12;critdevh2cp=1.d-12;critdevponddt=1.d-12
end if
fldtmin=.false.;fldaystart=.true.;dtmin=1.d-15
call boundtop(1)
startstore=sum(theta(1:numnod)*dz(1:numnod))+pond
telapsed=0.d0;trialdt=1.d0/2400.d0;evsum=0;rosum=0;qsum=0;naccept=0;nreject=0
write(*,*) 'NATIVE_MATCH_BEGIN',startstore,1.d0/24.d0
write(*,*) 'NATIVE_ABSOLUTE_INTERVAL',ts,ts+1.d0/24.d0
write(*,*) 'NATIVE_NUMERICAL',maxit,maxbacktr,CritDevBalCp,CritDevBalTot,critdevh1cp,critdevh2cp,critdevponddt
 do while(telapsed<1.d0/24.d0)
  oldh=h(1:numnod);oldt=theta(1:numnod);oldpond=pond
  hm1(1:numnod)=h(1:numnod);thetm1(1:numnod)=theta(1:numnod);pondm1=pond;gwlm1=gwl
  dt=min(trialdt,1.d0/24.d0-telapsed);dtold=dt;fldecdt=.false.
  call headcalc
  res=sum((theta(1:numnod)-oldt)*dz(1:numnod))+pond-oldpond+(reva+epd-nraidt)*dt+runots
  if(fldecdt.or.abs(res)>1.d-10)then
   h(1:numnod)=oldh;theta(1:numnod)=oldt;pond=oldpond
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
write(*,*) 'NATIVE_MATCH_BALANCE',sum(theta(1:numnod)*dz(1:numnod))+pond-startstore+evsum+rosum-nraidt*telapsed
write(*,*) 'NATIVE_MATCH_HEAD',h(1:numnod)
write(*,*) 'NATIVE_MATCH_THETA',theta(1:numnod)
end program
