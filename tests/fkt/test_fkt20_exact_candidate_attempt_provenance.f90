module mod_fkt20_test_support
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE
  implicit none
  private

  type, extends(kernel_parameters_t), public :: fkt20_parameters_t
  end type fkt20_parameters_t

  type, extends(canonical_forcing_t), public :: fkt20_forcing_t
  end type fkt20_forcing_t

  type, extends(kernel_model_t), public :: fkt20_model_t
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type fkt20_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fkt20_capacity_provider_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: evaluate => capacity_evaluate
  end type fkt20_capacity_provider_t

contains

  subroutine configure_parameters(self, parameters)
    class(fkt20_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FKT20 configure'
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fkt20_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fkt20_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FKT20 prepare'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FKT20 interval'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fkt20_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FKT20 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FKT20 state'
    class default
      error stop 'FKT20 type'
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
    class(fkt20_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FKT20 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 10.0_real64 + state%ponding_depth
    class default
      error stop 'FKT20 storage state'
    end select
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(fkt20_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FKT20 accounting'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(fkt20_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FKT20 temporal'
    value = 0.0_real64
  end function temporal_error

  subroutine capacity_evaluate(self, base_state, result)
    class(fkt20_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%value
    result%route = 'fkt20-test'
  end subroutine capacity_evaluate

end module mod_fkt20_test_support

program test_fkt20_exact_candidate_attempt_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED, &
       KERNEL_COMMIT_STATUS_EXECUTION_PROVENANCE_MISMATCH
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_candidate_bound_surface_evaporation_t, fmr_surface_evaporation_runtime_diagnostics_t, &
       fmr_materialize_candidate_bound_surface_evaporation, FMR_SURFACE_EVAP_RUNTIME_OK, &
       FMR_SURFACE_EVAP_RUNTIME_EXACT_PROVENANCE_UNAVAILABLE
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_surface_evaporation_publication_t, &
       fmr_prepare_surface_evaporation_publication, fmr_finalize_surface_evaporation_publication, &
       FMR_SURFACE_EVAP_PUBLICATION_OK, FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH
  use mod_fkt20_test_support, only: fkt20_parameters_t, fkt20_forcing_t, fkt20_model_t, fkt20_capacity_provider_t
  implicit none

  real(real64), parameter :: t0 = 4.0_real64, t1 = 9.0_real64
  integer(int64), parameter :: exec_a = 20001_int64, exec_b = 20002_int64
  type(fkt20_parameters_t) :: parameters
  type(fkt20_forcing_t) :: forcing
  type(fkt20_model_t), target :: model_a, model_b, model_plain
  type(fkt20_capacity_provider_t) :: provider_a, provider_b
  type(canonical_numerical_config_t) :: config
  type(kernel_executor_t) :: kernel_a, kernel_b, kernel_plain
  type(kernel_committed_state_t) :: committed, committed_cross, committed_plain
  type(kernel_checkpoint_t) :: checkpoint, checkpoint_cross, checkpoint_plain
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_cross, candidate_plain
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_cross, diag_plain
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr_candidate_bound_surface_evaporation_t) :: bound_a, bound_b, bound_plain
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared_a, prepared_b
  type(fmr_surface_evaporation_publication_t) :: pub_a, pub_b_as_a
  type(fmr_accepted_commit_receipt_t) :: receipt_a
  integer(int64) :: id_a1, seq_a1, id_a2, seq_a2, receipt_id, receipt_seq
  logical :: ok, available, did_bind, did_commit
  integer :: status, receipt_status, commit_status

  config%max_committed_substeps = 8
  config%progress_tolerance = 0.0_real64
  call kernel_a%bind_model(model_a)
  call kernel_b%bind_model(model_b)
  call kernel_plain%bind_model(model_plain)

  call kernel_a%bind_execution_provenance(exec_a, did_bind)
  call require(did_bind, 'bind exec A')
  call kernel_a%bind_execution_provenance(exec_a, did_bind)
  call require(did_bind, 'idempotent same exec A')
  call kernel_a%bind_execution_provenance(exec_b, did_bind)
  call require(.not. did_bind, 'reject rebind exec A')
  call kernel_b%bind_execution_provenance(exec_b, did_bind)
  call require(did_bind, 'bind exec B')
  write(*,'(A)') 'FKT20_EXECUTION_DOMAIN_BINDING=PASS'

  call make_committed(70001_int64, committed)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint')
  call kernel_a%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_a, diag_a, checkpoint)
  call require(result%completed .and. candidate_a%ready(), 'candidate A')
  call kernel_a%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_b, diag_b, checkpoint)
  call require(result%completed .and. candidate_b%ready(), 'candidate B')
  call candidate_a%exact_attempt_provenance(id_a1, seq_a1, available)
  call require(available, 'candidate A exact')
  call candidate_b%exact_attempt_provenance(id_a2, seq_a2, available)
  call require(available, 'candidate B exact')
  call require(id_a1 == exec_a .and. id_a2 == exec_a, 'execution id A')
  call require(seq_a1 == 1_int64 .and. seq_a2 == 2_int64, 'monotonic sequence')
  call require(candidate_a%current_lineage_id() == candidate_b%current_lineage_id(), 'same lineage tuple')
  call require(candidate_a%origin_revision() == candidate_b%origin_revision(), 'same revision tuple')
  write(*,'(A)') 'FKT20_SAME_TUPLE_DISTINCT_EXACT_CANDIDATES=PASS'

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.50_real64
  et%potential_pond_evaporation_cm_per_day = 0.70_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.
  provider_a%value = 0.12_real64
  provider_b%value = 0.31_real64

  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_a, et, et_diag, provider_a, bound_a, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_a%ready(), 'bound A')
  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_b, et, et_diag, provider_b, bound_b, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_b%ready(), 'bound B')
  call fmr_prepare_surface_evaporation_publication(bound_a, prepared_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_a%ready(), 'prepare A')
  call fmr_prepare_surface_evaporation_publication(bound_b, prepared_b, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_b%ready(), 'prepare B')

  call fmr_commit_candidate_with_receipt(kernel_a, checkpoint, committed, candidate_a, diag_a, did_commit, &
       receipt_a, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'commit A receipt')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit A status')
  call receipt_a%exact_attempt_provenance(receipt_id, receipt_seq, available)
  call require(available .and. receipt_id == exec_a .and. receipt_seq == seq_a1, 'receipt exact A')

  call fmr_finalize_surface_evaporation_publication(prepared_a, receipt_a, pub_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. pub_a%ready(), 'publish A')
  call fmr_finalize_surface_evaporation_publication(prepared_b, receipt_a, pub_b_as_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH, 'B with receipt A rejected')
  call require(.not. pub_b_as_a%ready(), 'B with receipt A unavailable')
  write(*,'(A)') 'FKT20_FVQ69_HN5_CLOSED=PASS'

  ! A generic unbound executor still supports generic F-KT candidate/commit, but
  ! accepted surface publication fails closed before a candidate-bound result is produced.
  call make_committed(70002_int64, committed_plain)
  call committed_plain%capture_checkpoint(checkpoint_plain, ok)
  call require(ok, 'checkpoint plain')
  call kernel_plain%advance_interval(parameters, committed_plain, forcing, config, t0, t1, result, candidate_plain, diag_plain, checkpoint_plain)
  call require(result%completed .and. candidate_plain%ready(), 'plain candidate')
  call candidate_plain%exact_attempt_provenance(id_a1, seq_a1, available)
  call require(.not. available, 'plain has no exact provenance')
  call fmr_materialize_candidate_bound_surface_evaporation(committed_plain, candidate_plain, et, et_diag, provider_a, bound_plain, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_EXACT_PROVENANCE_UNAVAILABLE, 'surface fail closed without exact provenance')
  call require(.not. bound_plain%ready(), 'plain bound unavailable')
  call kernel_plain%commit_candidate(committed_plain, candidate_plain, diag_plain, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'generic FKT commit preserved')
  write(*,'(A)') 'FKT20_GENERIC_FKT_PRESERVED_SURFACE_FAILS_CLOSED=PASS'

  ! An exact candidate is owned by its execution provenance domain. A different
  ! executor domain cannot commit it even though physical lineage/revision/time match.
  call make_committed(70003_int64, committed_cross)
  call committed_cross%capture_checkpoint(checkpoint_cross, ok)
  call require(ok, 'checkpoint cross')
  call kernel_a%advance_interval(parameters, committed_cross, forcing, config, t0, t1, result, candidate_cross, diag_cross, checkpoint_cross)
  call require(result%completed .and. candidate_cross%ready(), 'cross candidate')
  call kernel_b%commit_candidate(committed_cross, candidate_cross, diag_cross, did_commit, commit_status)
  call require(.not. did_commit, 'cross executor reject')
  call require(commit_status == KERNEL_COMMIT_STATUS_EXECUTION_PROVENANCE_MISMATCH, 'cross executor status')
  call require(candidate_cross%ready(), 'candidate survives rejected commit')
  call kernel_a%commit_candidate(committed_cross, candidate_cross, diag_cross, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'origin executor commits')
  write(*,'(A)') 'FKT20_CROSS_EXECUTOR_COMMIT_REJECTED=PASS'

  call require(diag_a%mass_rejections == 0 .and. diag_b%mass_rejections == 0 .and. diag_plain%mass_rejections == 0, &
       'no mass regression diagnostics')
  write(*,'(A)') 'FKT20_NO_MASS_BOOKING_CHANGE=PASS'
  write(*,'(A)') 'FKT20_OWNER_TEST PASS'

contains

  subroutine make_committed(lineage, state)
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fmr_b110_physical_state_t :: physical)
    select type (p => physical)
    type is (fmr_b110_physical_state_t)
      p%active_nodes = 2
      allocate(p%pressure_head(2), p%water_content(2))
      p%pressure_head = [-120.0_real64, -260.0_real64]
      p%water_content = [0.20_real64, 0.24_real64]
      p%ponding_depth = 0.0_real64
      p%groundwater_level = -190.0_real64
    end select
    call state%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FKT20_REQUIRE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt20_exact_candidate_attempt_provenance
