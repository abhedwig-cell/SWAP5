module mod_ppa_wu05a3_shrinkpar
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_OK = 0
  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_SOURCE_ERROR = 2
  public :: ppa_wu05a3_clay_reference_moisture

contains

  pure subroutine ppa_wu05a3_clay_reference_moisture(theta_s, alpha, beta, gamma, moisture_reference, status)
    real(real64), intent(in) :: theta_s, alpha, beta, gamma
    real(real64), intent(out) :: moisture_reference
    integer, intent(out) :: status
    real(real64) :: log_argument, upper_limit

    moisture_reference = 0.0_real64
    status = PPA_WU05A3_SHRINKPAR_INVALID_INPUT
    if (.not. ieee_is_finite(theta_s) .or. .not. ieee_is_finite(alpha) .or. &
        .not. ieee_is_finite(beta) .or. .not. ieee_is_finite(gamma)) return
    ! B1.11 macropore.f90 SHRINKPAR task 1; input ranges follow the parser.
    if (theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. alpha <= 0.0_real64 .or. &
        alpha > 10.0_real64 .or. abs(beta) < 1.0e-12_real64 .or. beta < -10.0_real64 .or. &
        beta > 100.0_real64 .or. gamma < -10.0_real64 .or. gamma > 100.0_real64) return

    log_argument = (gamma - 1.0_real64) / (alpha * beta)
    if (.not. ieee_is_finite(log_argument)) return
    if (log_argument <= 0.0_real64) return
    moisture_reference = -log(log_argument) / beta
    upper_limit = theta_s / (1.0_real64 - theta_s) - 0.01_real64
    if (.not. ieee_is_finite(moisture_reference)) then
      moisture_reference = 0.0_real64
      return
    end if
    if (moisture_reference > upper_limit) then
      moisture_reference = 0.0_real64
      status = PPA_WU05A3_SHRINKPAR_SOURCE_ERROR
      return
    end if
    status = PPA_WU05A3_SHRINKPAR_OK
  end subroutine ppa_wu05a3_clay_reference_moisture

end module mod_ppa_wu05a3_shrinkpar
