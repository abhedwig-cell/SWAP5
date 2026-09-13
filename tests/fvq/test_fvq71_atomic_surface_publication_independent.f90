module mod_fvq71_support
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

  type, extends(kernel_parameters_t), public :: fvq71_parameters_t
  end type fvq71_parameters_t

  type, extends(canonical_forcing_t), public :: fvq71_forcing_t
  end type fvq71_forcing_t

  type, extends(kernel_model_t), public :: fvq71_model_t
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type fvq71_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fvq71_capacity_provider_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: evaluate => capacity_evaluate
  end type fvq71_capacity_provider_t

contains

  subroutine configure_parameters(self, parameters)
    class(fvq71_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FVQ71 configure'
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fvq71_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fvq71_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FVQ71 prepare'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FVQ71 interval'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fvq71_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FVQ71 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FVQ71 state'
    class default
      error stop 'FVQ71 state type'
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
    class(fvq71_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FVQ71 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 41.0_real64 + state%ponding_depth
    class default
      error stop 'FVQ71 storage state'
    end select
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(fvq71_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FVQ71 accounting'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(fvq71_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FVQ71 temporal'
    value = 0.0_real64
  end function temporal_error

  subroutine capacity_evaluate(self, base_state, result)
    class(fvq71_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%value
    result%route = 'fvq71-independent'
  end subroutine capacity_evaluate

end module mod_fvq71_support

program test_fvq71_atomic_surface_publication_independent
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
  use mod_fvq71_support, only: fvq71_parameters_t, fvq71_forcing_t, fvq71_model_t, fvq71_capacity_provider_t
  implicit none

  real(real64), parameter :: t0 = 47.0_real64, t1 = 53.0_real64
  type(fvq71_parameters_t) :: parameters
  type(fvq71_forcing_t) :: forcing
  type(fvq71_model_t), target :: trial_model, commit_model, alternate_model, target_model, source_model
  type(kernel_executor_t) :: trial_kernel, commit_kernel, alternate_kernel, target_kernel, source_kernel
  type(canonical_numerical_config_t) :: config
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fvq71_capacity_provider_t) :: low_provider, high_provider
  type(kernel_committed_state_t) :: committed, target_committed, source_committed
  type(kernel_checkpoint_t) :: checkpoint, target_checkpoint, source_checkpoint
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, foreign_candidate
  type(kernel_result_t) :: trial_result
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_foreign
  type(fmr_surface_evaporation_publication_t) :: publication_a, rejected_publication
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  integer(int64) :: rev_before
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
  low_provider%value = 0.12_real64
  high_provider%value = 0.31_real64

  call trial_kernel%bind_model(trial_model)
  call commit_kernel%bind_model(commit_model)
  call alternate_kernel%bind_model(alternate_model)
  call target_kernel%bind_model(target_model)
  call source_kernel%bind_model(source_model)

  ! Produce two successful candidates from the same committed origin. This is
  ! the exact ambiguity class that defeated F-PM10/F-VQ69 before F-MR43.
  call make_committed(71001_int64, 0.0_real64, committed)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint common origin')
  call trial_kernel%advance_interval(parameters, committed, forcing, config, t0, t1, trial_result, candidate_a, diag_a, checkpoint)
  call require(trial_result%completed, 'candidate A completed')
  call require(candidate_a%ready(), 'candidate A ready')
  call alternate_kernel%advance_interval(parameters, committed, forcing, config, t0, t1, trial_result, candidate_b, diag_b, checkpoint)
  call require(trial_result%completed, 'candidate B completed')
  call require(candidate_b%ready(), 'candidate B ready')
  call require(candidate_a%current_lineage_id() == candidate_b%current_lineage_id(), 'same lineage')
  call require(candidate_a%origin_revision() == candidate_b%origin_revision(), 'same origin revision')
  write(*,'(A)') 'FVQ71_AMBIGUOUS_OLD_PROVENANCE_PAIR=REPRODUCED'

  ! Accept A atomically using a distinct commit executor. The publication rate
  ! must come from materialization inside this exact call.
  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel, checkpoint, committed, candidate_a, diag_a, &
       et, et_diag, low_provider, did_commit, publication_a, surface_diag, publication_status, receipt_status, commit_status)
  call require(did_commit, 'candidate A committed')
  call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_OK, 'A publication status')
  call require(publication_a%ready(), 'A publication ready')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'A receipt')
  call require_close(publication_a%bare_soil_evaporation_rate(), 0.12_real64, 'A published rate')
  call require(.not. candidate_a%ready(), 'A consumed')
  call require(committed%current_revision() == 1_int64, 'A revision committed')
  write(*,'(A)') 'FVQ71_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS'

  ! Candidate B still carries the old origin revision. It cannot be paired with
  ! A's accepted outcome because there is no public split result/receipt seam;
  ! trying the only public publication entry now must fail before commit.
  rev_before = committed%current_revision()
  call fmr_commit_candidate_with_surface_evaporation_publication(commit_kernel, checkpoint, committed, candidate_b, diag_b, &
       et, et_diag, high_provider, did_commit, rejected_publication, surface_diag, publication_status, receipt_status, commit_status)
  call require(.not. did_commit, 'stale B not committed')
  call require(.not. rejected_publication%ready(), 'stale B not published')
  call require(publication_status == FMR_SURFACE_EVAP_PUBLICATION_MATERIALIZATION_REJECTED, 'stale B publication status')
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, 'stale B provenance rejection')
  call require(committed%current_revision() == rev_before, 'stale B no committed mutation')
  call require(candidate_b%ready(), 'stale B preserved after precommit rejection')
  write(*,'(A)') 'FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED'

  ! Independent cross-lineage attack must also fail before commit.
  call make_committed(71002_int64, 0.0_real64, target_committed)
  call make_committed(71003_int64, 0.0_real64, source_committed)
  call target_committed%capture_checkpoint(target_checkpoint, ok)
  call require(ok, 'target checkpoint')
  call source_committed%capture_checkpoint(source_checkpoint, ok)
  call require(ok, 'source checkpoint')
  call source_kernel%advance_interval(parameters, source_committed, forcing, config, t0, t1, trial_result, foreign_candidate, &
       diag_foreign, source_checkpoint)
  call require(trial_result%completed, 'foreign completed')
  call require(foreign_candidate%ready(), 'foreign candidate ready')
  rev_before = target_committed%current_revision()
  call fmr_commit_candidate_with_surface_evaporation_publication(target_kernel, target_checkpoint, target_committed, &
       foreign_candidate, diag_foreign, et, et_diag, low_provider, did_commit, rejected_publication, surface_diag, &
       publication_status, receipt_status, commit_status)
  call require(.not. did_commit .and. .not. rejected_publication%ready(), 'cross-lineage rejected')
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH, 'cross-lineage provenance status')
  call require(target_committed%current_revision() == rev_before, 'cross-lineage no mutation')
  call require(foreign_candidate%ready(), 'foreign candidate preserved')
  write(*,'(A)') 'FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED'

  call require(diag_a%mass_rejections == 0 .and. diag_b%mass_rejections == 0 .and. diag_foreign%mass_rejections == 0, &
       'mass diagnostics unchanged')
  write(*,'(A)') 'FVQ71_NO_MASS_REGRESSION=PASS'
  write(*,'(A)') 'FVQ71_DECISION=QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION'
  write(*,'(A)') 'FVQ71_INDEPENDENT_ORACLE=PASS'

contains

  subroutine make_committed(lineage, ponding, state)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: ponding
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fmr_b110_physical_state_t :: physical)
    select type (p => physical)
    type is (fmr_b110_physical_state_t)
      p%active_nodes = 2
      allocate(p%pressure_head(2), p%water_content(2))
      p%pressure_head = [-130.0_real64, -270.0_real64]
      p%water_content = [0.20_real64, 0.24_real64]
      p%ponding_depth = ponding
      p%groundwater_level = -190.0_real64
    end select
    call state%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ71_REQUIRE_FAIL', trim(label)
      error stop 71
    end if
  end subroutine require

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call require(abs(actual-expected) <= 1.0e-12_real64, label)
  end subroutine require_close

end program test_fvq71_atomic_surface_publication_independent
