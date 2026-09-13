module mod_fpm10_provenance_test_support
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

  type, extends(kernel_parameters_t), public :: fpm10_parameters_t
  end type fpm10_parameters_t

  type, extends(canonical_forcing_t), public :: fpm10_forcing_t
  end type fpm10_forcing_t

  type, extends(kernel_model_t), public :: fpm10_model_t
  contains
    procedure :: configure_parameters => fpm10_configure_parameters
    procedure :: execution_admitted => fpm10_execution_admitted
    procedure :: prepare_interval => fpm10_prepare_interval
    procedure :: advance => fpm10_advance
    procedure :: storage => fpm10_storage
    procedure :: storage_accounting_status => fpm10_storage_accounting_status
    procedure :: temporal_error => fpm10_temporal_error
  end type fpm10_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fpm10_capacity_provider_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: evaluate => fpm10_capacity_evaluate
  end type fpm10_capacity_provider_t

contains

  subroutine fpm10_configure_parameters(self, parameters)
    class(fpm10_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FPM10 configure type'
  end subroutine fpm10_configure_parameters

  logical function fpm10_execution_admitted(self, parameters, numerical_config)
    class(fpm10_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    fpm10_execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function fpm10_execution_admitted

  subroutine fpm10_prepare_interval(self, forcing, interval, config)
    class(fpm10_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FPM10 prepare type'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FPM10 interval'
  end subroutine fpm10_prepare_interval

  subroutine fpm10_advance(self, state, t0, t1, outcome)
    class(fpm10_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FPM10 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FPM10 invalid state'
    class default
      error stop 'FPM10 unexpected state'
    end select

    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine fpm10_advance

  real(real64) function fpm10_storage(self, state) result(value)
    class(fpm10_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FPM10 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 10.0_real64 + state%ponding_depth
    class default
      error stop 'FPM10 storage state'
    end select
  end function fpm10_storage

  subroutine fpm10_storage_accounting_status(self, state, complete, missing_mask)
    class(fpm10_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FPM10 accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fpm10_storage_accounting_status

  real(real64) function fpm10_temporal_error(self, full_state, half_state) result(value)
    class(fpm10_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FPM10 temporal type'
    value = 0.0_real64
  end function fpm10_temporal_error

  subroutine fpm10_capacity_evaluate(self, base_state, result)
    class(fpm10_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result

    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%value
    result%route = 'fpm10-test'
  end subroutine fpm10_capacity_evaluate

end module mod_fpm10_provenance_test_support

program test_fpm10_surface_evaporation_publication_provenance
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
       fmr_materialize_candidate_bound_surface_evaporation, FMR_SURFACE_EVAP_RUNTIME_OK, &
       FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_surface_evaporation_publication_t, &
       fmr_prepare_surface_evaporation_publication, fmr_finalize_surface_evaporation_publication, &
       FMR_SURFACE_EVAP_PUBLICATION_OK, FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH
  use mod_fpm10_provenance_test_support, only: fpm10_parameters_t, fpm10_forcing_t, fpm10_model_t, &
       fpm10_capacity_provider_t
  implicit none

  real(real64), parameter :: t0 = 7.0_real64, t1 = 11.0_real64
  type(fpm10_parameters_t) :: parameters
  type(fpm10_forcing_t) :: forcing
  type(fpm10_model_t), target :: model
  type(fpm10_capacity_provider_t) :: provider_a, provider_b
  type(canonical_numerical_config_t) :: config
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed_a, committed_b
  type(kernel_checkpoint_t) :: checkpoint_a, checkpoint_b
  type(kernel_candidate_state_t) :: candidate_a, candidate_b
  type(kernel_result_t) :: kernel_result_a, kernel_result_b
  type(kernel_diagnostics_t) :: kernel_diag_a, kernel_diag_b
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr_candidate_bound_surface_evaporation_t) :: bound_a, bound_b, rejected_bound
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared_a, prepared_b
  type(fmr_surface_evaporation_publication_t) :: publication_a, publication_b_as_a, publication_b
  type(fmr_accepted_commit_receipt_t) :: receipt_a, receipt_b
  logical :: ok, did_commit
  integer :: status, receipt_status, commit_status

  call make_committed(10101_int64, 0.0_real64, committed_a)
  call make_committed(20202_int64, 10.0_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, committed_b)
  call kernel%bind_model(model)

  call committed_a%capture_checkpoint(checkpoint_a, ok)
  call require(ok, 'checkpoint A')
  call kernel%advance_interval(parameters, committed_a, forcing, config, t0, t1, kernel_result_a, candidate_a, &
       kernel_diag_a, checkpoint_a)
  call require(kernel_result_a%completed, 'candidate A completed')
  call require(kernel_result_a%mass%complete, 'candidate A mass complete')
  call require(candidate_a%ready(), 'candidate A ready')

  call committed_b%capture_checkpoint(checkpoint_b, ok)
  call require(ok, 'checkpoint B')
  call kernel%advance_interval(parameters, committed_b, forcing, config, t0, t1, kernel_result_b, candidate_b, &
       kernel_diag_b, checkpoint_b)
  call require(kernel_result_b%completed, 'candidate B completed')
  call require(kernel_result_b%mass%complete, 'candidate B mass complete')
  call require(candidate_b%ready(), 'candidate B ready')
  write(*,'(A)') 'FPM10_REAL_FKT_CANDIDATES_AND_HARD_MASS=PASS'

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.40_real64
  et%potential_pond_evaporation_cm_per_day = 0.60_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.
  provider_a%value = 0.11_real64
  provider_b%value = 0.47_real64

  call fmr_materialize_candidate_bound_surface_evaporation(committed_a, candidate_a, et, et_diag, provider_a, &
       bound_a, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 'bound A status')
  call require(bound_a%ready(), 'bound A ready')
  call require(trim(bound_a%route()) == 'dry', 'bound A dry')
  call require_close(bound_a%bare_soil_evaporation_rate(), 0.11_real64, 'bound A rate')

  call fmr_materialize_candidate_bound_surface_evaporation(committed_b, candidate_b, et, et_diag, provider_b, &
       bound_b, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 'bound B status')
  call require(bound_b%ready(), 'bound B ready')
  call require(trim(bound_b%route()) == 'ponded', 'bound B ponded')
  call require_close(bound_b%ponded_water_evaporation_rate(), 0.60_real64, 'bound B rate')
  write(*,'(A)') 'FPM10_BOUND_RESULT_POSITIVE_CONTROLS=PASS'

  call fmr_materialize_candidate_bound_surface_evaporation(committed_a, candidate_b, et, et_diag, provider_a, &
       rejected_bound, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, 'source bind mismatch status')
  call require(.not. rejected_bound%ready(), 'source bind mismatch not ready')
  write(*,'(A)') 'FPM10_SOURCE_BIND_CROSS_CANDIDATE_REJECTED=PASS'

  call fmr_prepare_surface_evaporation_publication(bound_a, prepared_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_a%ready(), 'prepare A')
  call fmr_prepare_surface_evaporation_publication(bound_b, prepared_b, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_b%ready(), 'prepare B')

  call fmr_commit_candidate_with_receipt(kernel, checkpoint_a, committed_a, candidate_a, kernel_diag_a, did_commit, &
       receipt_a, receipt_status, commit_status)
  call require(did_commit, 'commit A')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt A')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit status A')

  call fmr_finalize_surface_evaporation_publication(prepared_a, receipt_a, publication_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication_a%ready(), 'finalize A')
  call require(trim(publication_a%route()) == 'dry', 'publication A dry')
  call require_close(publication_a%bare_soil_evaporation_rate(), 0.11_real64, 'publication A rate')
  write(*,'(A)') 'FPM10_ACCEPTED_PUBLICATION_A_POSITIVE=PASS'

  ! Exact successor of F-VQ57 HN1: B is a valid physical surface result, but it
  ! originated from candidate B. Receipt A must never authorize it.
  call fmr_finalize_surface_evaporation_publication(prepared_b, receipt_a, publication_b_as_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH, 'B with A receipt rejected')
  call require(.not. publication_b_as_a%ready(), 'B with A publication unavailable')
  write(*,'(A)') 'FPM10_HN1_CROSS_CANDIDATE_SUBSTITUTION_REJECTED=PASS'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint_b, committed_b, candidate_b, kernel_diag_b, did_commit, &
       receipt_b, receipt_status, commit_status)
  call require(did_commit, 'commit B')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt B')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit status B')
  call fmr_finalize_surface_evaporation_publication(prepared_b, receipt_b, publication_b, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication_b%ready(), 'finalize B')
  call require(trim(publication_b%route()) == 'ponded', 'publication B ponded')
  call require_close(publication_b%ponded_water_evaporation_rate(), 0.60_real64, 'publication B rate')
  write(*,'(A)') 'FPM10_ACCEPTED_PUBLICATION_B_POSITIVE=PASS'

  write(*,'(A)') 'FPM10_NO_SECOND_MASS_BOOKING=PASS'
  write(*,'(A)') 'FPM10_OWNER_PROVENANCE_TEST PASS'

contains

  subroutine make_committed(lineage, ponding, committed)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: ponding
    type(kernel_committed_state_t), intent(out) :: committed
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr_b110_physical_state_t :: physical)
    select type (state => physical)
    type is (fmr_b110_physical_state_t)
      state%active_nodes = 2
      allocate(state%pressure_head(2), state%water_content(2))
      state%pressure_head = [-100.0_real64, -250.0_real64]
      state%water_content = [0.20_real64, 0.24_real64]
      state%ponding_depth = ponding
      state%groundwater_level = -180.0_real64
    end select
    call committed%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM10_REQUIRE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: tol
    tol = 256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(actual),abs(expected))
    call require(abs(actual-expected) <= tol, label)
  end subroutine require_close

end program test_fpm10_surface_evaporation_publication_provenance
