module mod_fmr43_test_support
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

  type, extends(kernel_parameters_t), public :: fmr43_parameters_t
  end type fmr43_parameters_t

  type, extends(canonical_forcing_t), public :: fmr43_forcing_t
  end type fmr43_forcing_t

  type, extends(kernel_model_t), public :: fmr43_model_t
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type fmr43_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fmr43_capacity_provider_t
    real(real64) :: capacity = 0.0_real64
    logical :: make_invalid = .false.
  contains
    procedure :: evaluate => capacity_evaluate
  end type fmr43_capacity_provider_t

contains

  subroutine configure_parameters(self, parameters)
    class(fmr43_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FMR43 configure'
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fmr43_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fmr43_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FMR43 prepare'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FMR43 interval'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fmr43_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FMR43 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FMR43 state'
    class default
      error stop 'FMR43 state type'
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
    class(fmr43_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FMR43 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 25.0_real64 + state%ponding_depth
    class default
      error stop 'FMR43 storage state'
    end select
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(fmr43_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FMR43 accounting'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(fmr43_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FMR43 temporal'
    value = 0.0_real64
  end function temporal_error

  subroutine capacity_evaluate(self, base_state, result)
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    class(fmr43_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    if (self%make_invalid) then
      result%evaporation_capacity = ieee_value(0.0_real64, ieee_quiet_nan)
    else
      result%evaporation_capacity = self%capacity
    end if
    result%route = 'fmr43-owner'
  end subroutine capacity_evaluate

end module mod_fmr43_test_support

program test_fmr43_atomic_surface_publication
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

  real(real64), parameter :: t0 = 31.0_real64, t1 = 35.0_real64
  type(fmr43_parameters_t) :: parameters
  type(fmr43_forcing_t) :: forcing
  type(fmr43_model_t), target :: trial_model_a, commit_model_a, trial_model_b, commit_model_b, trial_model_bad
  type(kernel_executor_t) :: trial_kernel_a, commit_kernel_a, trial_kernel_b, commit_kernel_b, trial_kernel_bad
  type(canonical_numerical_config_t) :: config
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr43_capacity_provider_t) :: dry_provider, ponded_provider, invalid_provider
  type(kernel_committed_state_t) :: committed_a, committed_b, committed_target, committed_source, committed_invalid
  type(kernel_checkpoint_t) :: checkpoint_a, checkpoint_b, checkpoint_target, checkpoint_source, checkpoint_invalid
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_source, candidate_invalid
  type(kernel_result_t) :: trial_result
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_source, diag_invalid
  type(fmr_surface_evaporation_publication_t) :: publication_a, publication_b, rejected_publication
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  logical :: ok, did_commit
  integer :: publication_status, receipt_status, commit_status
  integer(int64) :: before_revision

  config%max_committed_substeps = 8
  config%progress_tolerance = 0.0_real64
  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.40_real64
  et%potential_pond_evaporation_cm_per_day = 0.60_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.
  dry_provider%capacity = 0.11_real64
  ponded_provider%capacity = 0.47_real64
  invalid_provider%capacity = 0.25_real64
  invalid_provider%make_invalid = .true.

  ! Deliberately use separate trial and commit executor objects. This mirrors
  ! the existing serialized MultiSWAP composition where the backend owns the
  ! trial executor and the dispatcher owns transaction_control for commit.
  call trial_kernel_a%bind_model(trial_model_a)
  call commit_kernel_a%bind_model(commit_model_a)
  call make_committed(43001_int64, 0.0_real64, committed_a)
  call committed_a%capture_checkpoint(checkpoint_a, ok)
  call require(ok, 'checkpoint A')
  call trial_kernel_a%advance_interval(parameters, committed_a, forcing, config, t0, t1, trial_result, candidate_a, diag_a, checkpoint_a)
  call require(trial_result%completed .and. trial_result%mass%complete .and. candidate_a%ready(), 'candidate A ready')

  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel_a, checkpoint_a, committed_a, candidate_a, &
       diag_a, et, et_diag, dry_provider, did_commit, publication_a, surface_diag, publication_status, receipt_status, commit_status)
  call require(did_commit, 'atomic A committed')
  call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication_a%ready(), 'atomic A publication')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'atomic A receipt')
  call require(committed_a%current_revision() == 1_int64 .and. .not. candidate_a%ready(), 'atomic A candidate consumed')
  call require(trim(publication_a%route()) == 'dry', 'atomic A route')
  call require_close(publication_a%bare_soil_evaporation_rate(), 0.11_real64, 'atomic A rate')
  write(*,'(A)') 'FMR43_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS'

  call trial_kernel_b%bind_model(trial_model_b)
  call commit_kernel_b%bind_model(commit_model_b)
  call make_committed(43002_int64, 1.0e-6_real64, committed_b)
  call committed_b%capture_checkpoint(checkpoint_b, ok)
  call require(ok, 'checkpoint B')
  call trial_kernel_b%advance_interval(parameters, committed_b, forcing, config, t0, t1, trial_result, candidate_b, diag_b, checkpoint_b)
  call require(trial_result%completed .and. candidate_b%ready(), 'candidate B ready')
  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel_b, checkpoint_b, committed_b, candidate_b, &
       diag_b, et, et_diag, ponded_provider, did_commit, publication_b, surface_diag, publication_status, receipt_status, commit_status)
  call require(did_commit .and. publication_status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication_b%ready(), 'atomic B publication')
  call require(trim(publication_b%route()) == 'ponded', 'atomic B route')
  call require_close(publication_b%ponded_water_evaporation_rate(), 0.60_real64, 'atomic B rate')
  write(*,'(A)') 'FMR43_ATOMIC_SECOND_COLUMN_POSITIVE=PASS'

  ! A candidate from another lineage must be rejected before commit. This proves
  ! that the atomic wrapper does not weaken the existing candidate-origin guard.
  call make_committed(43003_int64, 0.0_real64, committed_target)
  call make_committed(43004_int64, 0.0_real64, committed_source)
  call committed_target%capture_checkpoint(checkpoint_target, ok)
  call require(ok, 'checkpoint target')
  call committed_source%capture_checkpoint(checkpoint_source, ok)
  call require(ok, 'checkpoint source')
  call trial_kernel_bad%bind_model(trial_model_bad)
  call trial_kernel_bad%advance_interval(parameters, committed_source, forcing, config, t0, t1, trial_result, candidate_source, &
       diag_source, checkpoint_source)
  call require(trial_result%completed .and. candidate_source%ready(), 'source candidate ready')
  before_revision = committed_target%current_revision()
  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel_a, checkpoint_target, committed_target, &
       candidate_source, diag_source, et, et_diag, dry_provider, did_commit, rejected_publication, surface_diag, &
       publication_status, receipt_status, commit_status)
  call require(.not. did_commit .and. .not. rejected_publication%ready(), 'cross-lineage rejected')
  call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED, 'cross-lineage publication status')
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, 'cross-lineage materializer status')
  call require(committed_target%current_revision() == before_revision .and. candidate_source%ready(), 'cross-lineage precommit immutability')
  write(*,'(A)') 'FMR43_CROSS_CANDIDATE_PRECOMMIT_FAIL_CLOSED=PASS'

  ! A failed process materialization must likewise leave committed state and
  ! candidate untouched. No accepted publication can exist without a commit.
  call make_committed(43005_int64, 0.0_real64, committed_invalid)
  call committed_invalid%capture_checkpoint(checkpoint_invalid, ok)
  call require(ok, 'checkpoint invalid')
  call trial_kernel_bad%advance_interval(parameters, committed_invalid, forcing, config, t0, t1, trial_result, candidate_invalid, &
       diag_invalid, checkpoint_invalid)
  call require(trial_result%completed .and. candidate_invalid%ready(), 'invalid candidate ready')
  before_revision = committed_invalid%current_revision()
  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel_a, checkpoint_invalid, committed_invalid, &
       candidate_invalid, diag_invalid, et, et_diag, invalid_provider, did_commit, rejected_publication, surface_diag, &
       publication_status, receipt_status, commit_status)
  call require(.not. did_commit .and. .not. rejected_publication%ready(), 'invalid materialization rejected')
  call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED, 'invalid publication status')
  call require(committed_invalid%current_revision() == before_revision .and. candidate_invalid%ready(), 'invalid precommit immutability')
  write(*,'(A)') 'FMR43_MATERIALIZATION_FAILURE_PRECOMMIT_FAIL_CLOSED=PASS'

  call require(diag_a%mass_rejections == 0 .and. diag_b%mass_rejections == 0 .and. &
       diag_source%mass_rejections == 0 .and. diag_invalid%mass_rejections == 0, 'mass diagnostics unchanged')
  write(*,'(A)') 'FMR43_NO_SECOND_MASS_BOOKING=PASS'
  write(*,'(A)') 'FMR43_OWNER_TEST PASS'

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
      state%water_content = [0.22_real64, 0.25_real64]
      state%ponding_depth = ponding
      state%groundwater_level = -175.0_real64
    end select
    call committed%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR43_REQUIRE_FAIL', trim(label)
      error stop 43
    end if
  end subroutine require

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call require(abs(actual-expected) <= 1.0e-12_real64, label)
  end subroutine require_close

end program test_fmr43_atomic_surface_publication
