module mod_ppa_wu05_perch20_continuation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_macropore_reduction_continuation_t
  use mod_ppa_wu05_perch19_frreduq_controller, only: perch19_frreduq_state_t, &
       perch19_failure_transition, perch19_success_transition
  implicit none
  private

  public :: perch20_failure_transition
  public :: perch20_success_transition

contains

  subroutine perch20_failure_transition(accepted,dt,dtmin,dtmax,candidate,action,retry_dt,ok)
    type(fmr_macropore_reduction_continuation_t),intent(in)::accepted
    real(real64),intent(in)::dt,dtmin,dtmax
    type(fmr_macropore_reduction_continuation_t),intent(out)::candidate
    integer,intent(out)::action
    real(real64),intent(out)::retry_dt
    logical,intent(out)::ok
    type(perch19_frreduq_state_t)::a,c

    call to_controller(accepted,a,ok)
    if(.not.ok)return
    call perch19_failure_transition(a,dt,dtmin,dtmax,c,action,retry_dt,ok)
    if(.not.ok)return
    call from_controller(c,candidate,ok)
  end subroutine perch20_failure_transition

  subroutine perch20_success_transition(accepted,dt,candidate,ok)
    type(fmr_macropore_reduction_continuation_t),intent(in)::accepted
    real(real64),intent(in)::dt
    type(fmr_macropore_reduction_continuation_t),intent(out)::candidate
    logical,intent(out)::ok
    type(perch19_frreduq_state_t)::a,c

    call to_controller(accepted,a,ok)
    if(.not.ok)return
    call perch19_success_transition(a,dt,c,ok)
    if(.not.ok)return
    call from_controller(c,candidate,ok)
  end subroutine perch20_success_transition

  subroutine to_controller(source,target,ok)
    type(fmr_macropore_reduction_continuation_t),intent(in)::source
    type(perch19_frreduq_state_t),intent(out)::target
    logical,intent(out)::ok
    target%reduction_level=source%reduction_level
    target%successful_steps=source%successful_steps
    target%previous_reduction_dt=source%previous_reduction_dt
    ok=source%valid() .and. target%valid()
  end subroutine to_controller

  subroutine from_controller(source,target,ok)
    type(perch19_frreduq_state_t),intent(in)::source
    type(fmr_macropore_reduction_continuation_t),intent(out)::target
    logical,intent(out)::ok
    target%reduction_level=source%reduction_level
    target%successful_steps=source%successful_steps
    target%previous_reduction_dt=source%previous_reduction_dt
    ok=source%valid() .and. target%valid()
  end subroutine from_controller

end module mod_ppa_wu05_perch20_continuation_binding
