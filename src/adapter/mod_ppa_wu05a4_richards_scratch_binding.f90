! Opt-in scratch adapter only: not called by production HeadCalc yet.
module mod_ppa_wu05a4_richards_scratch_binding
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_reference_richards_workspace,only:reference_richards_workspace_t
  use mod_ppa_wu05a4_saturated_trial,only:saturated_domain_inputs,evaluate_saturated_system
  use mod_ppa_wu05a4_trial_exchange,only:macro_trial_key,macro_used_exchange,discard_macro_exchange
  implicit none
  private
  public::apply_saturated_reference_scratch
contains
  subroutine apply_saturated_reference_scratch(input,head,dt,key,expected_generation, &
      derivative_enabled,workspace,used,storage_candidate,ok)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),dt
    type(macro_trial_key),intent(in)::key
    integer(int64),intent(in)::expected_generation
    logical,intent(in)::derivative_enabled
    type(reference_richards_workspace_t),intent(inout)::workspace
    type(macro_used_exchange),intent(out)::used
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    call discard_macro_exchange(used)
    storage_candidate=0; ok=.false.
    if(workspace%poisoned)return
    if(expected_generation<=0.or.workspace%generation/=expected_generation)return
    if(workspace%active_nodes/=size(head).or.size(head)<1)return
    if(.not.allocated(workspace%residual).or..not.allocated(workspace%dfdh_main))return
    if(size(workspace%residual)/=size(head).or.size(workspace%dfdh_main)/=size(head))return
    call evaluate_saturated_system(input,head,dt,key,derivative_enabled,workspace%residual, &
        workspace%dfdh_main,used,storage_candidate,ok)
  end subroutine
end module
