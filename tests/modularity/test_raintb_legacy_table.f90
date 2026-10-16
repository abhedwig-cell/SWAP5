program test_raintb_legacy_table
  use iso_fortran_env, only: real64, int64
  use ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_swap_daily_weather_file_adapter, only: swap_raintb_t, &
       construct_swap_raintb, construct_swap_raintb_legacy_table, &
       resolve_swap_raintb_pulse, SWAP_WEATHER_FILE_OK
  implicit none
  type(swap_raintb_t) :: table, normalized, invalid
  real(real64) :: flat(12), before(12), knots(4), intensities(4), rains(7)
  real(real64) :: duration,rate,od,orr,nan
  integer :: case_id,n,day,j,status,count
  nan=ieee_value(1.d0,ieee_quiet_nan)
  knots=[10.d0,100.d0,250.d0,365.d0]
  intensities=[0.5d0,2.d0,0.25d0,1.d0]
  rains=[0.d0,0.5d-8,1.d-8,1.00001d-8,0.3d0,1.4d0,100.d0]
  count=0
  do case_id=1,6
    n=min(case_id,4);flat=0.d0
    flat(1:2*n:2)=knots(:n);flat(2:2*n:2)=intensities(:n)
    if(case_id==5) then
      ! Descending nonzero sentinel, whose y and subsequent tail are ignored.
      flat(9)=300.d0;flat(10:12)=nan
    else if(case_id==6) then
      ! Source single-entry array terminated immediately; ignored y is NaN.
      n=1;flat(3)=0.d0;flat(4:12)=nan
    end if
    before=flat
    if(case_id==4) then
      call construct_swap_raintb_legacy_table(flat(:8),table,status)
    else
      call construct_swap_raintb_legacy_table(flat,table,status)
    end if
    call require(status==SWAP_WEATHER_FILE_OK.and.table%ready(),'legacy prefix constructs')
    call require(all(transfer(flat,[0_int64])==transfer(before,[0_int64])),'input bytes unchanged')
    call construct_swap_raintb(knots(:n),intensities(:n),normalized,status)
    call require(status==SWAP_WEATHER_FILE_OK.and.table%same_input(normalized),'existing owner identity')
    do day=1,366
      do j=1,size(rains)
        call resolve_swap_raintb_pulse(table,day,rains(j),duration,rate,status)
        call require(status==SWAP_WEATHER_FILE_OK,'legacy production pulse')
        if(case_id==4) then
          call source_pulse(flat(:8),real(day,real64),rains(j),od,orr)
        else
          call source_pulse(flat,real(day,real64),rains(j),od,orr)
        end if
        call require(transfer(duration,0_int64)==transfer(od,0_int64),'literal duration bits')
        call require(transfer(rate,0_int64)==transfer(orr,0_int64),'literal rate bits')
        count=count+1
      end do
    end do
  end do
  call construct_swap_raintb_legacy_table([1.d0,2.d0],table,status)
  call require(status==SWAP_WEATHER_FILE_OK,'minimal complete pair')
  call bad([real(real64)::],'empty')
  call bad([1.d0],'incomplete pair')
  call bad([1.d0,2.d0,3.d0],'odd array')
  call bad([1.d0,1.d0,1.d0,2.d0],'duplicate active x')
  call bad([1.d0,0.d0,0.d0,nan],'zero active intensity')
  call bad([1.d0,-1.d0,0.d0,nan],'negative active intensity')
  call bad([nan,1.d0],'nonfinite first x')
  call bad([1.d0,nan,0.d0,nan],'nonfinite active y')
  call bad([1.d0,1.d0,nan,1.d0],'nonfinite sentinel x')
  call bad([0.d0,1.d0],'first x out of domain')
  call bad([1.d0,1.d0,367.d0,1.d0],'active x out of domain')
  ! Failure clears its output; valid construction after failure is deterministic.
  call construct_swap_raintb_legacy_table([1.d0,2.d0,0.d0,nan],normalized,status)
  call require(status==SWAP_WEATHER_FILE_OK.and.table%same_input(normalized),'A bad A identity')
  print '(a,i0)','MODULAR_RAINTB_LEGACY_LITERAL_CASES=',count
  print '(a)','MODULAR_RAINTB_LEGACY_PREFIX_ORACLE_NONMUTATION_NEGATIVES=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      print *, 'FAIL ',label
      error stop 1
    end if
  end subroutine
  subroutine bad(raw,label)
    real(real64),intent(in)::raw(:)
    character(*),intent(in)::label
    call construct_swap_raintb_legacy_table(raw,invalid,status)
    call require(status/=SWAP_WEATHER_FILE_OK.and..not.invalid%ready(),label)
  end subroutine
  subroutine source_pulse(raintb,doy,rain,duration,rate)
    real(real64),intent(in)::raintb(:),doy,rain
    real(real64),intent(out)::duration,rate
    real(real64)::all_rain(1),rainflx(1),rtim,rflx
    integer::i,rain_rec
    i=1;rain_rec=1;all_rain(1)=rain;rtim=0.d0;rainflx=0.d0
    if(all_rain(i)>1.0d-8) then
                  rflx = afgen(raintb, size(raintb), doy)
                  rtim = dmin1(1.d0, all_rain(i) * 0.1d0 / rflx)
               rainflx(rain_rec) = all_rain(i) * 0.1d0 / rtim
    end if
    duration=rtim;rate=rainflx(1)
  end subroutine
  ! BEGIN LITERAL B1.11 AFGEN
   real(8) function afgen (table, iltab, x)

      ! ------------------------------------------------------------------
      ! source  : kees rappoldt, 1/86
      ! purpose : linear interpolation in table with length iltab for a
      !           given value of the independent variable x.
      ! ------------------------------------------------------------------

      implicit none

      ! global
      integer, intent(in) :: iltab
      real(8), intent(in) :: table(iltab), x

      ! local
      integer :: i
      real(8) :: slope

      ! ------------------------------------------------------------------

      if (table(1) >= x)  goto 40
      do i = 3,iltab-1,2
        if (table(i) >= x) goto 30
        if (table(i) < table(i-2)) goto 20
      end do

      ! table fully filled, argument larger then last x in table
      afgen = table(iltab)
      return

      ! table partly filled, argument larger then last x in table
 20   afgen = table(i-1)
      return
      ! argument between first and last x in table, interpolation
 30   slope = (table(i+1)-table(i-1))/(table(i)-table(i-2))
      afgen = table(i-1) + (x-table(i-2))*slope
      return

      ! argument less or equal to first x in table
 40   afgen = table(2)
      return

   end function afgen
  ! END LITERAL B1.11 AFGEN
end program
