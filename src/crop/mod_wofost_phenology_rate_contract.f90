module mod_wofost_phenology_rate_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: WOFOST_PHENOLOGY_RATE_OK=0
  integer, parameter, public :: WOFOST_PHENOLOGY_RATE_INVALID=1

  type, public :: wofost_phenology_rate_t
    real(real64) :: temperature_sum_increment=0.0_real64
    real(real64) :: development_rate=0.0_real64
  contains
    procedure, public :: validate=>wofost_phenology_rate_validate
  end type

contains

  integer function wofost_phenology_rate_validate(self) result(status)
    class(wofost_phenology_rate_t), intent(in) :: self
    status=WOFOST_PHENOLOGY_RATE_INVALID
    if(.not.ieee_is_finite(self%temperature_sum_increment).or.self%temperature_sum_increment<0.0_real64)return
    if(.not.ieee_is_finite(self%development_rate).or.self%development_rate<0.0_real64)return
    status=WOFOST_PHENOLOGY_RATE_OK
  end function

end module mod_wofost_phenology_rate_contract
