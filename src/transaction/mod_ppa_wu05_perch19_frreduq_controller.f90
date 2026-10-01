module mod_ppa_wu05_perch19_frreduq_controller
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PERCH19_ACTION_NONE=0
  integer, parameter, public :: PERCH19_ACTION_REDUCE_TIMESTEP=1
  integer, parameter, public :: PERCH19_ACTION_RETRY_REDUCED_EXCHANGE=2
  integer, parameter, public :: PERCH19_ACTION_TERMINAL_FAILURE=3

  type, public :: perch19_frreduq_state_t
    integer :: reduction_level=0
    integer :: successful_steps=0
    real(real64) :: previous_reduction_dt=0.0_real64
  contains
    procedure, public :: valid => perch19_state_valid
    procedure, public :: factor => perch19_state_factor
    procedure, public :: same_values => perch19_state_same_values
  end type perch19_frreduq_state_t

  public :: perch19_failure_transition
  public :: perch19_success_transition

contains

  pure logical function perch19_state_valid(self) result(ok)
    class(perch19_frreduq_state_t),intent(in)::self
    ok=self%reduction_level>=0 .and. self%reduction_level<=3 .and. &
         self%successful_steps>=0 .and. self%successful_steps<=10 .and. &
         ieee_is_finite(self%previous_reduction_dt) .and. self%previous_reduction_dt>=0.0_real64
  end function perch19_state_valid

  pure real(real64) function perch19_state_factor(self) result(value)
    class(perch19_frreduq_state_t),intent(in)::self
    if(.not.self%valid())then
      value=0.0_real64
    else
      value=0.1_real64**real(self%reduction_level,real64)
    end if
  end function perch19_state_factor

  pure logical function perch19_state_same_values(self,other) result(same)
    class(perch19_frreduq_state_t),intent(in)::self
    type(perch19_frreduq_state_t),intent(in)::other
    same=self%reduction_level==other%reduction_level .and. &
         self%successful_steps==other%successful_steps .and. &
         self%previous_reduction_dt==other%previous_reduction_dt
  end function perch19_state_same_values

  subroutine perch19_failure_transition(accepted,dt,dtmin,dtmax,candidate,action,retry_dt,ok)
    type(perch19_frreduq_state_t),intent(in)::accepted
    real(real64),intent(in)::dt,dtmin,dtmax
    type(perch19_frreduq_state_t),intent(out)::candidate
    integer,intent(out)::action
    real(real64),intent(out)::retry_dt
    logical,intent(out)::ok
    real(real64)::eps

    candidate=accepted
    action=PERCH19_ACTION_NONE
    retry_dt=dt
    ok=.false.
    if(.not.accepted%valid())return
    if(.not.ieee_is_finite(dt) .or. .not.ieee_is_finite(dtmin) .or. .not.ieee_is_finite(dtmax))return
    if(dt<=0.0_real64 .or. dtmin<=0.0_real64 .or. dtmax<dtmin)return

    eps=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(dt),abs(dtmin))
    if(dt>dtmin+eps)then
      ! Exact source ordering: ordinary temporal reduction owns this retry.
      action=PERCH19_ACTION_REDUCE_TIMESTEP
      ! Ordinary temporal policy owns the actual dt reduction. The macropore
      ! controller must not invent a competing timestep factor.
      retry_dt=dt
      ok=.true.
      return
    end if

    if(accepted%reduction_level<3)then
      candidate%reduction_level=accepted%reduction_level+1
      candidate%previous_reduction_dt=dt
      action=PERCH19_ACTION_RETRY_REDUCED_EXCHANGE
      retry_dt=sqrt(dtmin*dtmax)
      ok=candidate%valid()
      return
    end if

    action=PERCH19_ACTION_TERMINAL_FAILURE
    retry_dt=dt
    ok=.true.
  end subroutine perch19_failure_transition

  subroutine perch19_success_transition(accepted,dt,candidate,ok)
    type(perch19_frreduq_state_t),intent(in)::accepted
    real(real64),intent(in)::dt
    type(perch19_frreduq_state_t),intent(out)::candidate
    logical,intent(out)::ok

    candidate=accepted
    ok=.false.
    if(.not.accepted%valid() .or. .not.ieee_is_finite(dt) .or. dt<=0.0_real64)return

    if(candidate%reduction_level>0)then
      if(candidate%successful_steps<10)candidate%successful_steps=candidate%successful_steps+1
      if(dt>candidate%previous_reduction_dt .or. candidate%successful_steps>=10)then
        candidate%previous_reduction_dt=dt
        candidate%successful_steps=0
        candidate%reduction_level=candidate%reduction_level-1
      end if
    end if
    ok=candidate%valid()
  end subroutine perch19_success_transition

end module mod_ppa_wu05_perch19_frreduq_controller
