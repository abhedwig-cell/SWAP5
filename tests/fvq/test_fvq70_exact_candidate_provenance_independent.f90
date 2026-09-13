module mod_fvq70_support
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

  type, extends(kernel_parameters_t), public :: fvq70_parameters_t
  end type fvq70_parameters_t

  type, extends(canonical_forcing_t), public :: fvq70_forcing_t
  end type fvq70_forcing_t

  type, extends(kernel_model_t), public :: fvq70_model_t
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type fvq70_model_t

  type, extends(surface_evaporation_capacity_provider_t), public :: fvq70_capacity_provider_t
    real(real64) :: capacity = 0.0_real64
  contains
    procedure :: evaluate => capacity_evaluate
  end type fvq70_capacity_provider_t

contains

  subroutine configure_parameters(self, parameters)
    class(fvq70_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FVQ70 configure'
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fvq70_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fvq70_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FVQ70 prepare'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FVQ70 interval'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fvq70_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FVQ70 advance'
    select type (state)
    type is (fmr_b110_physical_state_t)
      if (state%active_nodes <= 0) error stop 'FVQ70 state'
    class default
      error stop 'FVQ70 state type'
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
    class(fvq70_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FVQ70 storage model'
    select type (state)
    type is (fmr_b110_physical_state_t)
      value = 20.0_real64 + state%ponding_depth
    class default
      error stop 'FVQ70 storage state'
    end select
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(fvq70_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FVQ70 accounting'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(fvq70_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FVQ70 temporal'
    value = 0.0_real64
  end function temporal_error

  subroutine capacity_evaluate(self, base_state, result)
    class(fvq70_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes <= 0) return
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%capacity
    result%route = 'fvq70-independent'
  end subroutine capacity_evaluate

end module mod_fvq70_support

program test_fvq70_exact_candidate_provenance_independent
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
  use mod_fvq70_support, only: fvq70_parameters_t, fvq70_forcing_t, fvq70_model_t, fvq70_capacity_provider_t
  implicit none

  real(real64), parameter :: t0 = 13.0_real64, t1 = 17.0_real64
  integer(int64), parameter :: domain_a = 31001_int64, domain_b = 31002_int64, collision_domain = 31999_int64
  type(fvq70_parameters_t) :: parameters
  type(fvq70_forcing_t) :: forcing
  type(fvq70_model_t), target :: model_a, model_b, model_plain, model_c, model_d
  type(fvq70_capacity_provider_t) :: provider_low, provider_high
  type(canonical_numerical_config_t) :: config
  type(kernel_executor_t) :: kernel_a, kernel_b, kernel_plain, kernel_c, kernel_d
  type(kernel_committed_state_t) :: committed, committed_cross, committed_plain, committed_collision
  type(kernel_checkpoint_t) :: checkpoint, checkpoint_cross, checkpoint_plain, checkpoint_collision
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_cross, candidate_plain, candidate_c, candidate_d
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_cross, diag_plain, diag_c, diag_d
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fmr_candidate_bound_surface_evaporation_t) :: bound_a, bound_b, bound_plain, bound_c, bound_d
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: surface_diag
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared_a, prepared_b, prepared_c, prepared_d
  type(fmr_surface_evaporation_publication_t) :: publication, attack_publication
  type(fmr_accepted_commit_receipt_t) :: receipt_a, receipt_c
  integer(int64) :: id_a, seq_a, id_b, seq_b, id_c, seq_c, id_d, seq_d
  logical :: ok, available, did_bind, did_commit
  integer :: status, receipt_status, commit_status

  config%max_committed_substeps = 8
  config%progress_tolerance = 0.0_real64

  call kernel_a%bind_model(model_a)
  call kernel_b%bind_model(model_b)
  call kernel_plain%bind_model(model_plain)
  call kernel_c%bind_model(model_c)
  call kernel_d%bind_model(model_d)
  call kernel_a%bind_execution_provenance(domain_a, did_bind)
  call require(did_bind, 'bind domain A')
  call kernel_b%bind_execution_provenance(domain_b, did_bind)
  call require(did_bind, 'bind domain B')

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.50_real64
  et%potential_pond_evaporation_cm_per_day = 0.70_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.
  provider_low%capacity = 0.11_real64
  provider_high%capacity = 0.29_real64

  ! Independent replay of the F-VQ69 class: same old public provenance tuple,
  ! two successful candidates from one executor, but exact sequence must differ.
  call make_committed(81001_int64, committed)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint A/B')
  call kernel_a%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_a, diag_a, checkpoint)
  call require(result%completed .and. candidate_a%ready(), 'candidate A')
  call kernel_a%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate_b, diag_b, checkpoint)
  call require(result%completed .and. candidate_b%ready(), 'candidate B')
  call candidate_a%exact_attempt_provenance(id_a, seq_a, available)
  call require(available, 'candidate A exact')
  call candidate_b%exact_attempt_provenance(id_b, seq_b, available)
  call require(available, 'candidate B exact')
  call require(id_a == domain_a .and. id_b == domain_a .and. seq_a /= seq_b, 'distinct exact sequence')
  call require(candidate_a%current_lineage_id() == candidate_b%current_lineage_id(), 'same old lineage')
  call require(candidate_a%origin_revision() == candidate_b%origin_revision(), 'same old revision')
  write(*,'(A)') 'FVQ70_SAME_OLD_TUPLE_DISTINCT_EXACT_ATTEMPTS=PASS'

  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_a, et, et_diag, provider_low, bound_a, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_a%ready(), 'bound A')
  call fmr_materialize_candidate_bound_surface_evaporation(committed, candidate_b, et, et_diag, provider_high, bound_b, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_b%ready(), 'bound B')
  call fmr_prepare_surface_evaporation_publication(bound_a, prepared_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_a%ready(), 'prepare A')
  call fmr_prepare_surface_evaporation_publication(bound_b, prepared_b, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_b%ready(), 'prepare B')
  call fmr_commit_candidate_with_receipt(kernel_a, checkpoint, committed, candidate_a, diag_a, did_commit, receipt_a, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit A')
  call fmr_finalize_surface_evaporation_publication(prepared_a, receipt_a, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication%ready(), 'positive A/A')
  write(*,'(A)') 'FVQ70_POSITIVE_EXACT_PUBLICATION=PASS'
  call fmr_finalize_surface_evaporation_publication(prepared_b, receipt_a, attack_publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH .and. .not. attack_publication%ready(), 'F-VQ69 HN5 reject')
  write(*,'(A)') 'FVQ70_FVQ69_HN5=PASS_CLOSED'

  ! Different execution domains must not be interchangeable at commit time.
  call make_committed(81002_int64, committed_cross)
  call committed_cross%capture_checkpoint(checkpoint_cross, ok)
  call require(ok, 'checkpoint cross')
  call kernel_a%advance_interval(parameters, committed_cross, forcing, config, t0, t1, result, candidate_cross, diag_cross, checkpoint_cross)
  call require(result%completed .and. candidate_cross%ready(), 'candidate cross')
  call kernel_b%commit_candidate(committed_cross, candidate_cross, diag_cross, did_commit, commit_status)
  call require(.not. did_commit .and. commit_status == KERNEL_COMMIT_STATUS_EXECUTION_PROVENANCE_MISMATCH, 'different domain reject')
  call require(candidate_cross%ready(), 'candidate survives different domain reject')
  write(*,'(A)') 'FVQ70_CROSS_DOMAIN_COMMIT=PASS_CLOSED'

  ! Generic F-KT remains usable, while accepted-side surface attribution must
  ! fail closed if exact attempt provenance is unavailable.
  call make_committed(81003_int64, committed_plain)
  call committed_plain%capture_checkpoint(checkpoint_plain, ok)
  call require(ok, 'checkpoint plain')
  call kernel_plain%advance_interval(parameters, committed_plain, forcing, config, t0, t1, result, candidate_plain, diag_plain, checkpoint_plain)
  call require(result%completed .and. candidate_plain%ready(), 'plain candidate')
  call fmr_materialize_candidate_bound_surface_evaporation(committed_plain, candidate_plain, et, et_diag, provider_low, bound_plain, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_EXACT_PROVENANCE_UNAVAILABLE .and. .not. bound_plain%ready(), 'plain surface fail closed')
  call kernel_plain%commit_candidate(committed_plain, candidate_plain, diag_plain, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'plain generic commit')
  write(*,'(A)') 'FVQ70_GENERIC_FKT_SURFACE_PUBLICATION=PASS_CLOSED'

  ! Hard negative HN-DOMAIN: independently live executors are deliberately
  ! assigned the same execution provenance domain. Because both begin their
  ! local candidate sequence at 1, a mechanism that merely trusts caller-side
  ! domain uniqueness can recreate an exact-token collision.
  call kernel_c%bind_execution_provenance(collision_domain, did_bind)
  call require(did_bind, 'bind collision C')
  call kernel_d%bind_execution_provenance(collision_domain, did_bind)
  call require(did_bind, 'bind collision D')
  call make_committed(81004_int64, committed_collision)
  call committed_collision%capture_checkpoint(checkpoint_collision, ok)
  call require(ok, 'checkpoint collision')
  call kernel_c%advance_interval(parameters, committed_collision, forcing, config, t0, t1, result, candidate_c, diag_c, checkpoint_collision)
  call require(result%completed .and. candidate_c%ready(), 'candidate C')
  call kernel_d%advance_interval(parameters, committed_collision, forcing, config, t0, t1, result, candidate_d, diag_d, checkpoint_collision)
  call require(result%completed .and. candidate_d%ready(), 'candidate D')
  call candidate_c%exact_attempt_provenance(id_c, seq_c, available)
  call require(available, 'candidate C exact')
  call candidate_d%exact_attempt_provenance(id_d, seq_d, available)
  call require(available, 'candidate D exact')
  call require(id_c == collision_domain .and. id_d == collision_domain, 'collision IDs')
  call require(seq_c == 1_int64 .and. seq_d == 1_int64, 'collision sequences')
  write(*,'(A)') 'FVQ70_DUPLICATE_DOMAIN_EXACT_TOKEN_COLLISION=REPRODUCED'

  call fmr_materialize_candidate_bound_surface_evaporation(committed_collision, candidate_c, et, et_diag, provider_low, bound_c, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_c%ready(), 'bound C')
  call fmr_materialize_candidate_bound_surface_evaporation(committed_collision, candidate_d, et, et_diag, provider_high, bound_d, surface_diag)
  call require(surface_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. bound_d%ready(), 'bound D')
  call fmr_prepare_surface_evaporation_publication(bound_c, prepared_c, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_c%ready(), 'prepare C')
  call fmr_prepare_surface_evaporation_publication(bound_d, prepared_d, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. prepared_d%ready(), 'prepare D')
  call fmr_commit_candidate_with_receipt(kernel_c, checkpoint_collision, committed_collision, candidate_c, diag_c, did_commit, receipt_c, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'commit C')

  call fmr_finalize_surface_evaporation_publication(prepared_d, receipt_c, attack_publication, status)
  if (status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. attack_publication%ready()) then
    write(*,'(A)') 'FVQ70_HN_DUPLICATE_EXECUTION_DOMAIN=FAIL_OPEN'
    write(*,'(A)') 'FVQ70_DECISION=NOT_QUALIFIED_RUNTIME_EXECUTION_DOMAIN_UNIQUENESS_NOT_ENFORCED'
  else
    call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH .and. .not. attack_publication%ready(), 'duplicate domain fail closed disposition')
    write(*,'(A)') 'FVQ70_HN_DUPLICATE_EXECUTION_DOMAIN=PASS_CLOSED'
    write(*,'(A)') 'FVQ70_DECISION=QUALIFIED_EXACT_CANDIDATE_ATTEMPT_PROVENANCE'
  end if

  call require(diag_a%mass_rejections == 0 .and. diag_b%mass_rejections == 0 .and. diag_cross%mass_rejections == 0 .and. &
       diag_plain%mass_rejections == 0 .and. diag_c%mass_rejections == 0 .and. diag_d%mass_rejections == 0, 'mass diagnostics unchanged')
  write(*,'(A)') 'FVQ70_NO_MASS_REGRESSION=PASS'
  write(*,'(A)') 'FVQ70_INDEPENDENT_ORACLE=PASS'

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
      p%pressure_head = [-115.0_real64, -245.0_real64]
      p%water_content = [0.21_real64, 0.25_real64]
      p%ponding_depth = 0.0_real64
      p%groundwater_level = -185.0_real64
    end select
    call state%initialize(lineage, physical, initialized, t0)
    call require(initialized, 'initialize committed')
  end subroutine make_committed

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ70_REQUIRE_FAIL', trim(label)
      error stop 70
    end if
  end subroutine require

end program test_fvq70_exact_candidate_provenance_independent
