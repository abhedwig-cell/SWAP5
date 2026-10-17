program batch_activation
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_rotation_calendar
 use mod_swap_daily_weather_file_adapter,only:swap_weather_calendar_day,swap_weather_calendar_year
 use mod_fmr_irrigation_material_root_binding,only:fmr_resolve_irrigation_management_activation
 implicit none
 type(crop_calendar_t)::calendar,empty
 integer::st,year,first_year,last_year,mode,startirr(2),endirr(2),n,k,j,day
 real(real64)::starts(1),ends(1),time,lo,hi,t,base,delta
 real(real64),parameter::offsets(9)=[-.002_real64,-.00101_real64,-.001_real64,-.00099_real64, &
    0._real64,.00099_real64,.001_real64,.00101_real64,.002_real64]
 logical::ok,window,expected,cross,schedule
 n=0
 do mode=1,4
  year=1999
  if(mode==2)year=2000
  first_year=year;last_year=year
  if(mode==3)last_year=year+1
  if(mode==4)then
   first_year=1900;last_year=1901
  end if
  starts=real(swap_weather_calendar_day(first_year,1,1),real64)
  ends=real(swap_weather_calendar_day(last_year,12,31),real64)
  call initialize_crop_calendar(starts,ends,calendar,st);call require(st==CROP_CAL_OK,'existing immutable crop plan')
  cross=last_year>first_year;startirr=[1,3];endirr=[20,9]
  if(cross)then
   lo=real(swap_weather_calendar_day(first_year,3,1),real64)
   hi=real(swap_weather_calendar_day(last_year,9,20),real64)
  else
   ! Preserve literal source annual t: days since actual Jan1, against1900 bounds.
   lo=real(swap_weather_calendar_day(year,1,1)+swap_weather_calendar_day(1900,3,1)- &
      swap_weather_calendar_day(1900,1,1),real64)
   hi=real(swap_weather_calendar_day(year,1,1)+swap_weather_calendar_day(1900,9,20)- &
      swap_weather_calendar_day(1900,1,1),real64)
  end if
  do j=1,2
  base=lo;if(j==2)base=hi
  do k=1,size(offsets)
   time=base+offsets(k)
   ! Evaluate the exact source operators using the same relative subtraction
   ! for the annual branch; large ordinals can round the adjacent tolerance witness.
   if(cross)then
    call b111_window(first_year,last_year,0._real64,time,0._real64,0._real64,lo,hi,expected)
   else
    t=time-real(swap_weather_calendar_day(year,1,1),real64)
    call b111_window(year,year,t,time, &
      real(swap_weather_calendar_day(1900,3,1)-swap_weather_calendar_day(1900,1,1),real64), &
      real(swap_weather_calendar_day(1900,9,20)-swap_weather_calendar_day(1900,1,1),real64),0._real64,0._real64,expected)
   end if
   call fmr_resolve_irrigation_management_activation(calendar,time,startirr,endirr,.true.,window,ok)
   call require(ok.and.(window.eqv.expected),'same-year/cross-year literal boundary operators')
   n=n+1
  end do
  end do
  do day=0,3
   time=starts(1)+real(day,real64)
   call fmr_resolve_irrigation_management_activation(calendar,time,startirr,endirr,.false.,window,ok)
   call require(ok.and..not.window,'schedule off prevents activation')
  end do
  call fmr_resolve_irrigation_management_activation(calendar,starts(1)-1,startirr,endirr,.true.,window,ok)
  call require(ok.and..not.window,'outside authoritative crop period')
 end do
 ! The source annual clock reaches March1's1900 offset on Feb29 in leap2000.
 year=2000;starts=real(swap_weather_calendar_day(year,1,1),real64);ends=starts+365
 call initialize_crop_calendar(starts,ends,calendar,st)
 call fmr_resolve_irrigation_management_activation(calendar,real(swap_weather_calendar_day(2000,2,29),real64), &
   [1,3],[20,9],.true.,window,ok)
 call require(ok.and.window,'historical leap-year annual offset retained')
 do year=1,9999
  call require(swap_weather_calendar_year(swap_weather_calendar_day(year,1,1))==year,'Gregorian year inverse Jan1')
  call require(swap_weather_calendar_year(swap_weather_calendar_day(year,12,31))==year,'Gregorian year inverse Dec31')
 end do
 call fmr_resolve_irrigation_management_activation(empty,starts(1),[1,1],[31,12],.true.,window,ok)
 call require(.not.ok.and..not.window,'absent crop authority rejected')
 call fmr_resolve_irrigation_management_activation(calendar,ieee_value(0._real64,ieee_quiet_nan),[1,1],[31,12],.true.,window,ok)
 call require(.not.ok.and..not.window,'NaN rejected before ordered comparison')
 call fmr_resolve_irrigation_management_activation(calendar,starts(1),[31,2],[31,12],.true.,window,ok)
 call require(.not.ok.and..not.window,'invalid source1900 date rejected')
 print '(a,i0)','BATCH_ACTIVATION_LITERAL_BOUNDARY_CASES=',n
 print '(a)','BATCH_ACTIVATION_EXISTING_CALENDAR_SOURCE_LEAP_INVALID=PASS'
contains
 subroutine require(value,label)
 logical,intent(in)::value
 character(*),intent(in)::label
 if(.not.value)then
 print *,label
 error stop 1
 end if
 end subroutine
end program
