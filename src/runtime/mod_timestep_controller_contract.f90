module mod_timestep_controller_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_timestep_decision_service, only: b1_10_timestep_decision_t, &
       b1_10_legacy_accepted_step_decision
  implicit none
  private

  integer, parameter, public :: TS_CTRL_REASON_NONE = 0
  integer, parameter, public :: TS_CTRL_REASON_LEGACY_COMPAT = 1
  integer, parameter, public :: TS_CTRL_REASON_UNAVAILABLE = 2
  integer, parameter, public :: TS_CTRL_REASON_SAFETY_FLOOR = 3
  integer, parameter, public :: TS_CTRL_REASON_SAFETY_CEILING = 4

  type, public :: timestep_accepted_context_t
    real(real64) :: accepted_time = 0.0_real64
    real(real64) :: previous_accepted_dt = 0.0_real64
    real(real64) :: previous_preferred_dt = 0.0_real64
    real(real64) :: executed_dt = 0.0_real64
    logical :: preferred_available = .false.
    logical :: event_clipped = .false.
    integer :: nonlinear_iterations = 0
    integer :: backtracking_attempts = 0
    integer :: internal_retries = 0
  end type timestep_accepted_context_t

  type, public :: timestep_controller_limits_t
    real(real64) :: retry_floor = 0.0_real64
    logical :: expert_ceiling_present = .false.
    real(real64) :: expert_ceiling = 0.0_real64
  end type timestep_controller_limits_t

  type, public :: timestep_proposal_t
    logical :: available = .false.
    real(real64) :: preferred_dt = 0.0_real64
    integer :: reason = TS_CTRL_REASON_NONE
  end type timestep_proposal_t

  type, abstract, public :: timestep_controller_t
  contains
    procedure(controller_propose_iface), deferred :: propose
  end type timestep_controller_t

  type, extends(timestep_controller_t), public :: legacy_compat_timestep_controller_t
    real(real64) :: dtmin = 0.0_real64
    real(real64) :: dtmax = 0.0_real64
    integer :: numbit_crit = 0
    integer :: maxit = 0
    real(real64) :: fact_increase = 0.0_real64
    real(real64) :: fact_decrease = 0.0_real64
  contains
    procedure :: propose => legacy_compat_propose
  end type legacy_compat_timestep_controller_t

  type, extends(timestep_controller_t), public :: auto_reference_null_controller_t
  contains
    procedure :: propose => auto_reference_null_propose
  end type auto_reference_null_controller_t

  public :: apply_timestep_safety_limits
  public :: valid_timestep_accepted_context
  public :: valid_timestep_controller_limits

  abstract interface
    pure subroutine controller_propose_iface(self, context, proposal)
      import :: timestep_controller_t, timestep_accepted_context_t, timestep_proposal_t
      class(timestep_controller_t), intent(in) :: self
      type(timestep_accepted_context_t), intent(in) :: context
      type(timestep_proposal_t), intent(out) :: proposal
    end subroutine controller_propose_iface
  end interface

contains

  pure logical function valid_timestep_accepted_context(context) result(ok)
    type(timestep_accepted_context_t), intent(in) :: context
    real(real64) :: values(4)

    values = [context%accepted_time, context%previous_accepted_dt, &
         context%previous_preferred_dt, context%executed_dt]
    ok = all(ieee_is_finite(values))
    if (.not. ok) return
    if (context%accepted_time < 0.0_real64) then
      ok = .false.
      return
    end if
    if (context%previous_accepted_dt <= 0.0_real64 .or. context%executed_dt <= 0.0_real64) then
      ok = .false.
      return
    end if
    if (context%preferred_available .and. context%previous_preferred_dt <= 0.0_real64) then
      ok = .false.
      return
    end if
    if (context%nonlinear_iterations < 0 .or. context%backtracking_attempts < 0 .or. context%internal_retries < 0) then
      ok = .false.
    end if
  end function valid_timestep_accepted_context

  pure logical function valid_timestep_controller_limits(limits) result(ok)
    type(timestep_controller_limits_t), intent(in) :: limits

    ok = ieee_is_finite(limits%retry_floor) .and. limits%retry_floor > 0.0_real64
    if (.not. ok) return
    if (limits%expert_ceiling_present) then
      ok = ieee_is_finite(limits%expert_ceiling) .and. limits%expert_ceiling > limits%retry_floor
    end if
  end function valid_timestep_controller_limits

  pure subroutine legacy_compat_propose(self, context, proposal)
    class(legacy_compat_timestep_controller_t), intent(in) :: self
    type(timestep_accepted_context_t), intent(in) :: context
    type(timestep_proposal_t), intent(out) :: proposal
    type(b1_10_timestep_decision_t) :: decision
    real(real64) :: base_dt

    proposal = timestep_proposal_t()
    if (.not. valid_timestep_accepted_context(context)) return
    if (.not. ieee_is_finite(self%dtmin) .or. .not. ieee_is_finite(self%dtmax)) return
    if (self%dtmin <= 0.0_real64 .or. self%dtmax < self%dtmin) return
    if (self%numbit_crit < 0 .or. self%maxit <= 0 .or. self%numbit_crit > self%maxit) return
    if (.not. ieee_is_finite(self%fact_increase) .or. self%fact_increase <= 0.0_real64) return
    if (.not. ieee_is_finite(self%fact_decrease) .or. self%fact_decrease <= 0.0_real64) return

    base_dt = context%executed_dt
    decision = b1_10_legacy_accepted_step_decision(base_dt, self%dtmin, self%dtmax, &
         context%nonlinear_iterations, self%numbit_crit, self%maxit, self%fact_increase, self%fact_decrease)

    proposal%available = .true.
    proposal%preferred_dt = decision%preferred_dt
    proposal%reason = TS_CTRL_REASON_LEGACY_COMPAT
  end subroutine legacy_compat_propose

  pure subroutine auto_reference_null_propose(self, context, proposal)
    class(auto_reference_null_controller_t), intent(in) :: self
    type(timestep_accepted_context_t), intent(in) :: context
    type(timestep_proposal_t), intent(out) :: proposal

    proposal = timestep_proposal_t()
    proposal%reason = TS_CTRL_REASON_UNAVAILABLE
    if (.not. same_type_as(self, self)) return
    if (.not. valid_timestep_accepted_context(context)) return
  end subroutine auto_reference_null_propose

  pure subroutine apply_timestep_safety_limits(proposal, limits, limited)
    type(timestep_proposal_t), intent(in) :: proposal
    type(timestep_controller_limits_t), intent(in) :: limits
    type(timestep_proposal_t), intent(out) :: limited

    limited = proposal
    if (.not. proposal%available) return
    if (.not. ieee_is_finite(proposal%preferred_dt) .or. proposal%preferred_dt <= 0.0_real64) then
      limited%available = .false.
      limited%preferred_dt = 0.0_real64
      limited%reason = TS_CTRL_REASON_UNAVAILABLE
      return
    end if
    if (.not. valid_timestep_controller_limits(limits)) then
      limited%available = .false.
      limited%preferred_dt = 0.0_real64
      limited%reason = TS_CTRL_REASON_UNAVAILABLE
      return
    end if

    if (limited%preferred_dt < limits%retry_floor) then
      limited%preferred_dt = limits%retry_floor
      limited%reason = TS_CTRL_REASON_SAFETY_FLOOR
    end if
    if (limits%expert_ceiling_present .and. limited%preferred_dt > limits%expert_ceiling) then
      limited%preferred_dt = limits%expert_ceiling
      limited%reason = TS_CTRL_REASON_SAFETY_CEILING
    end if
  end subroutine apply_timestep_safety_limits

end module mod_timestep_controller_contract
