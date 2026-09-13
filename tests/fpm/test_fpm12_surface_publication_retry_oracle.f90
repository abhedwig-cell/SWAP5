program test_fpm12_surface_publication_retry_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_surface_evaporation_runtime_materialization, only: fmr_surface_evaporation_runtime_diagnostics_t
  use mod_fmr_surface_evaporation_accepted_publication, only: fmr_surface_evaporation_publication_t, &
       fmr_commit_candidate_with_surface_evaporation_publication
  use mod_fmr43_test_support, only: fmr43_parameters_t, fmr43_forcing_t, fmr43_model_t, fmr43_capacity_provider_t
  implicit none
  real(real64), parameter :: t0=31.0_real64, t1=35.0_real64
  type(fmr43_parameters_t) :: parameters
  type(fmr43_forcing_t) :: forcing
  type(fmr43_model_t), target :: trial_model, commit_model
  type(kernel_executor_t) :: trial_kernel, commit_kernel
  type(canonical_numerical_config_t) :: config
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr43_capacity_provider_t) :: good, bad
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diag
  type(fmr_surface_evaporation_publication_t) :: pub, seed
  integer(int64) :: rev0
  integer :: ps, rs, cs, i
  logical :: did_commit

  config%max_committed_substeps=8
  et%potential_soil_evaporation_cm_per_day=0.40_real64
  et%potential_pond_evaporation_cm_per_day=0.60_real64
  et_diag%status=FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced=.true.
  good%capacity=0.11_real64
  bad%capacity=0.11_real64
  bad%make_invalid=.true.
  call trial_kernel%bind_model(trial_model)
  call commit_kernel%bind_model(commit_model)

  call setup(12001_int64, committed, checkpoint, candidate, diag)
  call publish(committed,checkpoint,candidate,diag,good,seed,did_commit,ps,rs,cs)
  call require(did_commit .and. seed%ready(),'seed acceptance')
  write(*,'(A)') 'FPM12_ACCEPTED_ONCE=PASS'

  call setup(12002_int64, committed, checkpoint, candidate, diag)
  rev0=committed%current_revision()
  pub=seed
  call publish(committed,checkpoint,candidate,diag,bad,pub,did_commit,ps,rs,cs)
  call require(.not.did_commit .and. .not.pub%ready(),'reject no publication')
  call require(committed%current_revision()==rev0 .and. candidate%ready(),'reject immutable')
  write(*,'(A)') 'FPM12_REJECT_ZERO_PUBLICATION=PASS'
  write(*,'(A)') 'FPM12_STALE_OUTPUT_CLEARED=PASS'
  call publish(committed,checkpoint,candidate,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'reject accept')
  call require(committed%current_revision()==rev0+1_int64,'reject accept one commit')
  write(*,'(A)') 'FPM12_REJECT_THEN_ACCEPT=PASS'

  call setup(12003_int64, committed, checkpoint, candidate, diag)
  rev0=committed%current_revision()
  do i=1,2
    pub=seed
    call publish(committed,checkpoint,candidate,diag,bad,pub,did_commit,ps,rs,cs)
    call require(.not.did_commit .and. .not.pub%ready(),'double reject no publication')
    call require(committed%current_revision()==rev0 .and. candidate%ready(),'double reject immutable')
  end do
  call publish(committed,checkpoint,candidate,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'double reject accept')
  call require(committed%current_revision()==rev0+1_int64,'double reject one commit')
  write(*,'(A)') 'FPM12_REJECT_REJECT_ACCEPT_NO_ACCUMULATION=PASS'

  call setup(12004_int64, committed, checkpoint, candidate, diag)
  rev0=committed%current_revision()
  do i=1,3
    pub=seed
    call publish(committed,checkpoint,candidate,diag,bad,pub,did_commit,ps,rs,cs)
    call require(.not.did_commit .and. .not.pub%ready(),'exhaustion no publication')
    call require(committed%current_revision()==rev0 .and. candidate%ready(),'exhaustion immutable')
  end do
  write(*,'(A)') 'FPM12_RETRY_EXHAUSTION_NO_PUBLICATION=PASS'
  write(*,'(A)') 'FPM12_RETRY_ORACLE=PASS'
contains
  subroutine setup(lineage,state,cp,cand,d)
    integer(int64),intent(in)::lineage
    type(kernel_committed_state_t),intent(out)::state
    type(kernel_checkpoint_t),intent(out)::cp
    type(kernel_candidate_state_t),intent(out)::cand
    type(kernel_diagnostics_t),intent(out)::d
    type(kernel_result_t)::r
    class(transaction_state_t),allocatable::physical
    logical::ok
    allocate(fmr_b110_physical_state_t::physical)
    select type(p=>physical); type is(fmr_b110_physical_state_t)
      p%active_nodes=2; allocate(p%pressure_head(2),p%water_content(2))
      p%pressure_head=[-100.0_real64,-250.0_real64]; p%water_content=[0.22_real64,0.25_real64]
      p%ponding_depth=0.0_real64; p%groundwater_level=-175.0_real64
    end select
    call state%initialize(lineage,physical,ok,t0); call require(ok,'initialize')
    call state%capture_checkpoint(cp,ok); call require(ok,'checkpoint')
    d=kernel_diagnostics_t()
    call trial_kernel%advance_interval(parameters,state,forcing,config,t0,t1,r,cand,d,cp)
    call require(r%completed .and. r%mass%complete .and. cand%ready(),'candidate')
  end subroutine setup
  subroutine publish(state,cp,cand,d,provider,outpub,ok,ps,rs,cs)
    type(kernel_committed_state_t),intent(inout)::state
    type(kernel_checkpoint_t),intent(in)::cp
    type(kernel_candidate_state_t),intent(inout)::cand
    type(kernel_diagnostics_t),intent(inout)::d
    type(fmr43_capacity_provider_t),intent(in)::provider
    type(fmr_surface_evaporation_publication_t),intent(out)::outpub
    logical,intent(out)::ok
    integer,intent(out)::ps,rs,cs
    type(fmr_surface_evaporation_runtime_diagnostics_t)::sd
    call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel,cp,state,cand,d,et,et_diag,provider,ok,outpub,sd,ps,rs,cs)
  end subroutine publish
  subroutine require(condition,label)
    logical,intent(in)::condition; character(len=*),intent(in)::label
    if(.not.condition)then; write(*,'(A,1X,A)')'FPM12_REQUIRE_FAIL',trim(label); error stop 12; end if
  end subroutine require
end program test_fpm12_surface_publication_retry_oracle
