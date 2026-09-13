module mod_b1_10_reference_temporal_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t
  implicit none
  private

  integer, parameter, public :: B1_10_TEMP_METRIC_NONE = 0
  integer, parameter, public :: B1_10_TEMP_METRIC_H = 1
  integer, parameter, public :: B1_10_TEMP_METRIC_THETA = 2
  integer, parameter, public :: B1_10_TEMP_METRIC_POND = 3
  integer, parameter, public :: B1_10_TEMP_METRIC_GWL = 4
  integer, parameter, public :: B1_10_TEMP_METRIC_VOLACT = 5
  integer, parameter, public :: B1_10_TEMP_METRIC_LDWET = 6
  integer, parameter, public :: B1_10_TEMP_METRIC_SPEV = 7
  integer, parameter, public :: B1_10_TEMP_METRIC_SAEV = 8

  ! No numerical defaults are admitted here. Negative initial values make an
  ! unconfigured policy fail closed until a qualification-owned profile binds
  ! every endpoint tolerance explicitly.
  type, public :: b1_10_reference_temporal_limits_t
    real(real64) :: h_cm = -1.0_real64
    real(real64) :: theta = -1.0_real64
    real(real64) :: pond_cm = -1.0_real64
    real(real64) :: gwl_cm = -1.0_real64
    real(real64) :: volact_cm = -1.0_real64
    real(real64) :: ldwet_cm = -1.0_real64
    real(real64) :: spev_cm = -1.0_real64
    real(real64) :: saev_cm = -1.0_real64
  contains
    procedure :: valid => b1_10_reference_temporal_limits_valid
  end type b1_10_reference_temporal_limits_t

  type, public :: b1_10_reference_temporal_assessment_t
    logical :: complete = .false.
    logical :: accepted = .false.
    logical :: lagged_continuation_diagnostic_only = .true.
    real(real64) :: normalized_error = huge(0.0_real64)
    integer :: limiting_metric = B1_10_TEMP_METRIC_NONE
    real(real64) :: h_ratio = huge(0.0_real64)
    real(real64) :: theta_ratio = huge(0.0_real64)
    real(real64) :: pond_ratio = huge(0.0_real64)
    real(real64) :: gwl_ratio = huge(0.0_real64)
    real(real64) :: volact_ratio = huge(0.0_real64)
    real(real64) :: ldwet_ratio = huge(0.0_real64)
    real(real64) :: spev_ratio = huge(0.0_real64)
    real(real64) :: saev_ratio = huge(0.0_real64)
  end type b1_10_reference_temporal_assessment_t

  public :: evaluate_b1_10_reference_temporal
  public :: b1_10_reference_temporal_error

contains

  pure logical function b1_10_reference_temporal_limits_valid(self) result(valid)
    class(b1_10_reference_temporal_limits_t), intent(in) :: self
    valid = finite_nonnegative(self%h_cm) .and. &
            finite_nonnegative(self%theta) .and. &
            finite_nonnegative(self%pond_cm) .and. &
            finite_nonnegative(self%gwl_cm) .and. &
            finite_nonnegative(self%volact_cm) .and. &
            finite_nonnegative(self%ldwet_cm) .and. &
            finite_nonnegative(self%spev_cm) .and. &
            finite_nonnegative(self%saev_cm)
  end function b1_10_reference_temporal_limits_valid

  pure logical function finite_nonnegative(value) result(ok)
    real(real64), intent(in) :: value
    ok = ieee_is_finite(value) .and. value >= 0.0_real64
  end function finite_nonnegative

  pure real(real64) function normalized_ratio(delta_value, tolerance) result(ratio)
    real(real64), intent(in) :: delta_value, tolerance
    if (.not. finite_nonnegative(delta_value) .or. .not. finite_nonnegative(tolerance)) then
      ratio = huge(0.0_real64)
    else if (tolerance <= 0.0_real64) then
      if (delta_value <= 0.0_real64) then
        ratio = 0.0_real64
      else
        ratio = huge(0.0_real64)
      end if
    else
      ratio = delta_value / tolerance
    end if
  end function normalized_ratio

  subroutine evaluate_b1_10_reference_temporal(delta, limits, assessment)
    type(b1_10_temporal_characterization_t), intent(in) :: delta
    type(b1_10_reference_temporal_limits_t), intent(in) :: limits
    type(b1_10_reference_temporal_assessment_t), intent(out) :: assessment

    assessment = b1_10_reference_temporal_assessment_t()
    if (.not. limits%valid()) return
    if (.not. delta%compatible .or. .not. delta%process_scope_complete) return

    ! F-CI14 acceptance compares endpoint quantities that represent the same t1.
    ! hm1/thetm1/pondm1/gwlm1 remain useful diagnostics but represent a former
    ! internal time level and therefore are deliberately excluded from this norm.
    assessment%h_ratio = normalized_ratio(delta%max_abs_h_cm, limits%h_cm)
    assessment%theta_ratio = normalized_ratio(delta%max_abs_theta, limits%theta)
    assessment%pond_ratio = normalized_ratio(delta%abs_pond_cm, limits%pond_cm)
    assessment%gwl_ratio = normalized_ratio(delta%abs_gwl_cm, limits%gwl_cm)
    assessment%volact_ratio = normalized_ratio(delta%abs_volact_cm, limits%volact_cm)
    assessment%ldwet_ratio = normalized_ratio(delta%abs_ldwet, limits%ldwet_cm)
    assessment%spev_ratio = normalized_ratio(delta%abs_spev, limits%spev_cm)
    assessment%saev_ratio = normalized_ratio(delta%abs_saev, limits%saev_cm)

    assessment%normalized_error = assessment%h_ratio
    assessment%limiting_metric = B1_10_TEMP_METRIC_H
    call update_limiting(assessment%theta_ratio, B1_10_TEMP_METRIC_THETA, assessment)
    call update_limiting(assessment%pond_ratio, B1_10_TEMP_METRIC_POND, assessment)
    call update_limiting(assessment%gwl_ratio, B1_10_TEMP_METRIC_GWL, assessment)
    call update_limiting(assessment%volact_ratio, B1_10_TEMP_METRIC_VOLACT, assessment)
    call update_limiting(assessment%ldwet_ratio, B1_10_TEMP_METRIC_LDWET, assessment)
    call update_limiting(assessment%spev_ratio, B1_10_TEMP_METRIC_SPEV, assessment)
    call update_limiting(assessment%saev_ratio, B1_10_TEMP_METRIC_SAEV, assessment)

    assessment%complete = ieee_is_finite(assessment%normalized_error)
    assessment%accepted = assessment%complete .and. assessment%normalized_error <= 1.0_real64
  end subroutine evaluate_b1_10_reference_temporal

  subroutine update_limiting(ratio, metric, assessment)
    real(real64), intent(in) :: ratio
    integer, intent(in) :: metric
    type(b1_10_reference_temporal_assessment_t), intent(inout) :: assessment
    if (ratio > assessment%normalized_error) then
      assessment%normalized_error = ratio
      assessment%limiting_metric = metric
    end if
  end subroutine update_limiting

  function b1_10_reference_temporal_error(delta, limits) result(value)
    type(b1_10_temporal_characterization_t), intent(in) :: delta
    type(b1_10_reference_temporal_limits_t), intent(in) :: limits
    real(real64) :: value
    type(b1_10_reference_temporal_assessment_t) :: assessment

    call evaluate_b1_10_reference_temporal(delta, limits, assessment)
    if (assessment%complete) then
      value = assessment%normalized_error
    else
      value = huge(0.0_real64)
    end if
  end function b1_10_reference_temporal_error

end module mod_b1_10_reference_temporal_policy
