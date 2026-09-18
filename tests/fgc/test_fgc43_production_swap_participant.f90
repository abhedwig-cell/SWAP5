module test_fgc43_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_UNSPECIFIED
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, &
       GW_SWAP_FORCING_OK, GW_SWAP_FORCING_INVALID_HEAD
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  implicit none

  type, extends(canonical_state_t) :: state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => clone_state
  end type state_t

  type, extends(canonical_forcing_t) :: forcing_t
    real(real64) :: head_m = 0.0_real64
  end type forcing_t

  type, extends(kernel_parameters_t) :: parameters_t
  end type parameters_t

  type, extends(kernel_model_t) :: model_t
    real(real64) :: active_head_m = 0.0_real64
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance_model
    procedure :: storage => storage_model
    procedure :: storage_accounting_status => storage_status
    procedure :: temporal_error => temporal_error
    procedure :: accepted_trajectory_direction_snapshot => trajectory_snapshot
  end type model_t

  type, extends(groundwater_swap_forcing_materializer_t) :: materializer_t
  contains
    procedure :: profile_admitted => profile_admitted
    procedure :: materialize => materialize
  end type materializer_t

contains

  subroutine make_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(state_t :: state)
    select type(s => state)
    type is(state_t)
      s%storage = value
    end select
  end subroutine make_state

  subroutine clone_state(self, copy)
    class(state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(state_t :: copy)
    select type(c => copy)
    type is(state_t)
      c%storage = self%storage
    end select
  end subroutine clone_state

  subroutine configure_parameters(self, parameters)
    class(model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 4301
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config) result(ok)
    class(model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    ok = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type(f => forcing)
    type is(forcing_t)
      self%active_head_m = f%head_m
    class default
      error stop 4302
    end select
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 4303
  end subroutine prepare_interval

  subroutine advance_model(self, state, t0, t1, outcome)
    class(model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, qout
    outcome = trial_outcome_t()
    dt = t1-t0
    qout = 0.2_real64 + 0.01_real64*self%active_head_m
    select type(s => state)
    type is(state_t)
      s%storage = s%storage + (1.0_real64-qout)*dt
    class default
      return
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = qout*dt
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%bottom_interface_exchange_available = .true.
    outcome%bottom_outward_exchange_native = qout*dt
    outcome%terminal_bottom_outward_flux_native = qout
  end subroutine advance_model

  function storage_model(self, state) result(value)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type(s => state)
    type is(state_t)
      value = s%storage
    end select
    if (.not. same_type_as(self,self)) error stop 4304
  end function storage_model

  subroutine storage_status(self, state, complete, missing_mask)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.; missing_mask = TX_MASS_MISSING_UNSPECIFIED
    select type(s => state)
    type is(state_t)
      complete=.true.; missing_mask=TX_MASS_MISSING_NONE
    end select
    if (.not. same_type_as(self,self)) error stop 4305
  end subroutine storage_status

  function temporal_error(self, full_state, half_state) result(value)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = 0.0_real64
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,full_state) .or. &
        .not. same_type_as(half_state,half_state)) error stop 4306
  end function temporal_error

  subroutine trajectory_snapshot(self, interval, result)
    class(model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    type(accepted_trajectory_direction_result_t), intent(out) :: result
    result = accepted_trajectory_direction_result_t()
    if (interval%t1 <= interval%t0 .or. .not. same_type_as(self,self)) error stop 4307
  end subroutine trajectory_snapshot

  logical function profile_admitted(self, parameters) result(ok)
    class(materializer_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    ok = same_type_as(self,self) .and. same_type_as(parameters,parameters)
  end function profile_admitted

  subroutine materialize(self, interface_head_m, datum, forcing, status)
    class(materializer_t), intent(in) :: self
    real(real64), intent(in) :: interface_head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    class(canonical_forcing_t), allocatable, intent(out) :: forcing
    integer, intent(out) :: status
    status = GW_SWAP_FORCING_INVALID_HEAD
    if (.not. datum%valid() .or. interface_head_m /= interface_head_m) return
    allocate(forcing_t :: forcing)
    select type(f => forcing)
    type is(forcing_t)
      f%head_m = interface_head_m
    end select
    if (.not. same_type_as(self,self)) error stop 4308
    status = GW_SWAP_FORCING_OK
  end subroutine materialize

  subroutine assert_true(x,msg)
    logical,intent(in)::x
    character(len=*),intent(in)::msg
    if(.not.x)then
      print '(A)','FAIL: '//trim(msg); error stop 1
    end if
  end subroutine assert_true
end module test_fgc43_fixture

program test_fgc43_production_swap_participant
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_transaction_participant_t, &
       groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK, GW_SWAP_PARTICIPANT_CANDIDATE_BUSY, &
       GW_SWAP_PARTICIPANT_PREFLIGHT_FAILED
  use test_fgc43_fixture
  implicit none

  type(model_t), target :: model
  type(parameters_t) :: parameters
  type(materializer_t) :: materializer
  type(kernel_committed_state_t) :: committed
  type(kernel_executor_t) :: executor
  type(groundwater_swap_transaction_participant_t) :: participant
  type(groundwater_swap_trial_t) :: trial1, trial2
  type(canonical_numerical_config_t) :: numerical
  type(groundwater_coupling_window_t) :: window
  type(groundwater_head_datum_t) :: datum
  class(transaction_state_t), allocatable :: initial_state, snapshot
  type(forcing_t) :: direct_forcing
  type(kernel_candidate_state_t) :: competing_candidate
  type(kernel_result_t) :: competing_result
  type(kernel_diagnostics_t) :: competing_diag
  logical :: initialized, did_commit, available
  integer :: status, commit_status
  real(real64) :: committed_time

  call make_state(initial_state,0.0_real64)
  call committed%initialize(7001_int64,initial_state,initialized,0.0_real64)
  call assert_true(initialized,'initialize committed SWAP state')
  call executor%bind_model(model)

  numerical%transaction%mass_tolerance=1.0e-12_real64
  numerical%transaction%temporal_tolerance=1.0e-12_real64
  numerical%transaction%max_retries=1
  numerical%max_committed_substeps=4
  window%t0=0.0_real64; window%t1=1.0_real64
  datum%available=.true.; datum%datum_id=91_int64; datum%bottom_boundary_elevation_m=-1.0_real64

  call participant%capture_origin(committed,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_OK,'capture production origin')
  call assert_true(participant%captured_lineage_id()==7001_int64,'captured lineage')
  call assert_true(participant%captured_revision()==0_int64,'captured revision')

  call participant%trial_from_origin(executor,parameters,committed,materializer,numerical,datum,window,2.0_real64,trial1,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_OK .and. trial1%valid,'first corrector trial')
  call assert_true(participant%has_live_candidate(),'first candidate live')
  call assert_true(committed%current_revision()==0_int64,'trial does not mutate committed state')
  call participant%trial_from_origin(executor,parameters,committed,materializer,numerical,datum,window,3.0_real64,trial2,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_CANDIDATE_BUSY,'second trial blocked until discard')

  call participant%discard_candidate(executor)
  call assert_true(.not.participant%has_live_candidate(),'discard clears candidate')
  call participant%trial_from_origin(executor,parameters,committed,materializer,numerical,datum,window,3.0_real64,trial2,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_OK .and. trial2%valid,'second corrector from same origin')
  call assert_true(participant%publication_ready(committed,window),'publication preflight')
  call assert_true(committed%current_revision()==0_int64,'preflight nonmutating')

  call participant%commit_candidate(executor,committed,window,did_commit,status)
  call assert_true(did_commit .and. status==GW_SWAP_PARTICIPANT_OK,'participant commit')
  call assert_true(committed%current_revision()==1_int64,'kernel sole revision mutation')
  call committed%current_time(committed_time,available)
  call assert_true(available .and. abs(committed_time-1.0_real64)<1.0e-14_real64,'kernel sole time mutation')
  call committed%snapshot(snapshot,available)
  call assert_true(available,'committed snapshot available')
  select type(s => snapshot)
  type is(state_t)
    call assert_true(abs(s%storage-0.77_real64)<1.0e-12_real64,'second trial started from immutable origin')
  class default
    call assert_true(.false.,'snapshot type')
  end select
  call assert_true(.not.participant%has_origin() .and. .not.participant%has_live_candidate(),'participant reset after commit')

  ! Re-capture at revision 1, create a live participant candidate, then mutate
  ! committed state through the kernel with a competing candidate. Publication
  ! preflight must detect the stale origin before the participant can commit.
  window%t0=1.0_real64; window%t1=2.0_real64
  call participant%capture_origin(committed,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_OK,'recapture revision one')
  call participant%trial_from_origin(executor,parameters,committed,materializer,numerical,datum,window,4.0_real64,trial1,status)
  call assert_true(status==GW_SWAP_PARTICIPANT_OK,'stale-origin setup trial')

  direct_forcing%head_m=5.0_real64
  call executor%advance_interval(parameters,committed,direct_forcing,numerical,1.0_real64,2.0_real64, &
       competing_result,competing_candidate,competing_diag)
  call assert_true(competing_result%completed .and. competing_candidate%ready(),'competing candidate')
  call executor%commit_candidate(committed,competing_candidate,competing_diag,did_commit,commit_status)
  call assert_true(did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'competing commit')
  call assert_true(.not.participant%publication_ready(committed,window),'stale origin rejected by preflight')
  call participant%commit_candidate(executor,committed,window,did_commit,status)
  call assert_true(.not.did_commit .and. status==GW_SWAP_PARTICIPANT_PREFLIGHT_FAILED,'stale participant cannot commit')
  call assert_true(committed%current_revision()==2_int64,'failed participant publish does not mutate committed state')
  call participant%discard_candidate(executor)

  print '(A)','FGC43_REAL_KERNEL_CHECKPOINT_ORIGIN=PASS'
  print '(A)','FGC43_REPEATED_CORRECTORS_SAME_ORIGIN=PASS'
  print '(A)','FGC43_PREFLIGHT_NONMUTATING=PASS'
  print '(A)','FGC43_KERNEL_SOLE_COMMIT_OWNER=PASS'
  print '(A)','FGC43_STALE_ORIGIN_FAIL_CLOSED=PASS'
  print '(A)','F-GC43 PRODUCTION SWAP PARTICIPANT GATE PASS'
end program test_fgc43_production_swap_participant
