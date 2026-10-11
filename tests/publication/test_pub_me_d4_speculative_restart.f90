module pub_me_d4_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: d4_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => d4_clone
  end type d4_state_t

  type, extends(canonical_forcing_t), public :: d4_forcing_t
  end type d4_forcing_t

  type, extends(kernel_parameters_t), public :: d4_parameters_t
  end type d4_parameters_t

  type, extends(kernel_model_t), public :: d4_model_t
  contains
    procedure :: configure_parameters => d4_configure_parameters
    procedure :: execution_admitted => d4_execution_admitted
    procedure :: prepare_interval => d4_prepare_interval
    procedure :: advance => d4_advance
    procedure :: storage => d4_storage
    procedure :: storage_accounting_status => d4_storage_status
    procedure :: temporal_error => d4_temporal_error
  end type d4_model_t

  public :: new_state, physical_value, assert_true, same_real

contains

  subroutine new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(d4_state_t :: state)
    select type(s => state)
    type is(d4_state_t)
      s%storage = value
    end select
  end subroutine new_state

  subroutine d4_clone(self, copy)
    class(d4_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(d4_state_t :: copy)
    select type(s => copy)
    type is(d4_state_t)
      s%storage = self%storage
    end select
  end subroutine d4_clone

  subroutine d4_configure_parameters(self, parameters)
    class(d4_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) &
      error stop 'D4 unreachable parameter types'
  end subroutine d4_configure_parameters

  logical function d4_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(d4_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function d4_execution_admitted

  subroutine d4_prepare_interval(self, forcing, interval, config)
    class(d4_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) &
      error stop 'D4 unreachable prepare types'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
      error stop 'D4 invalid interval'
  end subroutine d4_prepare_interval

  subroutine d4_advance(self, state, t0, t1, outcome)
    class(d4_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1-t0
    select type(s => state)
    type is(d4_state_t)
      s%storage = s%storage + dt
    class default
      return
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self,self)) error stop 'D4 unreachable model type'
  end subroutine d4_advance

  function d4_storage(self, state) result(value)
    class(d4_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type(s => state)
    type is(d4_state_t)
      value = s%storage
    end select
    if (.not. same_type_as(self,self)) error stop 'D4 unreachable storage'
  end function d4_storage

  subroutine d4_storage_status(self, state, complete, missing_mask)
    class(d4_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    select type(s => state)
    type is(d4_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    end select
    if (.not. same_type_as(self,self)) error stop 'D4 unreachable storage status'
  end subroutine d4_storage_status

  function d4_temporal_error(self, full_state, half_state) result(value)
    class(d4_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = 0.0_real64
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,full_state) .or. &
        .not. same_type_as(half_state,half_state)) error stop 'D4 unreachable temporal types'
  end function d4_temporal_error

  real(real64) function physical_value(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = huge(0.0_real64)
    if (.not. allocated(state)) return
    select type(s => state)
    type is(d4_state_t)
      value = s%storage
    class default
      error stop 'D4 unexpected physical state type'
    end select
  end function physical_value

  pure logical function same_real(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib)
    equal=ia==ib
  end function same_real

  subroutine assert_true(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D4_FAIL',trim(label)
      error stop 1
    end if
  end subroutine assert_true
end module pub_me_d4_fixture

program test_pub_me_d4_speculative_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, export_kernel_committed_state, &
       reconstruct_kernel_persistence_snapshot_trusted, restore_kernel_committed_state
  use pub_me_d4_fixture, only: d4_model_t,d4_parameters_t,d4_forcing_t,new_state,physical_value,assert_true,same_real
  implicit none

  integer(int64), parameter :: LINEAGE=401_int64
  integer(int64), parameter :: LAYOUT=4101_int64

  type(d4_model_t), target :: model
  type(d4_parameters_t) :: parameters
  type(d4_forcing_t) :: forcing
  type(kernel_executor_t) :: executor
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: accepted, clean_restored, bad_restored
  type(kernel_candidate_state_t) :: speculative, clean_next, restored_next, bad_next
  type(kernel_diagnostics_t) :: speculative_diag, clean_diag, restored_diag, bad_diag
  type(kernel_persistence_snapshot_t) :: clean_snapshot, bad_snapshot
  type(kernel_result_t) :: speculative_result, clean_result, restored_result, bad_result
  class(transaction_state_t), allocatable :: candidate_physical, committed_physical, restored_physical
  logical :: ok, reconstructed, restored, b2_detected, b1_detected
  integer :: status
  real(real64) :: committed_value, candidate_value, restored_bad_value
  real(real64) :: accepted_time, bad_time
  logical :: time_ok

  call setup(executor,model,config)
  call init_committed(accepted)

  ! CLEAN persistence control.
  call export_kernel_committed_state(accepted,LAYOUT,clean_snapshot,ok,status)
  call assert_true(ok .and. status==KERNEL_PERSISTENCE_OK,'clean export succeeds')
  call restore_kernel_committed_state(clean_snapshot,LAYOUT,clean_restored,restored,status,KERNEL_PERSISTENCE_SCHEMA_VERSION)
  call assert_true(restored .and. status==KERNEL_PERSISTENCE_OK,'clean restore succeeds')
  call assert_same_committed(accepted,clean_restored,'clean roundtrip')

  call executor%advance_interval(parameters,accepted,forcing,config,0.0_real64,1.0_real64, &
       clean_result,clean_next,clean_diag)
  call executor%advance_interval(parameters,clean_restored,forcing,config,0.0_real64,1.0_real64, &
       restored_result,restored_next,restored_diag)
  call assert_completed(clean_result,clean_next,'clean source continuation')
  call assert_completed(restored_result,restored_next,'clean restored continuation')
  call assert_candidates_equal(clean_next,restored_next,'clean continuation endpoints')
  call assert_mass_equal(clean_result,restored_result,'clean continuation mass')
  write(*,'(A)') 'PUB_ME_D4_CLEAN_ROUNDTRIP=PASS'
  write(*,'(A)') 'PUB_ME_D4_CLEAN_CONTINUATION=PASS'

  call executor%rollback_candidate(clean_next,clean_diag)
  call executor%rollback_candidate(restored_next,restored_diag)

  ! Fault path: create a real, still-uncommitted candidate.
  call executor%advance_interval(parameters,accepted,forcing,config,0.0_real64,1.0_real64, &
       speculative_result,speculative,speculative_diag)
  call assert_completed(speculative_result,speculative,'speculative candidate execution')

  call accepted%snapshot(committed_physical,ok)
  call assert_true(ok,'accepted physical snapshot')
  call speculative%snapshot(candidate_physical,ok)
  call assert_true(ok,'candidate physical snapshot')
  committed_value=physical_value(committed_physical)
  candidate_value=physical_value(candidate_physical)
  call assert_true(same_real(committed_value,0.0_real64),'accepted source remains zero pre-rollback')
  call assert_true(same_real(candidate_value,1.0_real64),'speculative candidate is one')

  ! B2 direct authority oracle is evaluated before faulty persistence publication.
  b2_detected = .not. same_real(committed_value,candidate_value)
  call assert_true(b2_detected,'B2 detects candidate/accepted physical mismatch before publication')
  write(*,'(A)') 'PUB_ME_D4_B2_PREPUBLICATION_AUTHORITY=DETECTED'

  ! Qualification-only faulty adapter: accepted provenance + speculative physical state.
  call accepted%current_time(accepted_time,time_ok)
  call assert_true(time_ok,'accepted source time available')
  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION,LAYOUT, &
       accepted%current_lineage_id(),accepted%current_revision(),accepted_time,accepted%time_is_bound(), &
       candidate_physical,bad_snapshot,reconstructed,status)

  ! The originating candidate is explicitly rejected/rolled back after the persistence attempt.
  call executor%rollback_candidate(speculative,speculative_diag)
  call assert_true(.not.speculative%ready(),'speculative candidate rolled back')
  call assert_true(speculative_diag%candidate_rollbacks==1,'candidate rollback recorded')
  call snapshot_committed_value(accepted,committed_value)
  call assert_true(same_real(committed_value,0.0_real64),'accepted source unchanged after rollback')
  call assert_true(accepted%current_revision()==0_int64,'accepted revision unchanged after rollback')
  call accepted%current_time(accepted_time,time_ok)
  call assert_true(time_ok .and. same_real(accepted_time,0.0_real64),'accepted time unchanged after rollback')
  write(*,'(A)') 'PUB_ME_D4_ORIGINATING_TRIAL_ROLLBACK=PASS'

  if(.not.reconstructed .or. status/=KERNEL_PERSISTENCE_OK) then
    write(*,'(A)') 'PUB_ME_D4_FAULT_ARTIFACT_RECONSTRUCTED=NO'
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=STRUCTURAL_PREVENTION'
    write(*,'(A)') 'PUB_ME_D4_SPECULATIVE_RESTART_EXPERIMENT=PASS'
    stop
  end if
  write(*,'(A)') 'PUB_ME_D4_FAULT_ARTIFACT_RECONSTRUCTED=YES'

  ! Restore the faulty artifact. If this is refused, D4 is structurally prevented.
  call restore_kernel_committed_state(bad_snapshot,LAYOUT,bad_restored,restored,status,KERNEL_PERSISTENCE_SCHEMA_VERSION)
  if(.not.restored .or. status/=KERNEL_PERSISTENCE_OK) then
    write(*,'(A)') 'PUB_ME_D4_FAULT_ARTIFACT_RESTORE=REJECTED'
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=STRUCTURAL_PREVENTION'
    write(*,'(A)') 'PUB_ME_D4_SPECULATIVE_RESTART_EXPERIMENT=PASS'
    stop
  end if
  write(*,'(A)') 'PUB_ME_D4_FAULT_ARTIFACT_RESTORE=ACCEPTED'

  call bad_restored%snapshot(restored_physical,ok)
  call assert_true(ok,'bad restored physical snapshot')
  restored_bad_value=physical_value(restored_physical)
  call bad_restored%current_time(bad_time,time_ok)
  call assert_true(time_ok,'bad restored time available')

  ! Strong B1 round-trip comparison happens immediately after restore.
  b1_detected = .not. same_real(committed_value,restored_bad_value)
  call assert_true(b1_detected,'B1 restart roundtrip detects physical divergence')
  call assert_true(bad_restored%current_lineage_id()==accepted%current_lineage_id(),'bad provenance lineage matches')
  call assert_true(bad_restored%current_revision()==accepted%current_revision(),'bad provenance revision matches')
  call assert_true(same_real(bad_time,accepted_time),'bad provenance time matches')
  write(*,'(A)') 'PUB_ME_D4_B1_ARTIFACT_ROUNDTRIP=DETECTED'

  ! Demonstrate the scientific consequence if the bad artifact is used anyway.
  call executor%advance_interval(parameters,accepted,forcing,config,0.0_real64,1.0_real64, &
       clean_result,clean_next,clean_diag)
  call executor%advance_interval(parameters,bad_restored,forcing,config,0.0_real64,1.0_real64, &
       bad_result,bad_next,bad_diag)
  call assert_completed(clean_result,clean_next,'post-rollback clean continuation')
  call assert_completed(bad_result,bad_next,'faulty restart continuation')
  call candidate_value_of(clean_next,committed_value)
  call candidate_value_of(bad_next,restored_bad_value)
  call assert_true(.not.same_real(committed_value,restored_bad_value),'faulty restart changes next endpoint')
  call assert_true(same_real(committed_value,1.0_real64),'clean next endpoint one')
  call assert_true(same_real(restored_bad_value,2.0_real64),'faulty restart next endpoint two')
  call assert_true(same_real(clean_result%mass%residual,0.0_real64),'clean continuation mass closes')
  call assert_true(same_real(bad_result%mass%residual,0.0_real64),'faulty continuation mass still closes')
  call assert_true(same_real(clean_result%mass%total_in,bad_result%mass%total_in),'continuation mass input identical')
  write(*,'(A)') 'PUB_ME_D4_SCIENTIFIC_CONSEQUENCE=NEXT_ENDPOINT_DIVERGES'
  write(*,'(A)') 'PUB_ME_D4_MASS_INVARIANT_FALSE_NEGATIVE=PASS'

  if(b2_detected .and. b1_detected) then
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=EARLIER_DETECTION'
  else if(b2_detected .and. .not.b1_detected) then
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=UNIQUE_DETECTION'
  else if(.not.b2_detected .and. b1_detected) then
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=NO_INCREMENTAL_VALUE'
  else
    write(*,'(A)') 'PUB_ME_D4_CLASSIFICATION=D4_AUTHORITY_FAILURE'
  end if
  write(*,'(A)') 'PUB_ME_D4_SPECULATIVE_RESTART_EXPERIMENT=PASS'

contains

  subroutine setup(k,m,c)
    type(kernel_executor_t),intent(out)::k
    type(d4_model_t),target,intent(inout)::m
    type(canonical_numerical_config_t),intent(out)::c
    call k%bind_model(m)
    c=canonical_numerical_config_t()
    c%transaction%mass_tolerance=1.0e-12_real64
    c%transaction%temporal_tolerance=1.0e-12_real64
    c%transaction%max_retries=1
    c%max_committed_substeps=4
  end subroutine setup

  subroutine init_committed(state)
    type(kernel_committed_state_t),intent(out)::state
    class(transaction_state_t),allocatable::initial
    logical::initialized
    call new_state(initial,0.0_real64)
    call state%initialize(LINEAGE,initial,initialized,0.0_real64)
    call assert_true(initialized,'D4 committed initialization')
  end subroutine init_committed

  subroutine snapshot_committed_value(state,value)
    type(kernel_committed_state_t),intent(in)::state
    real(real64),intent(out)::value
    class(transaction_state_t),allocatable::snap
    logical::available
    call state%snapshot(snap,available)
    call assert_true(available,'committed snapshot available')
    value=physical_value(snap)
  end subroutine snapshot_committed_value

  subroutine candidate_value_of(candidate,value)
    type(kernel_candidate_state_t),intent(in)::candidate
    real(real64),intent(out)::value
    class(transaction_state_t),allocatable::snap
    logical::available
    call candidate%snapshot(snap,available)
    call assert_true(available,'candidate snapshot available')
    value=physical_value(snap)
  end subroutine candidate_value_of

  subroutine assert_same_committed(left,right,label)
    type(kernel_committed_state_t),intent(in)::left,right
    character(len=*),intent(in)::label
    real(real64)::lv,rv,lt,rt
    logical::la,ra
    call snapshot_committed_value(left,lv)
    call snapshot_committed_value(right,rv)
    call assert_true(same_real(lv,rv),trim(label)//' physical')
    call assert_true(left%current_lineage_id()==right%current_lineage_id(),trim(label)//' lineage')
    call assert_true(left%current_revision()==right%current_revision(),trim(label)//' revision')
    call left%current_time(lt,la); call right%current_time(rt,ra)
    call assert_true(la .eqv. ra,trim(label)//' time availability')
    if(la) call assert_true(same_real(lt,rt),trim(label)//' time')
  end subroutine assert_same_committed

  subroutine assert_completed(result,candidate,label)
    type(kernel_result_t),intent(in)::result
    type(kernel_candidate_state_t),intent(in)::candidate
    character(len=*),intent(in)::label
    call assert_true(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,trim(label)//' completed')
    call assert_true(candidate%ready(),trim(label)//' candidate ready')
    call assert_true(result%mass%complete,trim(label)//' mass complete')
    call assert_true(result%mass%accepted_transaction_count==1,trim(label)//' one accepted transaction')
  end subroutine assert_completed

  subroutine assert_candidates_equal(left,right,label)
    type(kernel_candidate_state_t),intent(in)::left,right
    character(len=*),intent(in)::label
    real(real64)::lv,rv,lt0,lt1,rt0,rt1
    logical::la,ra
    call candidate_value_of(left,lv); call candidate_value_of(right,rv)
    call assert_true(same_real(lv,rv),trim(label)//' physical')
    call assert_true(left%current_lineage_id()==right%current_lineage_id(),trim(label)//' lineage')
    call assert_true(left%origin_revision()==right%origin_revision(),trim(label)//' revision')
    call left%origin_interval(lt0,lt1,la); call right%origin_interval(rt0,rt1,ra)
    call assert_true(la .and. ra,trim(label)//' interval available')
    call assert_true(same_real(lt0,rt0) .and. same_real(lt1,rt1),trim(label)//' interval')
  end subroutine assert_candidates_equal

  subroutine assert_mass_equal(left,right,label)
    type(kernel_result_t),intent(in)::left,right
    character(len=*),intent(in)::label
    call assert_true(left%mass%complete .and. right%mass%complete,trim(label)//' complete')
    call assert_true(same_real(left%mass%storage_start,right%mass%storage_start),trim(label)//' storage start')
    call assert_true(same_real(left%mass%storage_end,right%mass%storage_end),trim(label)//' storage end')
    call assert_true(same_real(left%mass%total_in,right%mass%total_in),trim(label)//' total in')
    call assert_true(same_real(left%mass%total_out,right%mass%total_out),trim(label)//' total out')
    call assert_true(same_real(left%mass%residual,right%mass%residual),trim(label)//' residual')
  end subroutine assert_mass_equal

end program test_pub_me_d4_speculative_restart
