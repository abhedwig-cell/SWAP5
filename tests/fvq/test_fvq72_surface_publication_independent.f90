program test_fvq72_surface_publication_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_surface_evaporation_runtime_materialization, only: fmr_surface_evaporation_runtime_diagnostics_t, &
       FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH
  use mod_fmr_surface_evaporation_accepted_publication, only: fmr_surface_evaporation_publication_t, &
       fmr_commit_candidate_with_surface_evaporation_publication, FMR_SURFACE_EVAP_PUBLICATION_OK, &
       FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED
  use mod_fmr_accepted_commit_receipt, only: FMR_COMMIT_RECEIPT_OK
  use mod_fmr43_test_support, only: fmr43_parameters_t, fmr43_forcing_t, fmr43_model_t, fmr43_capacity_provider_t
  implicit none

  real(real64), parameter :: t0=41.0_real64, t1=44.5_real64
  type(fmr43_parameters_t) :: parameters
  type(fmr43_forcing_t) :: forcing
  type(fmr43_model_t), target :: model_trial, model_commit, model_same, model_plain
  type(kernel_executor_t) :: trial_kernel, commit_kernel, same_kernel, plain_kernel
  type(canonical_numerical_config_t) :: config
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr43_capacity_provider_t) :: good, invalid
  type(fmr_surface_evaporation_publication_t) :: accepted_reference, pub
  type(kernel_committed_state_t) :: state, target_state, source_state, plain_state, atomic_state
  type(kernel_checkpoint_t) :: cp, target_cp, source_cp, plain_cp, atomic_cp
  type(kernel_candidate_state_t) :: cand, cand_a, cand_b, source_cand, plain_cand, atomic_cand
  type(kernel_diagnostics_t) :: diag, target_diag, source_diag, plain_diag, atomic_diag
  class(transaction_state_t), allocatable :: before_state, after_state, plain_physical, atomic_physical
  integer(int64) :: rev0
  integer :: ps, rs, cs, plain_commit_status, mass_rejections_before, i
  logical :: did_commit, ok, snap_ok

  config=canonical_numerical_config_t()
  config%max_committed_substeps=8
  config%progress_tolerance=0.0_real64
  et=reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day=0.40_real64
  et%potential_pond_evaporation_cm_per_day=0.60_real64
  et_diag=fmr_reference_et_binding_diagnostics_t()
  et_diag%status=FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced=.true.
  good%capacity=0.13_real64
  invalid%capacity=0.13_real64
  invalid%make_invalid=.true.

  call trial_kernel%bind_model(model_trial)
  call commit_kernel%bind_model(model_commit)
  call same_kernel%bind_model(model_same)
  call plain_kernel%bind_model(model_plain)

  ! Positive control: same executor, standalone-style.
  call setup_candidate(72001_int64,0.0_real64,same_kernel,state,cp,cand,diag)
  call atomic_publish(same_kernel,state,cp,cand,diag,good,accepted_reference,did_commit,ps,rs,cs)
  call require(did_commit,'same-executor commit')
  call require(ps==FMR_SURFACE_EVAP_PUBLICATION_OK .and. rs==FMR_COMMIT_RECEIPT_OK .and. &
       cs==KERNEL_COMMIT_STATUS_COMMITTED,'same-executor statuses')
  call require(accepted_reference%ready(),'same-executor publication ready')
  call require(accepted_reference%current_lineage_id()==72001_int64,'same-executor lineage')
  call require(accepted_reference%origin_revision()==0_int64 .and. accepted_reference%committed_revision()==1_int64, &
       'same-executor revisions')
  write(*,'(A)') 'FVQ72_ACCEPTED_ONCE=PASS'
  write(*,'(A)') 'FVQ72_SAME_EXECUTOR_STANDALONE=PASS'

  ! Positive control: separate trial and commit executors, serialized MultiSWAP-style.
  call setup_candidate(72002_int64,0.0_real64,trial_kernel,state,cp,cand,diag)
  call atomic_publish(commit_kernel,state,cp,cand,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'cross-executor publication')
  call require_close(pub%bare_soil_evaporation_rate(),accepted_reference%bare_soil_evaporation_rate(),'cross-executor rate')
  call require(trim(pub%route())==trim(accepted_reference%route()),'cross-executor route')
  write(*,'(A)') 'FVQ72_SERIALIZED_MULTISWAP_EQUIVALENCE=PASS'

  ! Independent mass/commit control: atomic wrapper must produce the same physical commit as plain F-KT commit.
  call setup_candidate(72003_int64,0.0_real64,plain_kernel,plain_state,plain_cp,plain_cand,plain_diag)
  call setup_candidate(72004_int64,0.0_real64,trial_kernel,atomic_state,atomic_cp,atomic_cand,atomic_diag)
  call plain_kernel%commit_candidate(plain_state,plain_cand,plain_diag,did_commit,plain_commit_status)
  call require(did_commit .and. plain_commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'plain commit')
  mass_rejections_before=atomic_diag%mass_rejections
  call atomic_publish(commit_kernel,atomic_state,atomic_cp,atomic_cand,atomic_diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'atomic control commit')
  call require(atomic_diag%mass_rejections==mass_rejections_before,'atomic mass diagnostics unchanged')
  call plain_state%snapshot(plain_physical,snap_ok); call require(snap_ok,'plain snapshot')
  call atomic_state%snapshot(atomic_physical,snap_ok); call require(snap_ok,'atomic snapshot')
  call require_same_physical(plain_physical,atomic_physical,'plain-vs-atomic')
  call require(plain_state%current_revision()==1_int64 .and. atomic_state%current_revision()==1_int64,'commit revisions equal')
  write(*,'(A)') 'FVQ72_ATOMIC_PLAIN_COMMIT_PHYSICAL_EQUIVALENCE=PASS'
  write(*,'(A)') 'FVQ72_NO_SECOND_MASS_BOOKING=PASS'

  ! Reject must clear preloaded output and preserve committed state bit-for-bit at exposed state values.
  call setup_candidate(72005_int64,0.0_real64,trial_kernel,state,cp,cand,diag)
  rev0=state%current_revision()
  call state%snapshot(before_state,snap_ok); call require(snap_ok,'reject before snapshot')
  pub=accepted_reference
  call atomic_publish(commit_kernel,state,cp,cand,diag,invalid,pub,did_commit,ps,rs,cs)
  call require(.not.did_commit .and. .not.pub%ready(),'reject publication absent')
  call require(ps==FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED,'reject status')
  call require(state%current_revision()==rev0 .and. cand%ready(),'reject ownership unchanged')
  call state%snapshot(after_state,snap_ok); call require(snap_ok,'reject after snapshot')
  call require_same_physical(before_state,after_state,'single-reject')
  write(*,'(A)') 'FVQ72_REJECT_IMMUTABILITY=PASS_EXACT_COMMITTED_STATE'
  write(*,'(A)') 'FVQ72_PRELOADED_OUTPUT_CLEARED=PASS'

  ! Reject -> accept: only accepted candidate is published.
  call atomic_publish(commit_kernel,state,cp,cand,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'reject-accept accepted')
  call require(state%current_revision()==rev0+1_int64,'reject-accept single revision')
  call require(pub%origin_revision()==rev0 .and. pub%committed_revision()==rev0+1_int64,'reject-accept provenance')
  write(*,'(A)') 'FVQ72_REJECT_THEN_ACCEPT=PASS'

  ! Two rejects -> accept: no rejected accumulation or state mutation.
  call setup_candidate(72006_int64,0.0_real64,trial_kernel,state,cp,cand,diag)
  rev0=state%current_revision()
  call state%snapshot(before_state,snap_ok); call require(snap_ok,'double reject before')
  do i=1,2
    pub=accepted_reference
    call atomic_publish(commit_kernel,state,cp,cand,diag,invalid,pub,did_commit,ps,rs,cs)
    call require(.not.did_commit .and. .not.pub%ready(),'double reject absent')
    call require(state%current_revision()==rev0 .and. cand%ready(),'double reject ownership')
  end do
  call state%snapshot(after_state,snap_ok); call require(snap_ok,'double reject after')
  call require_same_physical(before_state,after_state,'double-reject')
  call atomic_publish(commit_kernel,state,cp,cand,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready() .and. state%current_revision()==rev0+1_int64,'double reject accept')
  write(*,'(A)') 'FVQ72_REJECT_REJECT_ACCEPT_NO_ACCUMULATION=PASS'

  ! Retry exhaustion leaves committed state exactly unchanged.
  call setup_candidate(72007_int64,0.0_real64,trial_kernel,state,cp,cand,diag)
  rev0=state%current_revision()
  call state%snapshot(before_state,snap_ok); call require(snap_ok,'exhaust before')
  do i=1,3
    pub=accepted_reference
    call atomic_publish(commit_kernel,state,cp,cand,diag,invalid,pub,did_commit,ps,rs,cs)
    call require(.not.did_commit .and. .not.pub%ready(),'exhaust reject absent')
  end do
  call state%snapshot(after_state,snap_ok); call require(snap_ok,'exhaust after')
  call require(state%current_revision()==rev0 .and. cand%ready(),'exhaust ownership')
  call require_same_physical(before_state,after_state,'exhaustion')
  write(*,'(A)') 'FVQ72_RETRY_EXHAUSTION=PASS_NO_ACCEPTED_PUBLICATION'

  ! Cross-lineage candidate cannot reach commit/publication.
  call setup_candidate(72008_int64,0.0_real64,trial_kernel,source_state,source_cp,source_cand,source_diag)
  call initialize_only(72009_int64,0.0_real64,target_state)
  call target_state%capture_checkpoint(target_cp,ok); call require(ok,'target checkpoint')
  target_diag=kernel_diagnostics_t()
  rev0=target_state%current_revision()
  call target_state%snapshot(before_state,snap_ok); call require(snap_ok,'cross-lineage before')
  call atomic_publish(commit_kernel,target_state,target_cp,source_cand,source_diag,good,pub,did_commit,ps,rs,cs)
  call require(.not.did_commit .and. .not.pub%ready(),'cross-lineage no publication')
  call require(ps==FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED,'cross-lineage publication status')
  call require(target_state%current_revision()==rev0 .and. source_cand%ready(),'cross-lineage ownership')
  call target_state%snapshot(after_state,snap_ok); call require(snap_ok,'cross-lineage after')
  call require_same_physical(before_state,after_state,'cross-lineage')
  write(*,'(A)') 'FVQ72_CROSS_LINEAGE_FAIL_CLOSED=PASS'

  ! Same-origin alternate candidate becomes stale after candidate A commits.
  call initialize_only(72010_int64,0.0_real64,state)
  call state%capture_checkpoint(cp,ok); call require(ok,'alternate checkpoint')
  diag=kernel_diagnostics_t()
  call make_candidate(trial_kernel,state,cp,cand_a,diag)
  call make_candidate(trial_kernel,state,cp,cand_b,diag)
  call atomic_publish(commit_kernel,state,cp,cand_a,diag,good,pub,did_commit,ps,rs,cs)
  call require(did_commit .and. pub%ready(),'alternate A accepted')
  rev0=state%current_revision()
  call atomic_publish(commit_kernel,state,cp,cand_b,diag,good,pub,did_commit,ps,rs,cs)
  call require(.not.did_commit .and. .not.pub%ready(),'alternate B stale rejected')
  call require(ps==FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED,'alternate B status')
  call require(state%current_revision()==rev0 .and. cand_b%ready(),'alternate B no mutation')
  write(*,'(A)') 'FVQ72_SAME_ORIGIN_ALTERNATE_AFTER_ACCEPT=PASS_FAIL_CLOSED'

  write(*,'(A)') 'FVQ72_INDEPENDENT_ORACLE=PASS'

contains
  subroutine initialize_only(lineage,ponding,s)
    integer(int64),intent(in)::lineage
    real(real64),intent(in)::ponding
    type(kernel_committed_state_t),intent(out)::s
    class(transaction_state_t),allocatable::physical
    logical::initialized
    allocate(fmr_b110_physical_state_t::physical)
    select type(p=>physical); type is(fmr_b110_physical_state_t)
      p%active_nodes=2
      allocate(p%pressure_head(2),p%water_content(2))
      p%pressure_head=[-100.0_real64,-250.0_real64]
      p%water_content=[0.22_real64,0.25_real64]
      p%ponding_depth=ponding
      p%groundwater_level=-175.0_real64
    end select
    call s%initialize(lineage,physical,initialized,t0)
    call require(initialized,'initialize')
  end subroutine initialize_only

  subroutine setup_candidate(lineage,ponding,kernel,s,c,candidate,d)
    integer(int64),intent(in)::lineage
    real(real64),intent(in)::ponding
    type(kernel_executor_t),intent(inout)::kernel
    type(kernel_committed_state_t),intent(out)::s
    type(kernel_checkpoint_t),intent(out)::c
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(out)::d
    logical::ready
    call initialize_only(lineage,ponding,s)
    call s%capture_checkpoint(c,ready); call require(ready,'checkpoint')
    d=kernel_diagnostics_t()
    call make_candidate(kernel,s,c,candidate,d)
  end subroutine setup_candidate

  subroutine make_candidate(kernel,s,c,candidate,d)
    type(kernel_executor_t),intent(inout)::kernel
    type(kernel_committed_state_t),intent(in)::s
    type(kernel_checkpoint_t),intent(in)::c
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(inout)::d
    type(kernel_result_t)::r
    call kernel%advance_interval(parameters,s,forcing,config,t0,t1,r,candidate,d,c)
    call require(r%completed,'trial completed')
    call require(r%mass%complete,'trial mass complete')
    call require(candidate%ready(),'candidate ready')
  end subroutine make_candidate

  subroutine atomic_publish(kernel,s,c,candidate,d,provider,outpub,committed,publication_status,receipt_status,commit_status)
    type(kernel_executor_t),intent(inout)::kernel
    type(kernel_committed_state_t),intent(inout)::s
    type(kernel_checkpoint_t),intent(in)::c
    type(kernel_candidate_state_t),intent(inout)::candidate
    type(kernel_diagnostics_t),intent(inout)::d
    type(fmr43_capacity_provider_t),intent(in)::provider
    type(fmr_surface_evaporation_publication_t),intent(out)::outpub
    logical,intent(out)::committed
    integer,intent(out)::publication_status,receipt_status,commit_status
    type(fmr_surface_evaporation_runtime_diagnostics_t)::surface_diag
    call fmr_commit_candidate_with_surface_evaporation_publication(kernel,c,s,candidate,d,et,et_diag,provider,committed, &
         outpub,surface_diag,publication_status,receipt_status,commit_status)
    if (publication_status==FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED) then
      if (surface_diag%status==FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH) continue
    end if
  end subroutine atomic_publish

  subroutine require_same_physical(lhs,rhs,label)
    class(transaction_state_t),allocatable,intent(in)::lhs,rhs
    character(len=*),intent(in)::label
    call require(allocated(lhs) .and. allocated(rhs),label//' allocated')
    select type(a=>lhs); type is(fmr_b110_physical_state_t)
      select type(b=>rhs); type is(fmr_b110_physical_state_t)
        call require(a%active_nodes==b%active_nodes,label//' nodes')
        call require(allocated(a%pressure_head) .and. allocated(b%pressure_head),label//' heads allocated')
        call require(allocated(a%water_content) .and. allocated(b%water_content),label//' water allocated')
        call require(all(a%pressure_head==b%pressure_head),label//' head exact')
        call require(all(a%water_content==b%water_content),label//' water exact')
        call require(a%ponding_depth==b%ponding_depth,label//' ponding exact')
        call require(a%groundwater_level==b%groundwater_level,label//' groundwater exact')
        call require(allocated(a%snow) .eqv. allocated(b%snow),label//' snow allocation')
        call require(allocated(a%soil_temperature) .eqv. allocated(b%soil_temperature),label//' temperature allocation')
      class default
        call require(.false.,label//' rhs type')
      end select
    class default
      call require(.false.,label//' lhs type')
    end select
  end subroutine require_same_physical

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'FVQ72_REQUIRE_FAIL',trim(label)
      error stop 72
    end if
  end subroutine require

  subroutine require_close(actual,expected,label)
    real(real64),intent(in)::actual,expected
    character(len=*),intent(in)::label
    call require(abs(actual-expected)<=1.0e-12_real64,label)
  end subroutine require_close
end program test_fvq72_surface_publication_independent
