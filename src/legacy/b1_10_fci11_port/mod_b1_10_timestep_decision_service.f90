module mod_b1_10_timestep_decision_service
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: B110_TS_REASON_KEEP = 0
  integer, parameter, public :: B110_TS_REASON_GROW_LOW_ITER = 1
  integer, parameter, public :: B110_TS_REASON_SHRINK_MAX_ITER = 2
  integer, parameter, public :: B110_TS_REASON_GROW_THEN_SHRINK = 3
  integer, parameter, public :: B110_TS_REASON_SOLVER_RETRY = 4
  integer, parameter, public :: B110_TS_REASON_SOLVER_RETRY_FLOOR = 5

  type, public :: b1_10_timestep_decision_t
    real(real64) :: input_dt = 0.0_real64
    real(real64) :: preferred_dt = 0.0_real64
    integer :: reason = B110_TS_REASON_KEEP
    logical :: floor_reached = .false.
  end type b1_10_timestep_decision_t

  type, public :: b1_10_timestep_trace_t
    logical :: available = .false.
    integer :: sequence = 0
    real(real64) :: input_dt = 0.0_real64
    real(real64) :: preferred_dt = 0.0_real64
    real(real64) :: executed_dt = 0.0_real64
    integer :: reason = B110_TS_REASON_KEEP
    logical :: event_clipped = .false.
    logical :: floor_reached = .false.
  end type b1_10_timestep_trace_t

  public :: b1_10_legacy_accepted_step_decision
  public :: b1_10_legacy_solver_retry_decision

contains

  pure function b1_10_legacy_accepted_step_decision(dt, dtmin, dtmax, numbit, numbit_crit, &
       maxit, fact_increase, fact_decrease) result(decision)
    real(real64), intent(in) :: dt, dtmin, dtmax, fact_increase, fact_decrease
    integer, intent(in) :: numbit, numbit_crit, maxit
    type(b1_10_timestep_decision_t) :: decision
    logical :: grew, shrunk

    decision = b1_10_timestep_decision_t()
    decision%input_dt = dt
    decision%preferred_dt = dt
    grew = .false.
    shrunk = .false.

    if (numbit <= numbit_crit) then
      decision%preferred_dt = min(decision%preferred_dt*fact_increase, dtmax)
      grew = .true.
    end if
    if (numbit >= maxit) then
      decision%preferred_dt = max(decision%preferred_dt*fact_decrease, dtmin)
      shrunk = .true.
    end if

    if (decision%preferred_dt < dtmin) then
      decision%preferred_dt = dtmin
      decision%floor_reached = .true.
    end if

    if (grew .and. shrunk) then
      decision%reason = B110_TS_REASON_GROW_THEN_SHRINK
    else if (grew) then
      decision%reason = B110_TS_REASON_GROW_LOW_ITER
    else if (shrunk) then
      decision%reason = B110_TS_REASON_SHRINK_MAX_ITER
    else
      decision%reason = B110_TS_REASON_KEEP
    end if
  end function b1_10_legacy_accepted_step_decision

  pure function b1_10_legacy_solver_retry_decision(dt, dtmin, fact_failure) result(decision)
    real(real64), intent(in) :: dt, dtmin, fact_failure
    type(b1_10_timestep_decision_t) :: decision

    decision = b1_10_timestep_decision_t()
    decision%input_dt = dt

    if (dt > fact_failure*dtmin) then
      decision%preferred_dt = dt/fact_failure
      decision%reason = B110_TS_REASON_SOLVER_RETRY
    else
      decision%preferred_dt = dtmin
      decision%reason = B110_TS_REASON_SOLVER_RETRY_FLOOR
      decision%floor_reached = .true.
    end if
  end function b1_10_legacy_solver_retry_decision

end module mod_b1_10_timestep_decision_service
