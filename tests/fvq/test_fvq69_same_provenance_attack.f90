module mod_fvq69_independent_support
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

  type, extends(kernel_parameters_t), public :: fvq69_parameters_t
  end type fvq69_parameters_t

  type, extends(canonical_forcing_t), public :: fvq69_forcing_t
  end type fvq69_forcing_t

  type, extends(kernel_model_t), public :: fvq69_model_t
  contains
    procedure :: configure_parameters => fvq69_configure_parameters
    procedure :: execution_admitted => fvq69_execution_admitted
    procedure :: prepare_interval => fvq69_prepare_interval
    procedure :: advance => fvq69_advance
    procedure :: storage => fvq69_storage
    procedure :: storage_accounting_status => fvq69_storage_accounting_status
    procedure :: temporal_error => fvq69_temporal_error
  end type fvq69_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fvq69_capacity_provider_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: evaluate => fvq69_capacity_evaluate
  end type fvq69_capacity_provider_t

contains

  subroutine fvq69_configure_parameters(self, parameters)
    class(fvq69_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FVQ69 configure type'
  end subroutine fvq69_configure_parameters

  logical function fvq69_execution_admitted(self, parameters, numerical_config)
    class(fvq69_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    fvq69_execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function fvq69_execution_admitted

  subroutine fvq69_prepare_interval(self, forcing, interval, config)
    class(fvq69_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FVQ69 prepare type'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FVQ69 interval'
  end subroutine fvq69_prepare_interval

  subroutine fvq69_advance(self, state, t0, t1, outcome)
    class(fvq69_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FVQ69 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FVQ69 invalid state'
    class default
      error stop 'FVQ69 unexpected state'
    end select
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine fvq69_advance

  real(real64) function fvq69_storage(self, state) result(value)
    class(fvq69_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FVQ69 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 20.0_real64 + state%ponding_depth
    class default
      error stop 'FVQ69 storage state'
    end select
  end function fvq69_storage

  subroutine fvq69_storage_accounting_status(self, state, complete, missing_mask)
    class(fvq69_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FVQ69 accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fvq69_storage_accounting_status

  real(real64) function fvq69_temporal_error(self, full_state, half_state) result(value)
    class(fvq69_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FVQ69 temporal type'
    value = 0.0_real64
  end function fvq69_temporal_error

  subroutine fvq69_capacity_evaluate(self, base_state, result)
    class(fvq69_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%value
    result%route = 'fvq69-independent'
  end subroutine fvq69_capacity_evaluate

end module mod_fvq69_independent_support

program test_fvq69_same_provenance_attack
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_candidate_bound_surface_evaporation_t, fmr_surface_evaporation_runtime_diagnostics_t, &
       fmr_materialize_candidate_bound_surface_evaporation, FMR_SURFACE_EVAP_RUNTIME_OK
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_surface_evaporation_publication_t, &
       fmr_prepare_surface_evaporation_publication, fmr_finalize_surface_evaporation_publication, &
       FMR_SURFACE_EVAP_PUBLICATION_OK
  use mod_fvq69_independent_support, only: fvq69_parameters_t, fvq69_forcing_t, fvq69_model_t, &
       fvq69_capacity_provider_t
  implicit none

  real(real64), parameter :: t0 = 3.0_real64, t1 = 8.0_real64
  type(fvq69_parameters_t) :: parameters
  type(fvq69_forcing_t) :: forcing
  type(fvq69_model_t), target :: model
  type(fvq69_capacity_provider_t) :: provider_a, provider_b
  type(canonical_numerical_config_t) :: config
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate_a, candidate_b
  type(kernel_result_t) :: result_a, result_b
  type(kernel_diagnostics_t) :: diag_a, diag_b
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr_candidate_bound_surface_evaporation_t) :: bound_a, bound_b
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared_a, prepared_b
  type(fmr_surface_evaporation_publication_t) :: published_a, published_b_with_receipt_a
  type(fmr_accepted_commit_receipt_t) :: receipt_a
  integer :: status, receipt_status, commit_status
  logical :: ok, did_commit

  call make_committed(committed)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint')

  ! Two distinct trial candidate objects are generated from exactly the same
  ! committed origin and interval. Current F-KT public provenance therefore
  ! gives them the same lineage, origin revision and interval.
  call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result_a, candidate_a, diag_a, checkpoint)
  call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result_b, candidate_b, diag_b, checkpoint)
  call require(result_a%completed .and. candidate_a%ready(), 'candidate A ready')
  call require(result_b%completed .and. candidate_b%ready(), 'candidate B ready')
  call require(candidate_a%current_lineage_id() == candidate_b%current_lineage_id(), 'same lineage')
  call require(candidate_a%origin_revision() == candidate_b%origin_revision(), 'same origin revision')
  write(*,'(A)') 'FVQ69_SAME_PUBLIC_PROVENANCE_TWO_CANDIDATES=PASS'

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.50_real64
  et%potential_pond_evaporation_cm_per_day = 0.70_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.

  ! The publication-relevant physical result is deliberately different while
  ! candidate provenance remains the same. This is legal through the current
  ! public materialization API because the capacity provider is an independent
  ! call argument and no unique candidate/attempt token is carried.
  provider_a%value = 0.12_real64
  provider_b%value = 0.31_real64
  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_a, et, et_diag, provider_a, bound_a, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_a%ready(), 'bound A')
  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_b, et, et_diag, provider_b, bound_b, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_b%ready(), 'bound B')
  call require(abs(bound_a%bare_soil_evaporation_rate()-bound_b%bare_soil_evaporation_rate()) > 1.0e-6_real64, &
       'results physically distinct')
  write(*,'(A)') 'FVQ69_DISTINCT_RESULTS_WITH_SAME_PUBLIC_PROVENANCE=PASS'

  call fmr_prepare_surface_evaporation_publication(bound_a, prepared_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_a%ready(), 'prepare A')
  call fmr_prepare_surface_evaporation_publication(bound_b, prepared_b, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_b%ready(), 'prepare B')

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate_a, diag_a, did_commit, &
       receipt_a, receipt_status, commit_status)
  call require(did_commit, 'commit A')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt A')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit A status')

  call fmr_finalize_surface_evaporation_publication(prepared_a, receipt_a, published_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. published_a%ready(), 'positive A/A')
  write(*,'(A)') 'FVQ69_POSITIVE_A_WITH_RECEIPT_A=PASS'

  ! Hard negative: B was not the committed candidate object. If publication is
  ! truly bound to exact accepted candidate identity this must fail closed.
  call fmr_finalize_surface_evaporation_publication(prepared_b, receipt_a, published_b_with_receipt_a, status)
  if (status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. published_b_with_receipt_a%ready()) then
    write(*,'(A)') 'FVQ69_HN5_SAME_PROVENANCE_DISTINCT_CANDIDATE_SUBSTITUTION=FAIL_OPEN'
    write(*,'(A)') 'FVQ69_DECISION=NOT_QUALIFIED_EXACT_CANDIDATE_PROVENANCE_NOT_PROVEN'
    error stop 69
  end if

  write(*,'(A)') 'FVQ69_HN5_SAME_PROVENANCE_DISTINCT_CANDIDATE_SUBSTITUTION=PASS'
  write(*,'(A)') 'FVQ69_DECISION=CONTINUE_FULL_INDEPENDENT_MATRIX'

contains

  subroutine make_committed(state)
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr_b110_physical_state_t :: physical)
    select type (p => physical)
    type is (fmr_b110_physical_state_t)
      p%active_nodes = 2
      allocate(p%pressure_head(2), p%water_content(2))
      p%pressure_head = [-140.0_real64, -280.0_real64]
      p%water_content = [0.21_real64, 0.25_real64]
      p%ponding_depth = 0.0_real64
      p%groundwater_level = -210.0_real64
    end select
    call state%initialize(69001_int64, physical, initialized, t0)
    call require(initialized, 'committed initialize')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ69_REQUIRE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq69_same_provenance_attack
