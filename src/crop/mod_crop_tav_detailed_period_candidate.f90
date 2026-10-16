module mod_crop_tav_detailed_period_candidate
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_TAV_PERIOD_OK=0,CROP_TAV_PERIOD_INVALID=1
  public :: crop_tav_from_detailed_period_candidate
contains
  ! Source-shape probe only. The unofficial refactored SWAP meteoday
  ! ProcessMeteoDay calculates sum(atav(i))*metperiod.
  ! This does NOT attest exact B1.11 MOD_meteo or weather-owner provenance.
  subroutine crop_tav_from_detailed_period_candidate(temperatures,metperiod,tav,status)
    real(real64),intent(in) :: temperatures(:),metperiod
    real(real64),intent(out) :: tav
    integer,intent(out) :: status
    real(real64):: accumulated
    integer:: i,n
    tav=0.0_real64
    status=CROP_TAV_PERIOD_INVALID
    n=size(temperatures)
    if(n<1.or.n>96) return
    if(.not.ieee_is_finite(metperiod)) return
    if(metperiod<=0.0_real64.or.metperiod>1.0_real64) return
    if(abs(real(n,real64)*metperiod-1.0_real64)>32.0_real64*epsilon(metperiod)) return
    if(.not.all(ieee_is_finite(temperatures))) return
    accumulated=0.0_real64
    do i=1,n
      accumulated=accumulated+temperatures(i)
    end do
    tav=accumulated*metperiod
    if(.not.ieee_is_finite(tav)) then
      tav=0.0_real64
      return
    end if
    status=CROP_TAV_PERIOD_OK
  end subroutine
end module
