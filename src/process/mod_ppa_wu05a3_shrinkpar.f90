module mod_ppa_wu05a3_shrinkpar
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_OK = 0
  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_SHRINKPAR_SOURCE_ERROR = 2
  public :: ppa_wu05a3_clay_reference_moisture
  public :: ppa_wu05a3_clay_typical_points

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

  pure subroutine ppa_wu05a3_clay_typical_points(theta_s, alpha, moisture_at_reference, beta, gamma, &
       derived_reference, status)
    real(real64), intent(in) :: theta_s, alpha, moisture_at_reference
    real(real64), intent(out) :: beta, gamma, derived_reference
    integer, intent(out) :: status
    real(real64) :: beta_previous, beta_current, function_value, derivative, moisture_product
    integer :: iteration

    beta = 0.0_real64
    gamma = 0.0_real64
    derived_reference = 0.0_real64
    status = PPA_WU05A3_SHRINKPAR_INVALID_INPUT
    if (.not. ieee_is_finite(theta_s) .or. .not. ieee_is_finite(alpha) .or. &
        .not. ieee_is_finite(moisture_at_reference)) return
    ! B1.11 SHRINKPAR task 2. The legacy Newton loop has no cap; a bounded
    ! convergent domain and iteration guard turn invalid/nonconvergent inputs into rejection.
    if (theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. alpha <= 0.0_real64 .or. &
        alpha > 10.0_real64 .or. moisture_at_reference <= 0.0_real64 .or. &
        moisture_at_reference > 100.0_real64) return
    if (alpha > moisture_at_reference) then
      status = PPA_WU05A3_SHRINKPAR_SOURCE_ERROR
      return
    end if
    if (alpha >= moisture_at_reference) return
    if (moisture_at_reference > theta_s/(1.0_real64-theta_s)-0.01_real64) then
      status = PPA_WU05A3_SHRINKPAR_SOURCE_ERROR
      return
    end if
    if (moisture_at_reference/alpha < 1.01_real64) return

    beta_current = -log(moisture_at_reference/alpha) / moisture_at_reference
    beta_previous = beta_current + 1.0_real64
    iteration = 0
    do while (abs(beta_current-beta_previous) > 0.001_real64 .and. iteration < 10000)
      iteration = iteration + 1
      beta_previous = beta_current
      moisture_product = beta_previous * moisture_at_reference
      function_value = (alpha + alpha*moisture_at_reference*beta_previous) * exp(-moisture_product)
      derivative = (-alpha*moisture_at_reference*moisture_at_reference*beta_previous) * &
           exp(-moisture_product)
      if (abs(derivative) <= tiny(1.0_real64)) return
      beta_current = beta_previous - function_value/derivative
      if (.not. ieee_is_finite(beta_current)) return
    end do
    if (iteration >= 10000) return

    beta = beta_current
    gamma = 1.0_real64 + alpha*beta*exp(-beta*moisture_at_reference)
    derived_reference = moisture_at_reference
    if (.not. ieee_is_finite(gamma)) then
      beta = 0.0_real64
      gamma = 0.0_real64
      derived_reference = 0.0_real64
      return
    end if
    status = PPA_WU05A3_SHRINKPAR_OK
  end subroutine ppa_wu05a3_clay_typical_points

end module mod_ppa_wu05a3_shrinkpar
