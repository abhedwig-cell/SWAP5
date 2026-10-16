module mod_crop_atmospheric_co2_forcing
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_swap_daily_weather_file_adapter, only: swap_weather_calendar_day
  implicit none
  private
  integer, parameter, public :: CROP_ATMOSPHERIC_CO2_OK=0, CROP_ATMOSPHERIC_CO2_INVALID=1, &
       CROP_ATMOSPHERIC_CO2_MISSING_YEAR=2
  ! Immutable forcing, not crop state. Historical CO2year selects exactly one
  ! year's ppm; it does not interpolate concentrations across years.
  type, public :: crop_atmospheric_co2_forcing_t
    private
    integer, allocatable :: years(:)
    real(real64), allocatable :: concentrations(:)
  contains
    procedure :: ready => atmospheric_co2_ready
    procedure :: resolve => atmospheric_co2_resolve
  end type
  public :: construct_crop_atmospheric_co2_forcing
contains
  subroutine construct_crop_atmospheric_co2_forcing(years,ppm,forcing,status)
    integer,intent(in)::years(:)
    real(real64),intent(in)::ppm(:)
    type(crop_atmospheric_co2_forcing_t),intent(out)::forcing
    integer,intent(out)::status
    forcing=crop_atmospheric_co2_forcing_t()
    status=CROP_ATMOSPHERIC_CO2_INVALID
    if(size(years)<1.or.size(years)/=size(ppm))return
    if(any(years<1000).or.any(years>3000))return
    if(.not.all(ieee_is_finite(ppm)))return
    if(any(ppm<10.0_real64).or.any(ppm>3000.0_real64))return
    if(any(years(2:)<=years(:size(years)-1)))return
    forcing%years=years;forcing%concentrations=ppm
    status=CROP_ATMOSPHERIC_CO2_OK
  end subroutine
  logical function atmospheric_co2_ready(self) result(ok)
    class(crop_atmospheric_co2_forcing_t),intent(in)::self
    ok=allocated(self%years).and.allocated(self%concentrations)
  end function
  subroutine atmospheric_co2_resolve(self,calendar_day,ppm,status)
    class(crop_atmospheric_co2_forcing_t),intent(in)::self
    integer,intent(in)::calendar_day
    real(real64),intent(out)::ppm
    integer,intent(out)::status
    integer::i
    ppm=0.0_real64;status=CROP_ATMOSPHERIC_CO2_INVALID
    if(.not.self%ready())return
    status=CROP_ATMOSPHERIC_CO2_MISSING_YEAR
    do i=1,size(self%years)
      if(calendar_day<swap_weather_calendar_day(self%years(i),1,1))exit
      if(calendar_day>=swap_weather_calendar_day(self%years(i)+1,1,1))cycle
      ppm=self%concentrations(i);status=CROP_ATMOSPHERIC_CO2_OK;return
    end do
  end subroutine
end module
