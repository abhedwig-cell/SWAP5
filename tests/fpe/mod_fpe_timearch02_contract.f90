module mod_fpe_timearch02_contract
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: TS_REASON_KEEP=0
  integer, parameter, public :: TS_REASON_GROW_LOW_ITER=1
  integer, parameter, public :: TS_REASON_SHRINK_MAX_ITER=2
  integer, parameter, public :: TS_REASON_GROW_THEN_SHRINK=3
  integer, parameter, public :: TS_REASON_SOLVER_RETRY=4
  integer, parameter, public :: TS_REASON_SOLVER_RETRY_FLOOR=5
  integer, parameter, public :: TS_REASON_DAYSTART_COMPAT_FLOOR=6
  integer, parameter, public :: TS_REASON_HARD_EVENT_CLAMP=7
  integer, parameter, public :: TS_REASON_EXTERNAL_INTERVAL_CLAMP=8

  type, public :: timestep_decision_t
    real(real64) :: input_dt=0.0_real64
    real(real64) :: preferred_dt=0.0_real64
    real(real64) :: executed_dt=0.0_real64
    integer :: proposal_reason=TS_REASON_KEEP
    integer :: limiting_reason=TS_REASON_KEEP
    logical :: floor_reached=.false.
  end type timestep_decision_t

  public :: legacy_accepted_proposal
  public :: legacy_solver_retry
  public :: legacy_daystart_floor
  public :: compose_executable_dt

contains

  pure function legacy_accepted_proposal(dt,dtmin,dtmax,numbit,numbit_crit,maxit,fact_inc,fact_dec) result(d)
    real(real64),intent(in)::dt,dtmin,dtmax,fact_inc,fact_dec
    integer,intent(in)::numbit,numbit_crit,maxit
    type(timestep_decision_t)::d
    logical::grew,shrunk
    d%input_dt=dt
    d%preferred_dt=dt
    grew=.false.; shrunk=.false.
    if(numbit<=numbit_crit)then
      d%preferred_dt=min(d%preferred_dt*fact_inc,dtmax)
      grew=.true.
    end if
    if(numbit>=maxit)then
      d%preferred_dt=max(d%preferred_dt*fact_dec,dtmin)
      shrunk=.true.
    end if
    if(grew.and.shrunk)then
      d%proposal_reason=TS_REASON_GROW_THEN_SHRINK
    else if(grew)then
      d%proposal_reason=TS_REASON_GROW_LOW_ITER
    else if(shrunk)then
      d%proposal_reason=TS_REASON_SHRINK_MAX_ITER
    else
      d%proposal_reason=TS_REASON_KEEP
    end if
    d%executed_dt=d%preferred_dt
  end function

  pure function legacy_solver_retry(dt,dtmin,fact_fail) result(d)
    real(real64),intent(in)::dt,dtmin,fact_fail
    type(timestep_decision_t)::d
    d%input_dt=dt
    if(dt>fact_fail*dtmin)then
      d%preferred_dt=dt/fact_fail
      d%proposal_reason=TS_REASON_SOLVER_RETRY
    else
      d%preferred_dt=dtmin
      d%proposal_reason=TS_REASON_SOLVER_RETRY_FLOOR
      d%floor_reached=.true.
    end if
    d%executed_dt=d%preferred_dt
  end function

  pure function legacy_daystart_floor(dt,dtmin,dtmax) result(d)
    real(real64),intent(in)::dt,dtmin,dtmax
    type(timestep_decision_t)::d
    real(real64)::floor_dt
    d%input_dt=dt
    floor_dt=sqrt(dtmin*dtmax)
    d%preferred_dt=max(dt,floor_dt)
    if(d%preferred_dt>dt) d%proposal_reason=TS_REASON_DAYSTART_COMPAT_FLOOR
    d%executed_dt=d%preferred_dt
  end function

  pure function compose_executable_dt(preferred_dt,hard_event_remaining,external_active,external_remaining) result(d)
    real(real64),intent(in)::preferred_dt,hard_event_remaining,external_remaining
    logical,intent(in)::external_active
    type(timestep_decision_t)::d
    d%input_dt=preferred_dt
    d%preferred_dt=preferred_dt
    d%executed_dt=preferred_dt
    d%limiting_reason=TS_REASON_KEEP
    if(hard_event_remaining<d%executed_dt)then
      d%executed_dt=hard_event_remaining
      d%limiting_reason=TS_REASON_HARD_EVENT_CLAMP
    end if
    if(external_active.and.external_remaining<d%executed_dt)then
      d%executed_dt=external_remaining
      d%limiting_reason=TS_REASON_EXTERNAL_INTERVAL_CLAMP
    end if
  end function

end module mod_fpe_timearch02_contract
