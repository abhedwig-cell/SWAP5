! Disposable opt-in attempt context. Does not own or commit physical state.
module mod_ppa_wu05a4_attempt
  use, intrinsic::iso_fortran_env,only:real64,int64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_reference_richards_workspace,only:reference_richards_workspace_t
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_candidate_mass,only:candidate_mass_account
  use mod_ppa_wu05a4_checkpoint_input
  use mod_ppa_wu05a4_static_geometry,only:static_macro_geometry
  use mod_ppa_wu05a4_saturated_trial,only:saturated_domain_inputs
  use mod_ppa_wu05a4_trial_exchange,only:macro_trial_key
  use mod_ppa_wu05a4_richards_scratch_binding
  implicit none
  private
  type,public::static_macro_attempt
    private
    logical::active=.false.
    integer(int64)::generation=0
    real(real64)::dt=0
    type(macro_trial_key)::key
    type(saturated_domain_inputs)::input
    type(ppa_wu05a2_macropore_checkpoint_t)::checkpoint
    type(reference_trial_transfer)::transfer
  end type
  public::begin_static_attempt,evaluate_static_attempt,diagonal_static_attempt
  public::finish_static_attempt,discard_static_attempt
contains
  subroutine discard_static_attempt(attempt)
    type(static_macro_attempt),intent(out)::attempt
    attempt%active=.false.
  end subroutine

  subroutine begin_static_attempt(checkpoint,z,dz,volume,diameter,resistance,dt,attempt_id, &
      reduction_decades,workspace,attempt,geometry,ok)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in)::checkpoint
    real(real64),intent(in)::z(:),dz(:),volume(:),diameter(:),resistance(:),dt
    integer(int64),intent(in)::attempt_id
    integer,intent(in)::reduction_decades
    type(reference_richards_workspace_t),intent(in)::workspace
    type(static_macro_attempt),intent(out)::attempt
    type(static_macro_geometry),intent(out)::geometry
    logical,intent(out)::ok
    type(static_macro_attempt)::trial
    type(static_macro_geometry)::trial_geometry
    ok=.false.
    if(.not.ieee_is_finite(dt))return
    if(dt<=0.or.attempt_id<=0.or.reduction_decades<0.or.reduction_decades>3)return
    if(workspace%poisoned.or.workspace%generation<=0.or.workspace%active_nodes/=size(dz))return
    if(.not.allocated(workspace%residual))return
    if(size(workspace%residual)/=size(dz))return
    call prepare_static_checkpoint_input(checkpoint,z,dz,volume,diameter,resistance,trial%input,trial_geometry,ok)
    if(.not.ok)return
    trial%input%reduction_decades=reduction_decades
    trial%checkpoint=checkpoint; trial%dt=dt; trial%generation=workspace%generation
    trial%key=macro_trial_key(checkpoint%lineage_id,checkpoint%revision,attempt_id,0_int64)
    trial%active=.true.; attempt=trial; geometry=trial_geometry
  end subroutine

  subroutine evaluate_static_attempt(attempt,workspace,head,pond,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(inout)::workspace
    real(real64),intent(in)::head(:),pond
    logical,intent(out)::ok
    real(real64)::storage
    ok=.false.
    if(.not.attempt%active)return
    if(attempt%key%evaluation==huge(attempt%key%evaluation))then
      call discard_static_attempt(attempt); return
    end if
    attempt%key%evaluation=attempt%key%evaluation+1_int64
    call apply_saturated_reference_residual(attempt%input,head,pond,attempt%dt,attempt%key, &
        attempt%generation,workspace,attempt%transfer,storage,ok)
    if(.not.ok)call discard_static_attempt(attempt)
  end subroutine

  subroutine diagonal_static_attempt(attempt,workspace,head,enabled,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(inout)::workspace
    real(real64),intent(in)::head(:)
    logical,intent(in)::enabled
    logical,intent(out)::ok
    ok=.false.
    if(.not.attempt%active)return
    call apply_reference_trial_diagonal(workspace,attempt%transfer,attempt%key,enabled,ok,head)
    if(.not.ok)call discard_static_attempt(attempt)
  end subroutine

  subroutine finish_static_attempt(attempt,workspace,head,tolerance,candidate,account,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(in)::workspace
    real(real64),intent(in)::head(:),tolerance
    type(ppa_wu05a2_macropore_candidate_t),intent(out)::candidate
    type(candidate_mass_account),intent(out)::account
    logical,intent(out)::ok
    ok=.false.
    if(.not.attempt%active)return
    call prepare_reference_interval(workspace,attempt%transfer,attempt%key,head,attempt%dt, &
        attempt%checkpoint,tolerance,candidate,account,ok)
    ! Both failure and successful extraction end this disposable context.
    call discard_static_attempt(attempt)
  end subroutine
end module
