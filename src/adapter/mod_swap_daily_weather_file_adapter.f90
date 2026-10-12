module mod_swap_daily_weather_file_adapter
  use iso_fortran_env, only: real64, int64, iostat_end
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: SWAP_WEATHER_FILE_OK=0, SWAP_WEATHER_FILE_INVALID=1, &
       SWAP_WEATHER_FILE_IO=2, SWAP_WEATHER_FILE_MISSING=3
  ! Fully populated typed AFGEN table; immutable after construction/copy.
  type, public :: swap_raintb_t
    private
    real(real64), allocatable :: knots(:), intensities(:)
  contains
    procedure :: ready => raintb_ready
    procedure :: same_input => raintb_same_input
  end type
  public :: construct_swap_raintb, resolve_swap_raintb_pulse
  ! Immutable input, not a meteorological or physical state owner. Only the
  ! outer file reader can construct a valid record. No source-number setter.
  type, public :: swap_daily_weather_record_t
    private
    logical :: valid=.false.
    character(:), allocatable :: origin, raw_record, station, source_bytes
    integer :: calendar_day=0, day_of_year=0
    real(real64) :: tmin=0.0_real64, tmax=0.0_real64, rain=0.0_real64, etref=0.0_real64, radiation_kj=0.0_real64, vapour_pressure_kpa=0.0_real64, wind_speed_m_s=0.0_real64
  contains
    procedure :: ready => record_ready
    procedure :: values => record_values
    procedure :: pm_values => record_pm_values
    procedure :: rain_segment => record_rain_segment
    procedure :: growth_values => record_growth_values
    procedure :: same_input => record_same_input
    procedure :: same_source => record_same_source
  end type
  public :: read_swap_daily_weather_file, swap_weather_calendar_day
contains
  subroutine record_pm_values(self,doy,radiation,vapour_pressure,wind,available)
    class(swap_daily_weather_record_t),intent(in)::self
    integer,intent(out)::doy
    real(real64),intent(out)::radiation,vapour_pressure,wind
    logical,intent(out)::available
    doy=0;radiation=0.0_real64;vapour_pressure=0.0_real64;wind=0.0_real64;available=.false.
    if(.not.self%ready()) return
    if(self%radiation_kj>huge(radiation)/1000.0_real64) return
    doy=self%day_of_year;radiation=self%radiation_kj*1000.0_real64
    vapour_pressure=self%vapour_pressure_kpa;wind=self%wind_speed_m_s;available=.true.
  end subroutine
  subroutine construct_swap_raintb(knots,intensities,table,status)
    real(real64),intent(in)::knots(:),intensities(:)
    type(swap_raintb_t),intent(out)::table
    integer,intent(out)::status
    integer::i,n
    real(real64)::dx,dy
    table=swap_raintb_t();status=SWAP_WEATHER_FILE_INVALID
    n=size(knots)
    if(n<1.or.size(intensities)/=n) return
    if(.not.all(ieee_is_finite(knots)).or..not.all(ieee_is_finite(intensities))) return
    if(any(knots<1.0_real64).or.any(knots>366.0_real64).or.any(intensities<=0.0_real64)) return
    do i=2,n
      dx=knots(i)-knots(i-1)
      if(dx<=0.0_real64) return
      dy=abs(intensities(i)-intensities(i-1))
      if(dx<1.0_real64) then
        if(dy>huge(dx)*dx) return
      end if
    end do
    table%knots=knots;table%intensities=intensities;status=SWAP_WEATHER_FILE_OK
  end subroutine
  logical function raintb_ready(self) result(ok)
    class(swap_raintb_t),intent(in)::self
    ok=.false.
    if(.not.allocated(self%knots).or..not.allocated(self%intensities)) return
    ok=size(self%knots)>0.and.size(self%knots)==size(self%intensities)
  end function
  logical function raintb_same_input(self,other) result(ok)
    class(swap_raintb_t),intent(in)::self
    type(swap_raintb_t),intent(in)::other
    ok=.false.
    if(.not.self%ready().or..not.other%ready()) return
    if(size(self%knots)/=size(other%knots)) return
    ok=all(self%knots==other%knots).and.all(self%intensities==other%intensities)
  end function
  subroutine resolve_swap_raintb_pulse(table,day_of_year,rain_mm,duration,rate,status)
    type(swap_raintb_t),intent(in)::table
    integer,intent(in)::day_of_year
    real(real64),intent(in)::rain_mm
    real(real64),intent(out)::duration,rate
    integer,intent(out)::status
    real(real64)::x,rflx,slope
    integer::i,n
    duration=0.0_real64;rate=0.0_real64;status=SWAP_WEATHER_FILE_INVALID
    if(.not.table%ready().or.day_of_year<1.or.day_of_year>366) return
    if(.not.ieee_is_finite(rain_mm)) return
    if(rain_mm<0.0_real64) return
    status=SWAP_WEATHER_FILE_OK
    ! Literal MOD_meteo event threshold is in millimetres, before conversion.
    if(rain_mm<=1.0d-8) return
    x=real(day_of_year,real64);n=size(table%knots)
    rflx=table%intensities(n)
    if(table%knots(1)>=x) then
      rflx=table%intensities(1)
    else
      do i=2,n
        if(table%knots(i)>=x) then
          ! Retain AFGEN expression order, including its slope operation.
          slope=(table%intensities(i)-table%intensities(i-1))/(table%knots(i)-table%knots(i-1))
          rflx=table%intensities(i-1)+(x-table%knots(i-1))*slope
          exit
        end if
      end do
    end if
    if(rflx<1.0_real64) then
      if(rain_mm*0.1d0>huge(rflx)*rflx) then
        status=SWAP_WEATHER_FILE_INVALID;return
      end if
    end if
    duration=dmin1(1.d0,rain_mm*0.1d0/rflx)
    if(.not.ieee_is_finite(duration).or.duration<=0.0_real64) then
      status=SWAP_WEATHER_FILE_INVALID;return
    end if
    if(duration<1.0_real64) then
      if(rain_mm*0.1d0>huge(duration)*duration) then
        status=SWAP_WEATHER_FILE_INVALID;return
      end if
    end if
    rate=rain_mm*0.1d0/duration
    if(.not.ieee_is_finite(rate)) status=SWAP_WEATHER_FILE_INVALID
  end subroutine
  subroutine record_rain_segment(self,table,epoch,t0,t1,rate,segment_end,status)
    class(swap_daily_weather_record_t),intent(in)::self
    type(swap_raintb_t),intent(in)::table
    integer,intent(in)::epoch
    real(real64),intent(in)::t0,t1
    real(real64),intent(out)::rate,segment_end
    integer,intent(out)::status
    real(real64)::day,duration,pulse_end
    rate=0.0_real64;segment_end=t0;status=SWAP_WEATHER_FILE_INVALID
    if(.not.self%ready().or.epoch<1) return
    if(.not.all(ieee_is_finite([t0,t1]))) return
    day=real(self%calendar_day-epoch,real64)
    if(t0<day.or.t1>day+1.0_real64.or.t1<=t0) return
    call resolve_swap_raintb_pulse(table,self%day_of_year,self%rain,duration,rate,status)
    if(status/=SWAP_WEATHER_FILE_OK) return
    pulse_end=day+duration
    if(duration>0.0_real64.and.pulse_end<=day) then
      status=SWAP_WEATHER_FILE_INVALID;return
    end if
    segment_end=t1
    if(t0<pulse_end) then
      segment_end=min(t1,pulse_end)
    else
      rate=0.0_real64
    end if
  end subroutine
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
  ! Same immutable file record. Source RAD is kJ/m2/day, converted once
  ! in the literal historical order; astronomy is stateless, not an owner.
  subroutine record_growth_values(self,latitude,iday,rad,solar,available)
    class(swap_daily_weather_record_t),intent(in)::self
    real(real64),intent(in)::latitude
    integer,intent(out)::iday
    real(real64),intent(out)::rad,solar(6)
    logical,intent(out)::available
    real(real64),parameter::pi=3.141592653589793238462643383279502884197d0,radial=pi/180.d0,angle=-4.d0
    real(real64)::lat,dec,sc,aob,aob_corr,angot,dsinb,frdif
    real(real64)::atmtr_,dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_
    available=.false.;iday=0;rad=0.0_real64;solar=0.0_real64
    if(.not.self%ready()) return
    if(.not.ieee_is_finite(latitude)) return
    ! Historical detailed crop at |latitude| > 66.5 is outside this profile.
    if(abs(latitude)>66.5_real64) return
    if(self%radiation_kj>huge(rad)/1000.d0) return
    iday=self%day_of_year;lat=latitude;rad=1000.d0*self%radiation_kj

      dec = -asin(dsin(23.45d0 * radial) * dcos(2.d0 * pi * dble(iday + 10.d0) / 365.d0))
      sc = 1370.d0*(1.d0 + 0.033d0 * dcos(2.d0 * pi * dble(iday) / 365.d0))

      ! calculation of daylength from intermediate variables (sinld, cosld, aob)
      sinld_ = dsin(radial * lat) * dsin(dec)
      cosld_ = dcos(radial * lat) * dcos(dec)
      aob = sinld_ / cosld_

      ! For very high latitudes and days in summer and winter a limit is
      ! inserted to avoid math errors when daylength reaches 24 hours in
      ! summer or 0 hours in winter.

      ! calculate solution for base=0 degrees
      if (dabs(aob) <= 1.d0) then
        
         dayl_  = 12.d0 * (1.d0 + 2.d0 * asin(aob) / pi)
        
         ! integrals of sine of solar height
         dsinb  = 3600.d0 * (dayl_ * sinld_ + 24.d0 * cosld_ * dsqrt(1.d0 - aob**2) / pi)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)) + &
                  12.d0 * cosld_ * (2.d0 + 3.d0 * 0.4d0 * sinld_) * dsqrt(1.d0 - aob**2) / pi)
      else
        
         if (aob > 1.d0)  dayl_ = 24.d0
         if (aob < -1.d0) dayl_ = 0.d0

         ! integrals of sine of solar height      
         dsinb = 3600.d0 * (dayl_ * sinld_)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)))
      end if

      ! calculate solution for base=-4 (ANGLE) degrees
      aob_corr = (-dsin(angle * radial) + sinld_) / cosld_
      if (dabs(aob_corr) <= 1.0d0) then 
         daylp_ = 12.d0 * (1.d0 + 2.d0 * asin(aob_corr) / pi)
      else
         if (aob_corr > 1.0d0)  daylp_ = 24.d0
         if (aob_corr < -1.0d0) daylp_ = 0.d0
      end if

      ! extraterrestrial radiation and atmospheric transmission
      angot = sc * dsinb

      ! check for DAYL=0 as in that case the angot radiation is 0 as well
      if (dayl_ > 0.d0) then
         atmtr_ = rad / angot
      else
         atmtr_ = 0.d0
      end if

      ! estimate fraction diffuse irradiation
      if (atmtr_ > 0.75d0) frdif = 0.23d0
      if (atmtr_ <= 0.75d0 .AND. atmtr_ > 0.35d0) frdif = 1.33d0 - 1.46d0 * atmtr_
      if (atmtr_ <= 0.35d0 .AND. atmtr_ > 0.07d0) frdif = 1.d0 - 2.3d0 * (atmtr_ - 0.07d0)**2
      if (atmtr_ <= 0.07d0) frdif = 1.d0

      difpp_ = frdif * atmtr_ * 0.5d0 * sc

    solar=[dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_]
    if(.not.all(ieee_is_finite(solar))) return
    available=.true.
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
      candidate%day_of_year=ordinal-swap_weather_calendar_day(y,1,1)+1
      candidate%radiation_kj=rad
      candidate%vapour_pressure_kpa=hum;candidate%wind_speed_m_s=wind
      candidate%rain=rain;candidate%etref=etref;candidate%valid=.true.;found=.true.
    end do
    status=SWAP_WEATHER_FILE_MISSING
    if(.not.found) return
    record=candidate;status=SWAP_WEATHER_FILE_OK
    return
900 return
  end subroutine
end module
