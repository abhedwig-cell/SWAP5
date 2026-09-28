! Opt-in scratch adapter only: not called by production HeadCalc yet.
module mod_ppa_wu05a4_richards_scratch_binding
  use, intrinsic::iso_fortran_env,only:real64,int64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_interval_candidate,only:prepare_macropore_interval_candidate
  use mod_ppa_wu05a3_candidate_mass,only:candidate_mass_account,account_candidate_mass
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
    real(real64)::begin_storage=0,candidate_storage=0
    type(macro_used_exchange)::used
    type(saturated_domain_inputs)::geometry
  end type
  public::apply_saturated_reference_scratch,copy_reference_transfer,discard_reference_transfer
  public::apply_saturated_reference_residual,apply_reference_trial_diagonal
  public::copy_reference_budget
  public::prepare_reference_interval
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
      used%begin_storage=input%storage
      used%candidate_storage=storage_candidate
      used%geometry=input
    end if
  end subroutine

  ! Proposed single-domain bridge. All outputs remain tentative; no owner commit.
  subroutine prepare_reference_interval(workspace,record,key,head,dt,checkpoint,tolerance,candidate,account,ok)
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_trial_transfer),intent(inout)::record
    type(macro_trial_key),intent(in)::key
    real(real64),intent(in)::head(:),dt,tolerance
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in)::checkpoint
    type(ppa_wu05a2_macropore_candidate_t),intent(out)::candidate
    type(candidate_mass_account),intent(out)::account
    logical,intent(out)::ok
    type(ppa_wu05a2_macropore_candidate_t)::trial
    type(candidate_mass_account)::trial_account
    real(real64),allocatable::amount(:),rate(:),exchange(:,:),zeros(:),profile(:),faces(:,:),balance(:)
    real(real64)::begin_store,end_store,representation_tol
    integer::n,status
    ok=.false.
    if(.not.ieee_is_finite(tolerance))return
    if(tolerance<0)return
    if(checkpoint%lineage_id/=key%lineage.or.checkpoint%revision/=key%revision)return
    if(.not.checkpoint%payload%ready())return
    n=size(head)
    if(checkpoint%payload%n_domains/=1.or.checkpoint%payload%n_compartments/=n)return
    if(checkpoint%payload%bottom_domain(1)/=n)return
    call copy_reference_budget(workspace,record,key,head,dt,amount,begin_store,end_store,ok,rate)
    if(.not.ok)return
    ok=.false.
    representation_tol=32*epsilon(1.0_real64)*max(1.0_real64,begin_store)
    if(abs(checkpoint%payload%domain_water_storage(1)-begin_store)>representation_tol)return
    if(any(abs(checkpoint%payload%pore_volume(1,:)-record%geometry%volume)>representation_tol))return
    profile=record%geometry%volume*max(0.0_real64,min(1.0_real64, &
        (record%geometry%pore_level-record%geometry%z+0.5_real64*record%geometry%dz)/record%geometry%dz))
    if(any(abs(checkpoint%payload%pore_water(1,:)-profile)>representation_tol))return
    allocate(exchange(1,n),zeros(n)); zeros=0
    exchange(1,:)=rate
    call prepare_macropore_interval_candidate(checkpoint,dt,checkpoint%payload%pore_volume, &
        [0.0_real64],[0.0_real64],exchange,zeros,record%geometry%dz,[record%geometry%bottom], &
        tolerance,trial,faces,balance,status)
    if(status/=0)return
    if(abs(trial%payload%domain_water_storage(1)-end_store)>tolerance)return
    call account_candidate_mass(checkpoint,trial,dt,[0.0_real64],exchange,zeros,amount,tolerance,trial_account,status)
    if(status/=0)return
    candidate=trial; account=trial_account; ok=.true.
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

  subroutine copy_reference_transfer(workspace,record,key,amount,ok,head,dt,rate)
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_trial_transfer),intent(inout)::record
    type(macro_trial_key),intent(in)::key
    real(real64),allocatable,intent(out)::amount(:)
    logical,intent(out)::ok
    real(real64),optional,intent(in)::head(:),dt
    real(real64),allocatable,optional,intent(out)::rate(:)
    ok=.false.
    if(.not.workspace_matches(workspace,record)) then
      call discard_reference_transfer(record)
      return
    end if
    call copy_matrix_transfer(record%used,key,amount,ok,head,dt,rate)
    if(.not.ok.and.(present(head).or.present(dt)))call discard_reference_transfer(record)
  end subroutine

  ! Candidate-only paired budget from the actual residual evaluation. Do not
  ! recompute storage or read mutable physical inputs during final accounting.
  subroutine copy_reference_budget(workspace,record,key,head,dt,amount,begin_storage,candidate_storage,ok,rate)
    type(reference_richards_workspace_t),intent(in)::workspace
    type(reference_trial_transfer),intent(inout)::record
    type(macro_trial_key),intent(in)::key
    real(real64),intent(in)::head(:),dt
    real(real64),allocatable,intent(out)::amount(:)
    real(real64),intent(out)::begin_storage,candidate_storage
    real(real64),allocatable,optional,intent(out)::rate(:)
    logical,intent(out)::ok
    begin_storage=0; candidate_storage=0
    call copy_reference_transfer(workspace,record,key,amount,ok,head,dt,rate)
    if(.not.ok)return
    begin_storage=record%begin_storage
    candidate_storage=record%candidate_storage
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
      used%begin_storage=input%storage
      used%candidate_storage=storage_candidate
      used%geometry=input
    end if
  end subroutine
end module
