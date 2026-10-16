module mod_crop_tav_meteorological_candidate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_TAV_METEO_OK=0, CROP_TAV_METEO_INVALID=1
  public :: crop_tav_from_daily_minmax_candidate, crop_tav_from_uniform_detail_candidate
contains
  ! Candidate only: older SWAP meteoday daily air temperature is the arithmetic
  ! mean of minimum and maximum air temperature. B1.11 exchange task 22
  ! writes tav=(tmx+tmn)*0.5d0; preserve this operation order exactly.
  ! Caller input is not an accepted owner receipt.
  pure subroutine crop_tav_from_daily_minmax_candidate(tmin,tmax,tav,status)
    real(real64), intent(in) :: tmin,tmax
    real(real64), intent(out) :: tav
    integer, intent(out) :: status
    tav=0.0_real64
    status=CROP_TAV_METEO_INVALID
    if (.not.ieee_is_finite(tmin).or..not.ieee_is_finite(tmax)) return
    if (tmin>tmax) return
    tav=(tmax+tmin)*0.5_real64
    if (.not.ieee_is_finite(tav)) then
      tav=0.0_real64
      return
    end if
    status=CROP_TAV_METEO_OK
  end subroutine

  ! Candidate only: equal-duration full-day detailed temperatures. No
  ! interpolation, imputation, or weather source/acceptance certification.
  pure subroutine crop_tav_from_uniform_detail_candidate(temperatures,tav,status)
    real(real64), intent(in) :: temperatures(:)
    real(real64), intent(out) :: tav
    integer, intent(out) :: status
    real(real64) :: accum
    integer :: i
    tav=0.0_real64
    status=CROP_TAV_METEO_INVALID
    if (size(temperatures)<1.or.size(temperatures)>96) return
    if (.not.all(ieee_is_finite(temperatures))) return
    accum=0.0_real64
    do i=1,size(temperatures)
      accum=accum+temperatures(i)/real(size(temperatures),real64)
    end do
    if (.not.ieee_is_finite(accum)) return
    tav=accum
    status=CROP_TAV_METEO_OK
  end subroutine
end module
