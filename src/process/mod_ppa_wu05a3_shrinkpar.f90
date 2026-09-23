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
  public :: ppa_wu05a3_peat_typical_points

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

  pure subroutine ppa_wu05a3_peat_typical_points(theta_s, void_at_zero, moisture_b, moisture_c, &
       moisture_d, shape_p, alpha, beta, status)
    real(real64), intent(in) :: theta_s, void_at_zero, moisture_b, moisture_c, moisture_d, shape_p
    real(real64), intent(out) :: alpha, beta
    integer, intent(out) :: status
    real(real64) :: c1, c2, c3, inverse_vp, void_at_transition, void_at_reference
    real(real64) :: alpha_max, alpha_min, alpha_previous, alpha_current
    real(real64) :: fa, ga, ha, function_value, derivative, delta
    integer :: iteration

    alpha = 0.0_real64
    beta = 0.0_real64
    status = PPA_WU05A3_SHRINKPAR_INVALID_INPUT
    if (.not. all(ieee_is_finite([theta_s,void_at_zero,moisture_b,moisture_c,moisture_d,shape_p]))) return
    ! B1.11 macropore.f90 SHRINKPAR task 4. The source's unbounded Newton loop
    ! is reproduced on a finite, nonsingular parameter domain with a hard cap.
    if (theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. void_at_zero < 0.0_real64 .or. &
        void_at_zero > 10.0_real64 .or. moisture_b <= 0.0_real64 .or. moisture_b > 100.0_real64 .or. &
        moisture_c <= 0.0_real64 .or. moisture_c > 100.0_real64 .or. moisture_d <= 0.0_real64 .or. &
        moisture_d > 100.0_real64 .or. abs(shape_p) < 1.0e-12_real64 .or. abs(shape_p) > 10.0_real64) return
    inverse_vp = moisture_d / moisture_b
    if (inverse_vp <= 0.0_real64) return
    c1 = 1.0_real64 / inverse_vp
    c2 = moisture_c / moisture_d
    if (c1 <= 1.0_real64 .or. c1 > 10.0_real64 .or. c2 <= 0.0_real64 .or. c2 >= c1) return
    if (abs(c1-c2) < 1.0e-10_real64 .or. abs(c1-1.0_real64) < 1.0e-10_real64) return

    void_at_transition = void_at_zero + (theta_s/(1.0_real64-theta_s)-void_at_zero) * &
         moisture_c / (theta_s/(1.0_real64-theta_s))
    if (shape_p > 0.0_real64) then
      void_at_reference = void_at_zero + moisture_c
    else
      void_at_reference = 0.5_real64*void_at_zero + moisture_c
    end if
    c3 = (void_at_reference/void_at_transition - 1.0_real64) / shape_p
    if (.not. ieee_is_finite(c3)) return
    if (abs(shape_p) > 0.33_real64) then
      alpha_current = 0.5_real64
    else
      alpha_current = 0.9_real64
    end if
    alpha_previous = alpha_current + 1.0_real64
    alpha_max = 10.0_real64
    alpha_min = 0.001_real64
    iteration = 0
    do while (abs(alpha_current-alpha_previous) > 0.001_real64 .and. iteration < 10000)
      iteration = iteration + 1
      alpha_previous = alpha_current
      fa = c2**alpha_previous
      ga = exp((c1-c2)*alpha_previous)-1.0_real64
      ha = exp((c1-1.0_real64)*alpha_previous)-1.0_real64
      if (abs(ha) <= tiny(1.0_real64)) return
      function_value = fa*ga/ha-c3
      derivative = fa*(ga*(1.0_real64+log(c2)-c2-(c1-1.0_real64)/ha)+(c1-c2))/ha
      if (.not. ieee_is_finite(function_value) .or. .not. ieee_is_finite(derivative)) return
      if (abs(derivative) <= tiny(1.0_real64)) return
      alpha_current = alpha_previous-function_value/derivative
      if (.not. ieee_is_finite(alpha_current)) return
      delta = abs(alpha_current-alpha_previous)
      if (delta > 1.0e-2_real64) then
        if (alpha_current > alpha_previous) then
          if (alpha_previous > alpha_min .and. alpha_previous < alpha_max-1.0e-3_real64) then
            alpha_min = alpha_previous
          else
            alpha_current = (alpha_min+min(alpha_current,alpha_max-1.0e-2_real64))/2.0_real64
          end if
          alpha_current = min(alpha_current,alpha_max)
        else if (alpha_current < alpha_previous) then
          if (alpha_previous < alpha_max .and. alpha_previous > alpha_min+1.0e-3_real64) then
            alpha_max = alpha_previous
          else
            alpha_current = (alpha_max+max(alpha_current,alpha_min+1.0e-2_real64))/2.0_real64
          end if
          alpha_current = max(alpha_current,alpha_min)
        end if
      end if
    end do
    if (iteration >= 10000) return
    alpha = alpha_current
    beta = alpha_current/inverse_vp
    if (.not. ieee_is_finite(beta)) then
      alpha = 0.0_real64
      beta = 0.0_real64
      return
    end if
    status = PPA_WU05A3_SHRINKPAR_OK
  end subroutine ppa_wu05a3_peat_typical_points

end module mod_ppa_wu05a3_shrinkpar
