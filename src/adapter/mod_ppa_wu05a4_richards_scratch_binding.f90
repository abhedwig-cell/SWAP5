! Opt-in scratch adapter only: not called by production HeadCalc yet.
module mod_ppa_wu05a4_richards_scratch_binding
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_reference_richards_workspace,only:reference_richards_workspace_t
  use mod_ppa_wu05a4_saturated_trial,only:saturated_domain_inputs,evaluate_saturated_system, &
      evaluate_saturated_residual
  use mod_ppa_wu05a4_trial_exchange,only:macro_trial_key,macro_used_exchange,copy_matrix_transfer, &
      apply_macro_diagonal
  implicit none
  private
  type,public::reference_trial_transfer
    private
    integer(int64)::generation=0
    integer::nodes=0
    type(macro_used_exchange)::used
  end type
  public::apply_saturated_reference_scratch,copy_reference_transfer,discard_reference_transfer
  public::apply_saturated_reference_residual,apply_reference_trial_diagonal
contains
  ! Caller rebuilds the ordinary matrix residual before each evaluation and uses
  ! a new evaluation key for changed heads. No diagonal is touched here.
  subroutine apply_saturated_reference_residual(input,head,pond,dt,key,expected_generation, &
      workspace,used,storage_candidate,ok)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),pond,dt
    type(macro_trial_key),intent(in)::key
    integer(int64),intent(in)::expected_generation
    type(reference_richards_workspace_t),intent(inout)::workspace
    type(reference_trial_transfer),intent(out)::used
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    call discard_reference_transfer(used)
    storage_candidate=0; ok=.false.
    if(workspace%poisoned)return
    if(expected_generation<=0.or.workspace%generation/=expected_generation)return
    if(workspace%active_nodes/=size(head).or.size(head)<1)return
    if(.not.allocated(workspace%residual))return
    if(size(workspace%residual)/=size(head))return
    call evaluate_saturated_residual(input,head,dt,key,workspace%residual,used%used,storage_candidate,ok,pond)
    if(ok)then
      used%generation=workspace%generation
      used%nodes=workspace%active_nodes
    end if
  end subroutine

  ! Consume the residual's captured derivative after the ordinary diagonal is
  ! rebuilt. Failure invalidates capture; the owner must reject the trial.
  subroutine apply_reference_trial_diagonal(workspace,record,key,enabled,ok,head)
    type(reference_richards_workspace_t),intent(inout)::workspace
    type(reference_trial_transfer),intent(inout)::record
    type(macro_trial_key),intent(in)::key
    logical,intent(in)::enabled
    logical,intent(out)::ok
    real(real64),optional,intent(in)::head(:)
    ok=.false.
    if(.not.workspace_matches(workspace,record))then
      call discard_reference_transfer(record)
      return
    end if
    if(.not.allocated(workspace%dfdh_main))then
      call discard_reference_transfer(record)
      return
    end if
    call apply_macro_diagonal(record%used,key,enabled,workspace%dfdh_main,ok,head)
    if(.not.ok)call discard_reference_transfer(record)
  end subroutine

  logical function workspace_matches(workspace,record) result(valid)
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_trial_transfer),intent(in)::record
    valid=.false.
    if(workspace%poisoned.or.record%generation<=0.or.workspace%generation/=record%generation &
        .or.workspace%active_nodes/=record%nodes.or..not.allocated(workspace%residual))return
    if(size(workspace%residual)/=record%nodes)return
    valid=.true.
  end function

  subroutine discard_reference_transfer(record)
    type(reference_trial_transfer),intent(out)::record
    record%generation=0
  end subroutine

  subroutine copy_reference_transfer(workspace,record,key,amount,ok,head,dt)
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_trial_transfer),intent(inout)::record
    type(macro_trial_key),intent(in)::key
    real(real64),allocatable,intent(out)::amount(:)
    logical,intent(out)::ok
    real(real64),optional,intent(in)::head(:),dt
    ok=.false.
    if(.not.workspace_matches(workspace,record)) then
      call discard_reference_transfer(record)
      return
    end if
    call copy_matrix_transfer(record%used,key,amount,ok,head,dt)
    if(.not.ok.and.(present(head).or.present(dt)))call discard_reference_transfer(record)
  end subroutine

  subroutine apply_saturated_reference_scratch(input,head,dt,key,expected_generation, &
      derivative_enabled,workspace,used,storage_candidate,ok,pond)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),dt
    type(macro_trial_key),intent(in)::key
    integer(int64),intent(in)::expected_generation
    logical,intent(in)::derivative_enabled
    type(reference_richards_workspace_t),intent(inout)::workspace
    type(reference_trial_transfer),intent(out)::used
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    real(real64),optional,intent(in)::pond
    call discard_reference_transfer(used)
    storage_candidate=0; ok=.false.
    if(workspace%poisoned)return
    if(expected_generation<=0.or.workspace%generation/=expected_generation)return
    if(workspace%active_nodes/=size(head).or.size(head)<1)return
    if(.not.allocated(workspace%residual).or..not.allocated(workspace%dfdh_main))return
    if(size(workspace%residual)/=size(head).or.size(workspace%dfdh_main)/=size(head))return
    call evaluate_saturated_system(input,head,dt,key,derivative_enabled,workspace%residual, &
        workspace%dfdh_main,used%used,storage_candidate,ok,pond)
    if(ok) then
      used%generation=workspace%generation
      used%nodes=workspace%active_nodes
    end if
  end subroutine
end module
