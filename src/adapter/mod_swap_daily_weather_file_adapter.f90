module mod_swap_daily_weather_file_adapter
  use iso_fortran_env, only: real64, int64, iostat_end
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: SWAP_WEATHER_FILE_OK=0, SWAP_WEATHER_FILE_INVALID=1, &
       SWAP_WEATHER_FILE_IO=2, SWAP_WEATHER_FILE_MISSING=3
  ! Immutable input, not a meteorological or physical state owner. Only the
  ! outer file reader can construct a valid record. No source-number setter.
  type, public :: swap_daily_weather_record_t
    private
    logical :: valid=.false.
    character(:), allocatable :: origin, raw_record, station, source_bytes
    integer :: calendar_day=0
    real(real64) :: tmin=0.0_real64, tmax=0.0_real64, rain=0.0_real64, etref=0.0_real64
  contains
    procedure :: ready => record_ready
    procedure :: values => record_values
    procedure :: same_input => record_same_input
    procedure :: same_source => record_same_source
  end type
  public :: read_swap_daily_weather_file, swap_weather_calendar_day
contains
  ! Gregorian ordinal, day 1 = 0001-01-01. Application time is explicitly
  ! bound by an explicit model calendar epoch in the application bootstrap.
  pure integer function swap_weather_calendar_day(year,month,day) result(ordinal)
    integer,intent(in)::year,month,day
    integer,parameter::days(12)=[31,28,31,30,31,30,31,31,30,31,30,31]
    integer::lengths(12),y
    ordinal=0
    if(year<1.or.year>9999.or.month<1.or.month>12) return
    lengths=days
    if(mod(year,4)==0.and.(mod(year,100)/=0.or.mod(year,400)==0)) lengths(2)=29
    if(day<1.or.day>lengths(month)) return
    y=year-1
    ordinal=365*y+y/4-y/100+y/400+sum(lengths(:month-1))+day
  end function
  logical function record_ready(self) result(ok)
    class(swap_daily_weather_record_t),intent(in)::self
    ok=self%valid
  end function
  subroutine record_values(self,day,tmin,tmax,rain_mm,etref_mm,available)
    class(swap_daily_weather_record_t),intent(in)::self
    real(real64),intent(out)::day,tmin,tmax,rain_mm,etref_mm
    logical,intent(out)::available
    day=real(self%calendar_day,real64);tmin=self%tmin;tmax=self%tmax
    rain_mm=self%rain;etref_mm=self%etref;available=self%ready()
  end subroutine
  logical function record_same_input(self,other) result(same)
    class(swap_daily_weather_record_t),intent(in)::self
    type(swap_daily_weather_record_t),intent(in)::other
    same=.false.
    if(.not.self%ready().or..not.other%ready()) return
    same=self%same_source(other).and.self%raw_record==other%raw_record.and. &
         self%station==other%station.and.self%calendar_day==other%calendar_day
  end function
  logical function record_same_source(self,other) result(same)
    class(swap_daily_weather_record_t),intent(in)::self
    type(swap_daily_weather_record_t),intent(in)::other
    same=.false.
    if(.not.self%ready().or..not.other%ready()) return
    same=self%origin==other%origin.and.self%source_bytes==other%source_bytes.and.self%station==other%station
  end function
  ! Restricted checked-in daily format: station DD MM YYYY RAD Tmin Tmax
  ! HUM WIND RAIN ETref wet. Wet is retained/validated as input, but this
  ! DAILY uniform-rate profile does not claim rainfall-duration semantics.
  subroutine read_swap_daily_weather_file(path,year,month,day,record,status)
    character(*),intent(in)::path
    integer,intent(in)::year,month,day
    type(swap_daily_weather_record_t),intent(out)::record
    integer,intent(out)::status
    type(swap_daily_weather_record_t)::candidate
    character(4096)::line
    character(64)::station,first_station
    integer::unit,ios,d,m,y,ordinal,target,previous,close_status,extra_status,nbytes,first,last,newline
    real(real64)::rad,tmin,tmax,hum,wind,rain,etref,wet,extra
    logical::found
    record=swap_daily_weather_record_t();status=SWAP_WEATHER_FILE_INVALID
    target=swap_weather_calendar_day(year,month,day)
    if(target==0.or.len_trim(path)==0) return
    status=SWAP_WEATHER_FILE_IO
    open(newunit=unit,file=path,status='old',action='read',access='stream',form='unformatted',iostat=ios)
    if(ios/=0) return
    inquire(unit=unit,size=nbytes,iostat=ios)
    if(ios/=0.or.nbytes<=0.or.nbytes>1048576) then
      close(unit,iostat=close_status)
      return
    end if
    allocate(character(nbytes)::candidate%source_bytes)
    read(unit,iostat=ios) candidate%source_bytes
    close(unit,iostat=close_status)
    if(ios/=0.or.close_status/=0) return
    ! The exact source bytes are retained as immutable input authority. This
    ! bounded reader caps input to 1 MiB; it is not a scalable weather archive.
    previous=0;first_station='';found=.false.
    status=SWAP_WEATHER_FILE_INVALID
    first=1
    do
      if(first>nbytes) exit
      newline=index(candidate%source_bytes(first:),achar(10))
      last=nbytes
      if(newline/=0) last=first+newline-2
      if(last-first+1>=len(line)) return
      line=candidate%source_bytes(first:last)
      first=last+2
      ! Reject truncation, null/repetition/slash list-directed shortcuts and
      ! extra fields rather than accepting partially initialized records.
      if(len_trim(line)>=len(line)) goto 900
      line=adjustl(line)
      if(len_trim(line)==0) cycle
      if(line(1:1)=='*'.or.index(line,'Station')==1) cycle
      if(index(line,'/ ')/=0.or.index(line,'/')/=0.or.index(line,',')/=0) goto 900
      if(index(line,'*')/=0) goto 900
      read(line,*,iostat=ios) station,d,m,y,rad,tmin,tmax,hum,wind,rain,etref,wet
      if(ios/=0) goto 900
      read(line,*,iostat=extra_status) station,d,m,y,rad,tmin,tmax,hum,wind,rain,etref,wet,extra
      if(extra_status/=iostat_end) goto 900
      ordinal=swap_weather_calendar_day(y,m,d)
      if(ordinal==0.or.len_trim(station)==0) goto 900
      if(.not.all(ieee_is_finite([rad,tmin,tmax,hum,wind,rain,etref,wet]))) goto 900
      if(max(abs(tmin),abs(tmax))>huge(tmin)*0.5_real64) goto 900
      if(tmin>tmax.or.min(rad,hum,wind,rain,etref,wet)<0.0_real64.or.wet>1.0_real64) goto 900
      if(previous/=0) then
        if(ordinal/=previous+1.or.station/=first_station) goto 900
      else
        first_station=station
      end if
      previous=ordinal
      if(ordinal/=target) cycle
      if(found) goto 900
      candidate%origin=path;candidate%raw_record=trim(line);candidate%station=trim(station)
      candidate%calendar_day=ordinal;candidate%tmin=tmin;candidate%tmax=tmax
      candidate%rain=rain;candidate%etref=etref;candidate%valid=.true.;found=.true.
    end do
    status=SWAP_WEATHER_FILE_MISSING
    if(.not.found) return
    record=candidate;status=SWAP_WEATHER_FILE_OK
    return
900 return
  end subroutine
end module
