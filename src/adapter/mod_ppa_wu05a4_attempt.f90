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
  public::finish_closed_static_attempt
  public::finish_matrix_static_attempt
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

  ! Closed exchange only: no matrix intercell flux, sinks, top/bottom inputs,
  ! pond change or other stores. Caller supplies independently evaluated theta,
  ! not a theta reconstructed from the captured transfer to force closure.
  subroutine finish_closed_static_attempt(attempt,workspace,head,theta_before,theta_after, &
      tolerance,candidate,account,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(in)::workspace
    real(real64),intent(in)::head(:),theta_before(:),theta_after(:),tolerance
    type(ppa_wu05a2_macropore_candidate_t),intent(out)::candidate
    type(candidate_mass_account),intent(out)::account
    logical,intent(out)::ok
    real(real64)::zero(size(head)),faces(size(head)+1)
    zero=0; faces=0
    call finish_matrix_static_attempt(attempt,workspace,head,theta_before,theta_after,faces,zero,zero,zero, &
        tolerance,candidate,account,ok)
  end subroutine

  ! Richards convention: faces are upward-positive rates, ordered top to bottom.
  ! source/sink/root are separate nonnegative per-cell rates (cm/day). Internal
  ! macro exchange is captured, never supplied again through ordinary sources.
  ! This accounts matrix + macro only, not pond/crop/snow or canonical commit.
  subroutine finish_matrix_static_attempt(attempt,workspace,head,theta_before,theta_after, &
      faces,source,sink,root,tolerance,candidate,account,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(in)::workspace
    real(real64),intent(in)::head(:),theta_before(:),theta_after(:),tolerance
    real(real64),intent(in)::faces(:),source(:),sink(:),root(:)
    type(ppa_wu05a2_macropore_candidate_t),intent(out)::candidate
    type(candidate_mass_account),intent(out)::account
    logical,intent(out)::ok
    real(real64),allocatable::amount(:),change(:),ordinary(:),local_input(:)
    real(real64)::begin_store,end_store,external
    logical::valid
    integer::n
    ok=.false.
    if(.not.attempt%active)return
    ! A failed guard consumes the attempt, just like failed final extraction.
    n=size(attempt%input%dz)
    valid=.false.
    guard: block
      if(size(theta_before)/=n.or.size(theta_after)/=n)exit guard
      if(size(faces)/=n+1.or.size(source)/=n.or.size(sink)/=n.or.size(root)/=n)exit guard
      if(.not.all(ieee_is_finite(faces)).or..not.all(ieee_is_finite(source)))exit guard
      if(.not.all(ieee_is_finite(sink)).or..not.all(ieee_is_finite(root)))exit guard
      if(any(source<0).or.any(sink<0).or.any(root<0))exit guard
      if(.not.ieee_is_finite(tolerance))exit guard
      if(tolerance<0)exit guard
      if(.not.all(ieee_is_finite(theta_before)).or..not.all(ieee_is_finite(theta_after)))exit guard
      if(any(theta_before<0).or.any(theta_before>1).or.any(theta_after<0).or.any(theta_after>1))exit guard
      call copy_reference_budget(workspace,attempt%transfer,attempt%key,head,attempt%dt, &
          amount,begin_store,end_store,valid)
      if(.not.valid)exit guard
      valid=.false.
      change=(theta_after-theta_before)*(1.0_real64-attempt%input%volume/attempt%input%dz)*attempt%input%dz
      if(.not.all(ieee_is_finite(change)))exit guard
      ordinary=source-sink-root
      local_input=(faces(2:n+1)-faces(1:n)+ordinary)*attempt%dt
      external=(faces(n+1)-faces(1)+sum(ordinary))*attempt%dt
      if(.not.all(ieee_is_finite(local_input)).or..not.ieee_is_finite(external))exit guard
      if(any(abs(change-amount-local_input)>tolerance))exit guard
      if(abs(sum(change)+end_store-begin_store-external)>tolerance)exit guard
      valid=.true.
    end block guard
    if(.not.valid)then
      call discard_static_attempt(attempt); return
    end if
    call finish_static_attempt(attempt,workspace,head,tolerance,candidate,account,ok)
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
