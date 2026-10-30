! Original project receipt replay, component qualification only. Hydraulic/crop
! observations are actual SWAP4.3.1 output, not an alternate SWAP5 water model.
program original_hupsel_irrigation
 use iso_fortran_env,only:real64
 use mod_hupsel_scheduled_irrigation
 implicit none
 type(original_potato_irrigation_t)::current,candidate,restored,wrong
 integer::u,r,day,emerged,code,io,gifts=0,n=0
 real(real64)::origin,dvs,rain,expected,potential,drought,salinity,event_end,rate,gift,error=0d0
 real(real64)::other_end,other_rate
 call rdinit(74,0,'swap.swp');call rdstim('tstart',origin);close(74)
 call current%initialize('potato.crp',origin,34,code);call require(code==0,'original potato input binding')
 call restored%initialize('potato.crp',origin,34,code);call require(code==0,'restart immutable source binding')
 call require(abs(current%parameters%rate_cm_per_day-36d0)<1d-12,'source mm/hour to cm/day')
 open(newunit=u,file='source.txt',status='old')
 do
  read(u,*,iostat=io)day,dvs,emerged,rain,expected,potential,drought,salinity
  if(io<0)exit
  call require(io==0,'source receipt read')
  if(day>=494.and.day<637)then
   call current%propose_day(real(day,real64),dvs,emerged==1,rain,candidate,event_end,rate,code)
   call require(code==0,'source scheduling proposal')
   gift=rate*(event_end-day);error=max(error,abs(gift-expected));n=n+1
   if(gift>0d0)then
    gifts=gifts+1
    write(*,'(a,i0,a,3(es24.16,1x))')'ORIGINAL_POTATO_IRRIGATION day=',day+1,' gift/rate/duration=',gift,rate,event_end-day
   end if
   call require(abs(gift-expected)<1d-9,'source original irrigation dates and dose')
   current=candidate
  end if
  call current%commit_day(real(day+1,real64),potential,drought,salinity,code)
  call require(code==0,'publish preceding accepted day stress')
  open(newunit=r,file='irrigation.bin',access='stream',form='unformatted',status='replace')
  call irrigation_native_view(r,.false.,current,code);close(r);call require(code==0,'native owner write')
  open(newunit=r,file='irrigation.bin',access='stream',form='unformatted',status='old')
  call irrigation_native_view(r,.true.,restored,code);close(r);call require(code==0,'native owner read')
  call require(restored%clock==current%clock.and.restored%state%dayfix==current%state%dayfix,'exact clock and DAYFIX restart')
  call require(restored%previous_potential==current%previous_potential.and. &
       restored%previous_drought==current%previous_drought.and.restored%previous_salinity==current%previous_salinity, &
       'exact accepted source observation restart')
  if(day>=494.and.day<636)then
   call current%propose_day(real(day+1,real64),dvs,emerged==1,rain,candidate,event_end,rate,code)
   call require(code==0,'next native source proposal')
   call restored%propose_day(real(day+1,real64),dvs,emerged==1,rain,wrong,other_end,other_rate,code)
   call require(code==0.and.event_end==other_end.and.rate==other_rate,'same restart event plan')
  end if
 end do
 close(u)
 write(*,'(a,i0,a,i0,a,es24.16)')'ORIGINAL_POTATO_SCHEDULE_RECEIPTS=',n,' GIFTS=',gifts,' MAX_DIFFERENCE_CM=',error
 print '(a)','ORIGINAL_INPUT_IRRIGATION_OWNER_REPLAY_AND_RESTART=PASS_NOT_WHOLE_MODEL_EXECUTION'
contains
 subroutine require(ok,why)
  logical,intent(in)::ok
  character(*),intent(in)::why
  if(.not.ok)then;print *,why;error stop 1;end if
 end subroutine
end program
