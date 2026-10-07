module mod_irrigation_management_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_POLICY_OK = 0
  integer, parameter, public :: IRR_POLICY_INVALID = 1

  type, public :: irrigation_event_policy_t
    logical :: minimum_interval_enabled = .true.
    integer :: minimum_interval_days = 1
    logical :: depth_limits_enabled = .false.
    real(real64) :: minimum_depth_cm = 0.0_real64
    real(real64) :: maximum_depth_cm = huge(1.0_real64)
    logical :: source_rate_adaptation_enabled = .false.
  end type irrigation_event_policy_t

  type, public :: irrigation_event_shape_t
    integer :: status = IRR_POLICY_OK
    logical :: interval_gate_passed = .false.
    real(real64) :: selected_depth_cm = 0.0_real64
    real(real64) :: effective_rate_cm_per_day = 0.0_real64
    real(real64) :: event_duration_day = 0.0_real64
    logical :: minimum_depth_applied = .false.
    logical :: maximum_depth_applied = .false.
    logical :: zero_rate_daily_fallback = .false.
    logical :: long_duration_rate_cap = .false.
  end type irrigation_event_shape_t

  public :: irrigation_interval_gate
  public :: resolve_irrigation_event_shape

contains

  pure logical function irrigation_interval_gate(policy, dayfix)
    type(irrigation_event_policy_t), intent(in) :: policy
    integer, intent(in) :: dayfix
    if (.not. policy%minimum_interval_enabled) then
      irrigation_interval_gate = .true.
    else
      irrigation_interval_gate = dayfix >= policy%minimum_interval_days
    end if
  end function irrigation_interval_gate

  pure subroutine resolve_irrigation_event_shape(policy, requested_depth_cm, configured_rate_cm_per_day, shape)
    type(irrigation_event_policy_t), intent(in) :: policy
    real(real64), intent(in) :: requested_depth_cm, configured_rate_cm_per_day
    type(irrigation_event_shape_t), intent(out) :: shape
    real(real64) :: depth, duration

    shape = irrigation_event_shape_t()
    if (.not. valid_policy(policy)) then
      shape%status = IRR_POLICY_INVALID
      return
    end if
    if (.not. ieee_is_finite(requested_depth_cm) .or. requested_depth_cm <= 0.0_real64) then
      shape%status = IRR_POLICY_INVALID
      return
    end if
    if (.not. ieee_is_finite(configured_rate_cm_per_day) .or. configured_rate_cm_per_day < 0.0_real64) then
      shape%status = IRR_POLICY_INVALID
      return
    end if

    depth = requested_depth_cm
    if (policy%depth_limits_enabled) then
      if (depth < policy%minimum_depth_cm) then
        depth = policy%minimum_depth_cm
        shape%minimum_depth_applied = .true.
      end if
      if (depth > policy%maximum_depth_cm) then
        depth = policy%maximum_depth_cm
        shape%maximum_depth_applied = .true.
      end if
    end if
    if (depth <= 0.0_real64 .or. .not. ieee_is_finite(depth)) then
      shape%status = IRR_POLICY_INVALID
      return
    end if

    shape%selected_depth_cm = depth
    if (.not. policy%source_rate_adaptation_enabled) then
      if (configured_rate_cm_per_day <= 0.0_real64) then
        shape%status = IRR_POLICY_INVALID
        return
      end if
      duration = depth / configured_rate_cm_per_day
      if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64 .or. duration > 1.0_real64) then
        shape%status = IRR_POLICY_INVALID
        return
      end if
      shape%effective_rate_cm_per_day = configured_rate_cm_per_day
      shape%event_duration_day = duration
      return
    end if

    if (configured_rate_cm_per_day <= 0.0_real64) then
      shape%effective_rate_cm_per_day = depth
      shape%event_duration_day = 1.0_real64
      shape%zero_rate_daily_fallback = .true.
      return
    end if

    duration = depth / configured_rate_cm_per_day
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64) then
      shape%status = IRR_POLICY_INVALID
      return
    end if
    if (duration > 1.0_real64) then
      shape%effective_rate_cm_per_day = depth
      shape%event_duration_day = 1.0_real64
      shape%long_duration_rate_cap = .true.
    else
      shape%effective_rate_cm_per_day = configured_rate_cm_per_day
      shape%event_duration_day = duration
    end if
  end subroutine resolve_irrigation_event_shape

  pure logical function valid_policy(policy)
    type(irrigation_event_policy_t), intent(in) :: policy
    valid_policy = policy%minimum_interval_days >= 1
    if (.not. valid_policy) return
    if (policy%depth_limits_enabled) then
      valid_policy = ieee_is_finite(policy%minimum_depth_cm) .and. ieee_is_finite(policy%maximum_depth_cm) .and. &
                     policy%minimum_depth_cm >= 0.0_real64 .and. &
                     policy%maximum_depth_cm >= policy%minimum_depth_cm
    end if
  end function valid_policy
end module mod_irrigation_management_policy
