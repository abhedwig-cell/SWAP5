module mod_crop_weather_day_owner
  use iso_fortran_env, only: real64,int64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: WEATHER_DAY_OK=0, WEATHER_DAY_INVALID=1, &
       WEATHER_DAY_STALE=2, WEATHER_DAY_DUPLICATE=3, WEATHER_DAY_SOURCE=4, &
       WEATHER_DAY_CONFLICT=5
  type, public :: weather_day_owner_t
    private
    integer(int64) :: source=0_int64, epoch=0_int64, revision=0_int64
    real(real64) :: day=0.0_real64, tmin=0.0_real64, tmax=0.0_real64, tav=0.0_real64
    logical :: active=.false., has_day=.false.
  contains
    procedure :: read_day => weather_owner_read_day
    procedure :: snapshot => weather_owner_snapshot
  end type
  public :: initialize_weather_day_owner, ingest_weather_day, reconstruct_weather_day_owner, validate_weather_day_forcing_span
contains
  subroutine initialize_weather_day_owner(owner,source,epoch,status)
    type(weather_day_owner_t),intent(out)::owner
    integer(int64),intent(in)::source,epoch
    integer,intent(out)::status
    owner=weather_day_owner_t();status=WEATHER_DAY_INVALID
    if(source<=0_int64.or.epoch<=0_int64) return
    owner%source=source;owner%epoch=epoch;owner%active=.true.
    status=WEATHER_DAY_OK
  end subroutine
  subroutine ingest_weather_day(owner,source,epoch,day,tmin,tmax,status)
    type(weather_day_owner_t),intent(inout)::owner
    integer(int64),intent(in)::source,epoch
    real(real64),intent(in)::day,tmin,tmax
    integer,intent(out)::status
    real(real64)::tav
    status=WEATHER_DAY_INVALID
    if(.not.owner%active) return
    if(.not.ieee_is_finite(day).or..not.ieee_is_finite(tmin).or..not.ieee_is_finite(tmax)) return
    if(tmin>tmax.or.day/=anint(day)) return
    status=WEATHER_DAY_SOURCE
    if(source/=owner%source.or.epoch/=owner%epoch) return
    if(owner%has_day) then
      if(day==owner%day) then
        status=WEATHER_DAY_DUPLICATE
        if (transfer(tmin,0_int64)==transfer(owner%tmin,0_int64).and. &
            transfer(tmax,0_int64)==transfer(owner%tmax,0_int64)) return
        status=WEATHER_DAY_CONFLICT
        return
      end if
      status=WEATHER_DAY_STALE
      if(day/=owner%day+1.0_real64) return
    end if
    status=WEATHER_DAY_INVALID
    if(owner%revision==huge(owner%revision)) return
    ! B1.11 task 22 arithmetic order, not WOFOST daytime temperature.
    tav=(tmax+tmin)*0.5_real64
    if(.not.ieee_is_finite(tav)) return
    owner%day=day;owner%tmin=tmin;owner%tmax=tmax;owner%tav=tav
    owner%revision=owner%revision+1_int64;owner%has_day=.true.
    status=WEATHER_DAY_OK
  end subroutine
  subroutine weather_owner_read_day(self,source,epoch,revision,day,tav,status,tmin,tmax)
    class(weather_day_owner_t),intent(in)::self
    integer(int64),intent(in)::source,epoch,revision
    real(real64),intent(in)::day
    real(real64),intent(out)::tav
    integer,intent(out)::status
    real(real64),intent(out),optional::tmin,tmax
    tav=0.0_real64;status=WEATHER_DAY_INVALID
    if(present(tmin)) tmin=0.0_real64
    if(present(tmax)) tmax=0.0_real64
    if(.not.self%active.or..not.self%has_day) return
    if(.not.ieee_is_finite(day)) return
    status=WEATHER_DAY_SOURCE
    if(source/=self%source.or.epoch/=self%epoch) return
    status=WEATHER_DAY_STALE
    if(revision/=self%revision.or.day/=self%day) return
    tav=self%tav
    if(present(tmin)) tmin=self%tmin
    if(present(tmax)) tmax=self%tmax
    status=WEATHER_DAY_OK
  end subroutine
  ! Read-only handoff guard for a hydrological forcing interval. The
  ! interval must belong to the very same recorded meteorological day used
  ! by crop daystart. This does not certify an upstream weather producer or
  ! change the hydrological forcing values.
  subroutine validate_weather_day_forcing_span(owner,source,epoch,revision,day,t0,t1,tav,status)
    type(weather_day_owner_t),intent(in)::owner
    integer(int64),intent(in)::source,epoch,revision
    real(real64),intent(in)::day,t0,t1
    real(real64),intent(out)::tav
    integer,intent(out)::status
    tav=0.0_real64
    status=WEATHER_DAY_INVALID
    if(.not.ieee_is_finite(day).or..not.ieee_is_finite(t0).or..not.ieee_is_finite(t1)) return
    if(day/=anint(day).or.t0<day.or.t1<=t0.or.t1>day+1.0_real64) return
    call owner%read_day(source,epoch,revision,day,tav,status)
  end subroutine validate_weather_day_forcing_span
  subroutine weather_owner_snapshot(self,source,epoch,revision,day,tmin,tmax,available)
    class(weather_day_owner_t),intent(in)::self
    integer(int64),intent(out)::source,epoch,revision
    real(real64),intent(out)::day,tmin,tmax
    logical,intent(out)::available
    source=self%source;epoch=self%epoch;revision=self%revision
    day=self%day;tmin=self%tmin;tmax=self%tmax
    available=self%active.and.self%has_day
  end subroutine
  ! Trusted restart still requires matching source and epoch supplied by the real
  ! input owner. This is a reconstructible local record, NOT a sealed weather
  ! provenance certificate and cannot authorize physical event publication.
  subroutine reconstruct_weather_day_owner(owner,source,epoch,revision,day,tmin,tmax,status)
    type(weather_day_owner_t),intent(out)::owner
    integer(int64),intent(in)::source,epoch,revision
    real(real64),intent(in)::day,tmin,tmax
    integer,intent(out)::status
    integer::s
    owner=weather_day_owner_t();status=WEATHER_DAY_INVALID
    if(revision<1_int64) return
    call initialize_weather_day_owner(owner,source,epoch,s)
    if(s/=WEATHER_DAY_OK) return
    call ingest_weather_day(owner,source,epoch,day,tmin,tmax,s)
    if(s/=WEATHER_DAY_OK) then
      owner=weather_day_owner_t();return
    end if
    owner%revision=revision;status=WEATHER_DAY_OK
  end subroutine
end module
