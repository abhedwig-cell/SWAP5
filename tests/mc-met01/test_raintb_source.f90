program test_raintb_source
  use iso_fortran_env,only:real64,int64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_swap_daily_weather_file_adapter
  implicit none
  type(swap_raintb_t)::table,invalid,changed
  real(real64)::x(4),y(4),flat(8),d,r,od,orr,rains(7),nan
  integer::i,j,k,s,count,n
  interface
    subroutine b111_pulse(t,n,day,rain,duration,rate)
      import real64
      integer,intent(in)::n
      real(real64),intent(in)::t(n),day,rain
      real(real64),intent(out)::duration,rate
    end subroutine
  end interface
  rains=[0.d0,0.5d-8,1.d-8,1.00001d-8,0.3d0,1.4d0,100.d0]
  count=0
  do k=1,3
    n=4
    x=[10.d0,100.d0,250.d0,365.d0];y=[0.5d0,2.d0,0.25d0,1.d0]
    if(k==2) y=1.d0
    if(k==3) n=1
    call construct_swap_raintb(x(:n),y(:n),table,s)
    call require(s==SWAP_WEATHER_FILE_OK.and.table%ready(),'valid table')
    do i=1,n
      flat(2*i-1)=x(i);flat(2*i)=y(i)
    end do
    do i=1,366
      do j=1,size(rains)
        call resolve_swap_raintb_pulse(table,i,rains(j),d,r,s)
        call require(s==SWAP_WEATHER_FILE_OK,'valid source pulse')
        call b111_pulse(flat(:2*n),2*n,real(i,real64),rains(j),od,orr)
        call require(transfer(d,0_int64)==transfer(od,0_int64),'literal duration bits')
        call require(transfer(r,0_int64)==transfer(orr,0_int64),'literal rate bits')
        count=count+1
      end do
    end do
  end do
  call construct_swap_raintb([1.d0,1.d0],[1.d0,2.d0],invalid,s)
  call require(s/=SWAP_WEATHER_FILE_OK.and..not.invalid%ready(),'duplicate knots')
  call construct_swap_raintb([2.d0,1.d0],[1.d0,2.d0],invalid,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'descending knots')
  call construct_swap_raintb([1.d0,366.d0],[0.d0,2.d0],invalid,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'zero intensity')
  nan=ieee_value(1.d0,ieee_quiet_nan)
  call construct_swap_raintb([1.d0,366.d0],[nan,2.d0],invalid,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'nan table')
  call resolve_swap_raintb_pulse(table,0,1.d0,d,r,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'invalid doy')
  call resolve_swap_raintb_pulse(table,1,-1.d0,d,r,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'negative rain')
  call resolve_swap_raintb_pulse(table,1,nan,d,r,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'nan rain')
  call construct_swap_raintb([10.d0],[0.6d0],changed,s)
  call require(.not.table%same_input(changed),'table identity mismatch')
  call construct_swap_raintb([1.d0],[tiny(1.d0)],invalid,s)
  call resolve_swap_raintb_pulse(invalid,1,huge(1.d0),d,r,s)
  call require(s/=SWAP_WEATHER_FILE_OK,'overflow rejected before arithmetic trap')
  call require(swap_weather_calendar_day(2000,3,1)-swap_weather_calendar_day(2000,1,1)==60,'leap ordinal')
  call require(swap_weather_calendar_day(1900,3,1)-swap_weather_calendar_day(1900,1,1)==59,'nonleap century')
  call require(swap_weather_calendar_day(2000,1,1)-swap_weather_calendar_day(1999,12,31)==1,'year boundary')
  print '(a,i0)','MC_MET01_LITERAL_CASES=',count
  print '(a)','MC_MET01_LITERAL_AFGEN_THRESHOLD_PULSE_CALENDAR_NEGATIVES=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      print *,'FAIL ',label
      error stop 1
    end if
  end subroutine
end program
