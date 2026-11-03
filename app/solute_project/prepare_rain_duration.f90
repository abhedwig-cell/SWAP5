! Original-input forcing adapter. Produces the existing end_day/rate event view.
! Does not supply missing crop, ET, boundary, heat or solute application coupling.
program prepare_rain_duration
 use iso_fortran_env,only:real64
 use mod_daily_rain_duration,only:resolve_daily_rain_duration
 implicit none
 character(1024)::swp,met,output
 integer::arg_status
 integer::mode,n,i,u,code,date(6)
 integer,allocatable::dd(:),mm(:),yyyy(:)
 real(real64),allocatable::rain(:),wet(:)
 real(real64)::first,last,t,previous,duration,rate
 call get_command_argument(1,swp,status=arg_status)
 if(arg_status/=0.or.len_trim(swp)==0)error stop 'requires original project path'
 call get_command_argument(2,met,status=arg_status)
 if(arg_status/=0.or.len_trim(met)==0)error stop 'requires original weather path'
 output='rain_events.csv'
 if(command_argument_count()>3)error stop 'usage: prepare project weather [output]'
 if(command_argument_count()==3)then
  call get_command_argument(3,output,status=arg_status)
  if(arg_status/=0.or.len_trim(output)==0)error stop 'invalid event output path'
 end if
 call rdinit(74,0,trim(swp))
 call rdsinr('swrain',0,3,mode)
 if(mode/=2)error stop 'SWRAIN2 adapter requires original duration forcing'
 call rdstim('tstart',first);call rdstim('tend',last);close(74)
 call rdinit(74,0,trim(met));call rdinne('yyyy',n)
 if(n<1.or.n>100000)error stop 'original weather capacity'
 allocate(dd(n),mm(n),yyyy(n),rain(n),wet(n))
 call rdfinr('dd',1,31,dd,n,n);call rdfinr('mm',1,12,mm,n,n)
 call rdfint('yyyy',yyyy,n,n);call rdfdor('rain',0d0,1000d0,rain,n,n)
 call rdfdor('wet',0d0,1d0,wet,n,n);close(74)
 ! Validate the entire selected window before creating an externally visible
 ! event stream. A late missing day or invalid wet event must leave no prefix.
 previous=first-1d0
 do i=1,n
  date=0;date(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(date,0.,t)
  if(t<first.or.t>last)cycle
  if(t/=previous+1d0)error stop 'original weather must cover consecutive project days'
  call resolve_daily_rain_duration(rain(i),wet(i),duration,rate,code)
  if(code/=0)error stop 'original RAIN and WET do not correspond'
  previous=t
 end do
 if(previous/=last)error stop 'incomplete original weather'
 open(newunit=u,file=trim(output),status='new',action='write')
 write(u,'(a)')'end_day,rate_cm_day'
 do i=1,n
  date=0;date(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(date,0.,t)
  if(t<first.or.t>last)cycle
  call resolve_daily_rain_duration(rain(i),wet(i),duration,rate,code)
  if(duration>0d0)write(u,'(es25.16e3,a,es25.16e3)')t-first+duration,',',rate
  if(duration<1d0)write(u,'(es25.16e3,a,es25.16e3)')t-first+1d0,',',0d0
 end do
 close(u)
 print '(a,i0)','SWP_ORIGINAL_DURATION_PREPARED_DAYS=',nint(last-first+1d0)
end program prepare_rain_duration
