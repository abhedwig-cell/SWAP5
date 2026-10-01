module mod_ppa_wu05_perch19_reduction_controller
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer,parameter,public :: PERCH_REDUCTION_MAX_LEVEL=3
  integer,parameter,public :: PERCH_REDUCTION_RECOVERY_STEPS=10

  type,public :: macropore_reduction_continuation_t
    integer :: level=0
    integer :: stable_steps=0
    real(real64) :: previous_dt=0.0_real64
  contains
    procedure,public :: valid=>reduction_state_valid
    procedure,public :: factor=>reduction_factor
  end type macropore_reduction_continuation_t

  public :: reduction_after_retry
  public :: reduction_after_accept

contains

  pure logical function reduction_state_valid(self) result(ok)
    class(macropore_reduction_continuation_t),intent(in)::self
    ok=self%level>=0 .and. self%level<=PERCH_REDUCTION_MAX_LEVEL .and. &
       self%stable_steps>=0 .and. self%stable_steps<=PERCH_REDUCTION_RECOVERY_STEPS .and. &
       self%previous_dt>=0.0_real64
  end function reduction_state_valid

  pure real(real64) function reduction_factor(self) result(factor)
    class(macropore_reduction_continuation_t),intent(in)::self
    factor=0.1_real64**real(self%level,real64)
  end function reduction_factor

  pure subroutine reduction_after_retry(accepted,current_dt,candidate,can_retry)
    type(macropore_reduction_continuation_t),intent(in)::accepted
    real(real64),intent(in)::current_dt
    type(macropore_reduction_continuation_t),intent(out)::candidate
    logical,intent(out)::can_retry

    candidate=accepted
    can_retry=.false.
    if(.not.accepted%valid() .or. current_dt<=0.0_real64)return
    if(accepted%level>=PERCH_REDUCTION_MAX_LEVEL)return

    candidate%level=accepted%level+1
    candidate%previous_dt=current_dt
    can_retry=.true.
  end subroutine reduction_after_retry

  pure subroutine reduction_after_accept(attempt_state,current_dt,candidate)
    type(macropore_reduction_continuation_t),intent(in)::attempt_state
    real(real64),intent(in)::current_dt
    type(macropore_reduction_continuation_t),intent(out)::candidate

    candidate=attempt_state
    if(.not.attempt_state%valid() .or. current_dt<=0.0_real64)return

    if(candidate%level>0)then
      if(candidate%stable_steps<PERCH_REDUCTION_RECOVERY_STEPS) &
           candidate%stable_steps=candidate%stable_steps+1

      if(current_dt>candidate%previous_dt .or. &
         candidate%stable_steps>=PERCH_REDUCTION_RECOVERY_STEPS)then
        candidate%previous_dt=current_dt
        candidate%stable_steps=0
        candidate%level=candidate%level-1
      end if
    end if
  end subroutine reduction_after_accept

end module mod_ppa_wu05_perch19_reduction_controller
