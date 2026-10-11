module mod_rfm_unponded_activation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: RFM_ACTIVATION_NOT_RUN = 0
  integer, parameter, public :: RFM_ACTIVATION_AVAILABLE = 1
  integer, parameter, public :: RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED = 2
  integer, parameter, public :: RFM_ACTIVATION_INVALID = 3

  type, public :: rfm_unponded_activation_request_t
    real(real64) :: sigma_b = 0.0_real64
    real(real64) :: matrix_conductivity_cm_per_day = 0.0_real64
    real(real64) :: surface_sorptivity_cm_sqrt_day = 0.0_real64
    real(real64) :: source_rate_cm_per_day = 0.0_real64
    real(real64) :: event_age_day = 0.0_real64
    real(real64) :: ponding_depth_cm = 0.0_real64
  contains
    procedure, public :: valid => request_valid
  end type rfm_unponded_activation_request_t

  type, public :: rfm_unponded_activation_result_t
    integer :: status = RFM_ACTIVATION_NOT_RUN
    real(real64) :: b50_cm_per_day = 0.0_real64
    real(real64) :: matrix_rate_cm_per_day = 0.0_real64
    real(real64) :: preferential_rate_cm_per_day = 0.0_real64
    real(real64) :: preferential_fraction = 0.0_real64
  end type rfm_unponded_activation_result_t

  public :: evaluate_rfm_unponded_activation

contains

  pure logical function request_valid(self) result(ok)
    class(rfm_unponded_activation_request_t), intent(in) :: self

    ok = ieee_is_finite(self%sigma_b) .and. self%sigma_b > 0.0_real64 .and. &
         ieee_is_finite(self%matrix_conductivity_cm_per_day) .and. &
         self%matrix_conductivity_cm_per_day >= 0.0_real64 .and. &
         ieee_is_finite(self%surface_sorptivity_cm_sqrt_day) .and. &
         self%surface_sorptivity_cm_sqrt_day >= 0.0_real64 .and. &
         ieee_is_finite(self%source_rate_cm_per_day) .and. &
         self%source_rate_cm_per_day >= 0.0_real64 .and. &
         ieee_is_finite(self%event_age_day) .and. self%event_age_day >= 0.0_real64 .and. &
         ieee_is_finite(self%ponding_depth_cm) .and. self%ponding_depth_cm >= 0.0_real64
  end function request_valid

  subroutine evaluate_rfm_unponded_activation(request, result)
    type(rfm_unponded_activation_request_t), intent(in) :: request
    type(rfm_unponded_activation_result_t), intent(out) :: result
    real(real64) :: age, mu, log_r, z_trunc, z_tail, truncated_mean

    result = rfm_unponded_activation_result_t()

    if (.not. request%valid()) then
      result%status = RFM_ACTIVATION_INVALID
      return
    end if

    if (request%ponding_depth_cm > 0.0_real64) then
      result%status = RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED
      return
    end if

    if (request%source_rate_cm_per_day <= 0.0_real64) then
      result%status = RFM_ACTIVATION_AVAILABLE
      return
    end if

    age = max(request%event_age_day, 1.0e-12_real64)
    result%b50_cm_per_day = request%matrix_conductivity_cm_per_day + &
         request%surface_sorptivity_cm_sqrt_day/(2.0_real64*sqrt(age))

    if (.not. ieee_is_finite(result%b50_cm_per_day) .or. result%b50_cm_per_day <= 0.0_real64) then
      result = rfm_unponded_activation_result_t(status=RFM_ACTIVATION_INVALID)
      return
    end if

    mu = log(result%b50_cm_per_day)
    log_r = log(request%source_rate_cm_per_day)
    z_trunc = (log_r-mu-request%sigma_b**2)/request%sigma_b
    z_tail = (log_r-mu)/request%sigma_b
    truncated_mean = exp(mu+0.5_real64*request%sigma_b**2)*normal_cdf(z_trunc)

    result%matrix_rate_cm_per_day = truncated_mean + &
         request%source_rate_cm_per_day*(1.0_real64-normal_cdf(z_tail))
    result%matrix_rate_cm_per_day = min(request%source_rate_cm_per_day, &
         max(0.0_real64,result%matrix_rate_cm_per_day))
    result%preferential_rate_cm_per_day = &
         request%source_rate_cm_per_day-result%matrix_rate_cm_per_day
    result%preferential_fraction = &
         result%preferential_rate_cm_per_day/request%source_rate_cm_per_day
    result%status = RFM_ACTIVATION_AVAILABLE
  end subroutine evaluate_rfm_unponded_activation

  pure real(real64) function normal_cdf(x) result(value)
    real(real64), intent(in) :: x
    value = 0.5_real64*(1.0_real64+erf(x/sqrt(2.0_real64)))
  end function normal_cdf

end module mod_rfm_unponded_activation
