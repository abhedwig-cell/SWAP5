! Opt-in final-state bridge for explicit flux boundaries and the full column.
! Caller must have materialized final qtop/qbot and constitutive state. No
! prescribed-head top, saturated shortcut, legacy root source or owner commit.
module mod_ppa_wu05a4_reference_finish
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_reference_richards_state_binding
  use mod_reference_richards_workspace,only:reference_richards_workspace_t
  use mod_ppa_wu05a4_attempt
  use mod_ppa_wu05a2_macropore_state,only:ppa_wu05a2_macropore_candidate_t
  use mod_ppa_wu05a3_candidate_mass,only:candidate_mass_account
  implicit none
  private
  public::finish_reference_static_attempt
contains
  subroutine finish_reference_static_attempt(attempt,workspace,state,tolerance,candidate,account,ok)
    type(static_macro_attempt),intent(inout)::attempt
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_richards_state_binding_t),intent(in)::state
    real(real64),intent(in)::tolerance
    type(ppa_wu05a2_macropore_candidate_t),intent(out)::candidate
    type(candidate_mass_account),intent(out)::account
    logical,intent(out)::ok
    real(real64),allocatable::faces(:)
    logical::valid
    integer::n
    ok=.false.
    call validate_reference_state_binding(state,valid)
    guard: block
      if(.not.valid)exit guard
      valid=.false.; n=state%active_nodes
      if(n<2.or.workspace%active_nodes/=n.or.workspace%poisoned)exit guard
      if(state%ftoph.or.any(workspace%unsaturated_flags))exit guard
      if(.not.allocated(workspace%head_gradient).or..not.allocated(workspace%source) &
          .or..not.allocated(workspace%sink).or..not.allocated(workspace%provider_root_sink))exit guard
      if(size(workspace%head_gradient)/=n+1.or.size(workspace%source)/=n &
          .or.size(workspace%sink)/=n.or.size(workspace%provider_root_sink)/=n)exit guard
      if(.not.all(ieee_is_finite([state%qtop,state%qbot])))exit guard
      if(.not.all(ieee_is_finite(state%kmean(2:n))))exit guard
      if(any(state%kmean(2:n)<0))exit guard
      if(.not.all(ieee_is_finite(workspace%head_gradient(2:n))))exit guard
      allocate(faces(n+1))
      faces(1)=state%qtop; faces(n+1)=state%qbot
      ! vertical_flux is reused by special branches and may be stale. Use the
      ! same Darcy face product as vector_F, never infer flux from mass closure.
      faces(2:n)=-state%kmean(2:n)*workspace%head_gradient(2:n)
      if(.not.all(ieee_is_finite(faces)))exit guard
      valid=.true.
    end block guard
    if(.not.valid)then
      call discard_static_attempt(attempt); return
    end if
    call finish_matrix_static_attempt(attempt,workspace,state%h,state%thetm1,state%theta,faces, &
        workspace%source,workspace%sink,workspace%provider_root_sink,tolerance,candidate,account,ok)
  end subroutine
end module
