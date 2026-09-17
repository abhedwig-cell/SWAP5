module pub_me_d6_support
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE
  use mod_fmr_surface_evaporation_runtime_materialization, only: fmr_candidate_bound_surface_evaporation_t
  use mod_fmr_surface_evaporation_accepted_publication, only: fmr_surface_evaporation_publication_t
  implicit none
  private

  type, extends(kernel_parameters_t), public :: d6_parameters_t
  end type d6_parameters_t

  type, extends(canonical_forcing_t), public :: d6_forcing_t
  end type d6_forcing_t

  type, extends(kernel_model_t), public :: d6_model_t
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type d6_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: d6_capacity_provider_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: evaluate => capacity_evaluate
  end type d6_capacity_provider_t

  type, public :: d6_event_t
    logical :: initialized = .false.
    logical :: accepted_source = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: bare_rate = 0.0_real64
    real(real64) :: ponded_rate = 0.0_real64
    character(len=24) :: route = 'none'
  end type d6_event_t

  type, public :: d6_event_sink_t
    integer :: count = 0
    type(d6_event_t) :: events(4)
  contains
    procedure :: publish_candidate_unguarded
    procedure :: publish_accepted
  end type d6_event_sink_t

contains

  subroutine configure_parameters(self, parameters)
    class(d6_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'D6 configure'
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(d6_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(d6_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'D6 prepare'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'D6 interval'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(d6_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'D6 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'D6 state'
    class default
      error stop 'D6 state type'
    end select
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine advance

  real(real64) function storage(self, state) result(value)
    class(d6_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'D6 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 41.0_real64 + state%ponding_depth
    class default
      error stop 'D6 storage state'
    end select
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(d6_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'D6 accounting'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(d6_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'D6 temporal'
    value = 0.0_real64
  end function temporal_error

  subroutine capacity_evaluate(self, base_state, result)
    class(d6_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%value
    result%route = 'pub-me-d6'
  end subroutine capacity_evaluate

  subroutine publish_candidate_unguarded(self, bound)
    class(d6_event_sink_t), intent(inout) :: self
    type(fmr_candidate_bound_surface_evaporation_t), intent(in) :: bound
    real(real64) :: t0, t1
    logical :: available
    if (.not. bound%ready()) error stop 'D6 candidate event not ready'
    if (self%count >= size(self%events)) error stop 'D6 event sink full'
    call bound%origin_interval(t0, t1, available)
    if (.not. available) error stop 'D6 candidate interval unavailable'
    self%count = self%count + 1
    self%events(self%count)%initialized = .true.
    self%events(self%count)%accepted_source = .false.
    self%events(self%count)%lineage_id = bound%current_lineage_id()
    self%events(self%count)%origin_revision = bound%origin_revision()
    self%events(self%count)%t0 = t0
    self%events(self%count)%t1 = t1
    self%events(self%count)%bare_rate = bound%bare_soil_evaporation_rate()
    self%events(self%count)%ponded_rate = bound%ponded_water_evaporation_rate()
    self%events(self%count)%route = bound%route()
  end subroutine publish_candidate_unguarded

  subroutine publish_accepted(self, publication)
    class(d6_event_sink_t), intent(inout) :: self
    type(fmr_surface_evaporation_publication_t), intent(in) :: publication
    real(real64) :: t0, t1
    logical :: available
    if (.not. publication%ready()) error stop 'D6 accepted event not ready'
    if (self%count >= size(self%events)) error stop 'D6 event sink full'
    call publication%origin_interval(t0, t1, available)
    if (.not. available) error stop 'D6 accepted interval unavailable'
    self%count = self%count + 1
    self%events(self%count)%initialized = .true.
    self%events(self%count)%accepted_source = .true.
    self%events(self%count)%lineage_id = publication%current_lineage_id()
    self%events(self%count)%origin_revision = publication%origin_revision()
    self%events(self%count)%t0 = t0
    self%events(self%count)%t1 = t1
    self%events(self%count)%bare_rate = publication%bare_soil_evaporation_rate()
    self%events(self%count)%ponded_rate = publication%ponded_water_evaporation_rate()
    self%events(self%count)%route = publication%route()
  end subroutine publish_accepted

end module pub_me_d6_support

program test_pub_me_d6_rejected_side_effect
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_surface_evaporation_runtime_materialization, only: fmr_candidate_bound_surface_evaporation_t, &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_candidate_bound_surface_evaporation, &
       FMR_SURFACE_EVAP_RUNTIME_OK, FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH
  use mod_fmr_surface_evaporation_accepted_publication, only: fmr_surface_evaporation_publication_t, &
       fmr_commit_candidate_with_surface_evaporation_publication, FMR_SURFACE_EVAP_PUBLICATION_OK, &
       FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED
  use mod_fmr_accepted_commit_receipt, only: FMR_COMMIT_RECEIPT_OK
  use pub_me_d6_support, only: d6_parameters_t, d6_forcing_t, d6_model_t, d6_capacity_provider_t, d6_event_sink_t
  implicit none

  real(real64), parameter :: t0 = 47.0_real64, t1 = 53.0_real64
  real(real64), parameter :: accepted_rate_expected = 0.12_real64
  real(real64), parameter :: rejected_rate_expected = 0.31_real64

  integer :: clean_count, mutant_count
  integer(int64) :: clean_revision, mutant_revision
  real(real64) :: clean_time, mutant_time, clean_digest, mutant_digest
  real(real64) :: clean_rate, mutant_accepted_rate, mutant_rejected_rate
  logical :: clean_time_ok, mutant_time_ok, b2_detected, b1_detected

  call run_case(.false., clean_count, clean_revision, clean_time, clean_time_ok, clean_digest, &
       clean_rate, mutant_rejected_rate, b2_detected, b1_detected)
  call require(clean_count == 1, 'clean accepted event count')
  call require(.not. b2_detected, 'clean no B2 violation')
  call require(.not. b1_detected, 'clean no B1 violation')
  call require_close(clean_rate, accepted_rate_expected, 'clean accepted event rate')
  write(*,'(A)') 'PUB_ME_D6_CLEAN_ACCEPTED_ONLY_STREAM=PASS'

  call run_case(.true., mutant_count, mutant_revision, mutant_time, mutant_time_ok, mutant_digest, &
       mutant_accepted_rate, mutant_rejected_rate, b2_detected, b1_detected)
  call require(mutant_count == 2, 'mutant event count')
  call require(b2_detected, 'B2 detects preaccept side effect')
  call require(b1_detected, 'B1 detects contaminated event stream')
  call require_close(mutant_rejected_rate, rejected_rate_expected, 'mutant rejected event rate')
  call require_close(mutant_accepted_rate, accepted_rate_expected, 'mutant accepted event rate')
  write(*,'(A)') 'PUB_ME_D6_B2_PREPUBLICATION_AUTHORITY=DETECTED'
  write(*,'(A)') 'PUB_ME_D6_B1_END_STREAM_REGRESSION=DETECTED'

  call require(clean_revision == mutant_revision .and. clean_revision == 1_int64, 'accepted revisions match')
  call require(clean_time_ok .and. mutant_time_ok, 'accepted times available')
  call require_close(clean_time, mutant_time, 'accepted times match')
  call require_close(clean_digest, mutant_digest, 'accepted physical state digest matches')
  call require_close(clean_rate, mutant_accepted_rate, 'accepted publication matches')
  write(*,'(A)') 'PUB_ME_D6_ACCEPTED_PHYSICS_UNCHANGED=PASS'

  write(*,'(A,I0)') 'PUB_ME_D6_CLEAN_EVENT_COUNT=', clean_count
  write(*,'(A,I0)') 'PUB_ME_D6_MUTANT_EVENT_COUNT=', mutant_count
  write(*,'(A,ES26.17E3)') 'PUB_ME_D6_REJECTED_EVENT_RATE=', mutant_rejected_rate
  write(*,'(A,ES26.17E3)') 'PUB_ME_D6_ACCEPTED_EVENT_RATE=', mutant_accepted_rate
  write(*,'(A)') 'PUB_ME_D6_CLASSIFICATION=EARLIER_DETECTION'
  write(*,'(A)') 'PUB_ME_D6_REJECTED_SIDE_EFFECT_EXPERIMENT=PASS'

contains

  subroutine run_case(inject_fault, event_count, revision, accepted_time, time_ok, state_digest, &
       accepted_rate, rejected_rate, b2_violation, b1_violation)
    logical, intent(in) :: inject_fault
    integer, intent(out) :: event_count
    integer(int64), intent(out) :: revision
    real(real64), intent(out) :: accepted_time, state_digest, accepted_rate, rejected_rate
    logical, intent(out) :: time_ok, b2_violation, b1_violation

    type(d6_parameters_t) :: parameters
    type(d6_forcing_t) :: forcing
    type(d6_model_t), target :: model_a, model_b, commit_model
    type(kernel_executor_t) :: kernel_a, kernel_b, commit_kernel
    type(canonical_numerical_config_t) :: config
    type(reference_et_demand_result_t) :: et
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(d6_capacity_provider_t) :: accepted_provider, rejected_provider
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diag_a, diag_b
    type(fmr_candidate_bound_surface_evaporation_t) :: bound_a
    type(fmr_surface_evaporation_publication_t) :: publication_b, rejected_publication
    type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
    type(d6_event_sink_t) :: sink
    class(transaction_state_t), allocatable :: snapshot
    integer(int64) :: rev_before_stale
    logical :: ok, did_commit
    integer :: publication_status, receipt_status, commit_status

    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
    et = reference_et_demand_result_t()
    et%potential_soil_evaporation_cm_per_day = 0.44_real64
    et%potential_pond_evaporation_cm_per_day = 0.66_real64
    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.
    accepted_provider%value = accepted_rate_expected
    rejected_provider%value = rejected_rate_expected

    call kernel_a%bind_model(model_a)
    call kernel_b%bind_model(model_b)
    call commit_kernel%bind_model(commit_model)

    call make_committed(76001_int64, committed)
    call committed%capture_checkpoint(checkpoint, ok)
    call require(ok, 'common checkpoint')

    call kernel_a%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_a, diag_a, checkpoint)
    call require(result%completed .and. candidate_a%ready(), 'candidate A ready')
    call kernel_b%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_b, diag_b, checkpoint)
    call require(result%completed .and. candidate_b%ready(), 'candidate B ready')
    call require(candidate_a%current_lineage_id() == candidate_b%current_lineage_id(), 'same lineage')
    call require(candidate_a%origin_revision() == candidate_b%origin_revision(), 'same origin revision')

    call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_a, et, et_diag, rejected_provider, &
         bound_a, surface_diag)
    call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_a%ready(), 'candidate A bound result')
    rejected_rate = bound_a%bare_soil_evaporation_rate()
    call require_close(rejected_rate, rejected_rate_expected, 'candidate A process rate')

    b2_violation = .false.
    if (inject_fault) then
      ! B2 rule: a candidate-bound result is not accepted publication authority.
      ! At this point no commit receipt exists for A or B.
      b2_violation = bound_a%ready() .and. committed%current_revision() == candidate_a%origin_revision()
      call require(b2_violation, 'prepublication authority violation recognized')
      ! Qualification-only bypass used to observe the consequence B1 would see.
      call sink%publish_candidate_unguarded(bound_a)
    end if

    call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel, checkpoint, committed, candidate_b, diag_b, &
         et, et_diag, accepted_provider, did_commit, publication_b, surface_diag, publication_status, receipt_status, commit_status)
    call require(did_commit, 'candidate B committed')
    call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_OK, 'candidate B publication status')
    call require(publication_b%ready(), 'candidate B accepted publication ready')
    call require(receipt_status == FMR_COMMIT_RECEIPT_OK .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
         'candidate B accepted receipt')
    call sink%publish_accepted(publication_b)
    accepted_rate = publication_b%bare_soil_evaporation_rate()

    rev_before_stale = committed%current_revision()
    call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel, checkpoint, committed, candidate_a, diag_a, &
         et, et_diag, rejected_provider, did_commit, rejected_publication, surface_diag, publication_status, receipt_status, commit_status)
    call require(.not. did_commit, 'candidate A stale not committed')
    call require(.not. rejected_publication%ready(), 'candidate A stale not accepted-published')
    call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED, 'candidate A stale publication status')
    call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, 'candidate A stale provenance rejection')
    call require(committed%current_revision() == rev_before_stale, 'stale candidate no committed mutation')
    call require(candidate_a%ready(), 'stale candidate remains ready')

    event_count = sink%count
    b1_violation = .false.
    if (sink%count /= 1) b1_violation = .true.
    if (sink%count >= 1) then
      if (.not. sink%events(sink%count)%accepted_source) b1_violation = .true.
      if (abs(sink%events(sink%count)%bare_rate - accepted_rate) > 1.0e-12_real64) b1_violation = .true.
    end if
    if (sink%count > 1) then
      if (.not. sink%events(1)%accepted_source) b1_violation = .true.
      if (abs(sink%events(1)%bare_rate - accepted_rate) > 1.0e-12_real64) b1_violation = .true.
    end if

    revision = committed%current_revision()
    call committed%current_time(accepted_time, time_ok)
    call committed%snapshot(snapshot, ok)
    call require(ok, 'accepted state snapshot')
    state_digest = physical_digest(snapshot)
  end subroutine run_case

  subroutine make_committed(lineage, state)
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fmr_b110_physical_state_t :: physical)
    select type (typed => physical)
    type is (fmr_b110_physical_state_t)
      typed%active_nodes = 2
      allocate(typed%pressure_head(2), typed%water_content(2))
      typed%pressure_head = [-130.0_real64, -270.0_real64]
      typed%water_content = [0.20_real64, 0.24_real64]
      typed%ponding_depth = 0.0_real64
      typed%groundwater_level = -190.0_real64
    end select
    call state%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  real(real64) function physical_digest(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = huge(0.0_real64)
    if (.not. allocated(state)) return
    select type (typed => state)
    type is (fmr_b110_physical_state_t)
      value = sum(typed%pressure_head) + sum(typed%water_content) + typed%ponding_depth + typed%groundwater_level
    end select
  end function physical_digest

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call require(abs(actual-expected) <= 1.0e-12_real64, label)
  end subroutine require_close

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D6_FAIL', trim(label)
      error stop 6
    end if
  end subroutine require
end program test_pub_me_d6_rejected_side_effect
