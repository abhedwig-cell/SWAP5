module mod_ebi01_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: ebi01_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => ebi01_clone
  end type ebi01_state_t

  type, extends(kernel_parameters_t), public :: ebi01_parameters_t
    real(real64) :: flux_rate = 0.1_real64
  end type ebi01_parameters_t

  type, extends(canonical_forcing_t), public :: ebi01_forcing_t
    real(real64) :: scale = 1.0_real64
  end type ebi01_forcing_t

  type, extends(kernel_model_t), public :: ebi01_model_t
    real(real64) :: flux_rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
  contains
    procedure :: configure_parameters => ebi01_configure_parameters
    procedure :: execution_admitted => ebi01_execution_admitted
    procedure :: prepare_interval => ebi01_prepare_interval
    procedure :: advance => ebi01_advance
    procedure :: storage => ebi01_storage
    procedure :: temporal_error => ebi01_temporal_error
  end type ebi01_model_t

contains

  subroutine ebi01_clone(self, copy)
    class(ebi01_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(ebi01_state_t :: copy)
    select type (copy)
    type is (ebi01_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine ebi01_clone

  subroutine ebi01_configure_parameters(self, parameters)
    class(ebi01_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (ebi01_parameters_t)
      self%flux_rate = parameters%flux_rate
    class default
      error stop 'EB-I01 unexpected parameter type'
    end select
  end subroutine ebi01_configure_parameters

  logical function ebi01_execution_admitted(self, parameters, numerical_config)
    class(ebi01_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (ebi01_parameters_t)
      parameter_ok = parameters%flux_rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    ebi01_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%scale >= 0.0_real64
  end function ebi01_execution_admitted

  subroutine ebi01_prepare_interval(self, forcing, interval, config)
    class(ebi01_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (ebi01_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'EB-I01 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'EB-I01 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'EB-I01 invalid config'
  end subroutine ebi01_prepare_interval

  subroutine ebi01_advance(self, state, t0, t1, outcome)
    class(ebi01_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: transfer_mass

    outcome = trial_outcome_t()
    transfer_mass = self%flux_rate * self%scale * (t1 - t0)
    select type (state)
    type is (ebi01_state_t)
      state%storage_value = state%storage_value + transfer_mass
    class default
      error stop 'EB-I01 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = transfer_mass
    outcome%nonlinear_iterations = 1
  end subroutine ebi01_advance

  real(real64) function ebi01_storage(self, state) result(value)
    class(ebi01_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%scale < 0.0_real64) error stop 'EB-I01 unreachable scale'
    select type (state)
    type is (ebi01_state_t)
      value = state%storage_value
    class default
      error stop 'EB-I01 unexpected state type'
    end select
  end function ebi01_storage

  real(real64) function ebi01_temporal_error(self, full_state, half_state) result(value)
    class(ebi01_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%scale < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'EB-I01 unexpected temporal state'
    end if
    value = 0.0_real64
  end function ebi01_temporal_error

end module mod_ebi01_test_model

program test_ebi01_energy_ledger_receipt_integration
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt
  use mod_energy_conservation_types, only: energy_balance_t, ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger
  use mod_ebi01_test_model
  implicit none

  integer(int64), parameter :: SOIL = 1_int64, CANOPY = 2_int64
  integer(int64) :: ids(2), soil_only(1)
  real(real64) :: initial_energy(2), final_energy(2)
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint0, checkpoint1
  type(kernel_executor_t) :: kernel
  type(ebi01_model_t), target :: model
  type(ebi01_parameters_t) :: parameters
  type(ebi01_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(energy_trial_ledger_t) :: ledger, validation_ledger
  type(prepared_energy_trial_t) :: prepared
  type(energy_commit_record_t) :: record, rollback_record
  type(fmr_accepted_commit_receipt_t) :: receipt, old_receipt
  type(energy_balance_t) :: balance
  logical :: ok, did_commit, available
  integer :: status, receipt_status, commit_status

  ids = [SOIL, CANOPY]
  soil_only = [SOIL]
  initial_energy = [100.0_real64, 20.0_real64]
  final_energy = [120.0_real64, 25.0_real64]

  call validation_ledger%begin_trial(8199_int64, 0_int64, 0.0_real64, 0.5_real64, ids, initial_energy, status, 1)
  call require(status == ENERGY_LEDGER_OK, 'start component registration validation')
  call validation_ledger%record_transfer(SOIL, 99_int64, 1.0_real64, status)
  call require(status == ENERGY_LEDGER_UNKNOWN_COMPONENT, 'unknown target component rejected')
  call validation_ledger%record_transfer(99_int64, CANOPY, 1.0_real64, status)
  call require(status == ENERGY_LEDGER_UNKNOWN_COMPONENT, 'unknown source component rejected')
  call require(validation_ledger%has_active_trial(), 'component rejection leaves trial intact')
  call validation_ledger%discard_trial(status)
  call require(status == ENERGY_LEDGER_OK .and. .not. validation_ledger%has_active_trial(), &
       'component validation trial discarded cleanly')
  print '(a)', 'EBI01_UNREGISTERED_INTERNAL_COMPONENT_REJECTED=PASS'

  call setup_solver(parameters, forcing, config)
  call kernel%bind_model(model)
  call setup_committed(committed, 8101_int64, 0.0_real64)
  call committed%capture_checkpoint(checkpoint0, ok)
  call require(ok, 'capture initial checkpoint')

  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint0, 0.0_real64, 0.5_real64, &
       candidate, diagnostics)
  call stage_energy_trial(ledger, 8101_int64, 0_int64, 0.0_real64, 0.5_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'stage first energy trial')
  call ledger%summarize_control_volume(soil_only, balance, status)
  call require(status == ENERGY_LEDGER_OK .and. bitwise_equal(balance%residual_j_m2, 0.0_real64), &
       'nested soil control volume closes')
  call ledger%prepare_trial(prepared, status)
  call require(status == ENERGY_LEDGER_OK .and. prepared%ready(), 'prepare first energy trial')

  call fmr_commit_candidate_with_receipt(kernel, checkpoint0, committed, candidate, diagnostics, did_commit, &
       receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'physical commit creates receipt')
  call require(ledger%prepared_ready_for_receipt(prepared, receipt), 'prepared energy matches accepted receipt')
  call ledger%commit_prepared(prepared, receipt, record)
  call require(record%ready(), 'energy commit record published')
  call record%conservation_balance(balance, available)
  call require(available .and. bitwise_equal(balance%residual_j_m2, 0.0_real64), 'accepted outer energy balance closes')
  call require(bitwise_equal(balance%boundary_input_j_m2, 30.0_real64) .and. &
       bitwise_equal(balance%boundary_output_j_m2, 5.0_real64), 'accepted boundary energy')
  call require(.not. prepared%ready() .and. .not. ledger%has_prepared_trial(), 'accepted prepared handle consumed')
  old_receipt = receipt
  print '(a)', 'EBI01_REAL_FKT_RECEIPT_PUBLISHES_ENERGY_ONCE=PASS'

  call committed%capture_checkpoint(checkpoint1, ok)
  call require(ok .and. committed%current_revision() == 1_int64, 'capture replay checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint1, 0.5_real64, 0.75_real64, &
       candidate, diagnostics)
  call stage_energy_trial(ledger, 8101_int64, 1_int64, 0.5_real64, 0.75_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'stage rollback energy trial')
  call ledger%prepare_trial(prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'prepare rollback energy trial')
  call kernel%rollback_candidate(candidate, diagnostics)
  call ledger%abort_prepared(prepared)
  call require(.not. candidate%ready(), 'physical rollback discards candidate')
  call require(.not. prepared%ready() .and. .not. ledger%has_prepared_trial(), 'energy rollback discards prepared trial')
  call require(.not. rollback_record%ready(), 'rollback publishes no energy record')
  call require(committed%current_revision() == 1_int64, 'rollback leaves committed revision unchanged')
  print '(a)', 'EBI01_ROLLBACK_PUBLISHES_NO_ENERGY=PASS'

  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint1, 0.5_real64, 0.75_real64, &
       candidate, diagnostics)
  call stage_energy_trial(ledger, 8101_int64, 1_int64, 0.5_real64, 0.75_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'restage replay energy trial')
  call ledger%prepare_trial(prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'prepare replay energy trial')
  call require(.not. ledger%prepared_ready_for_receipt(prepared, old_receipt), 'stale receipt rejected')
  call fmr_commit_candidate_with_receipt(kernel, checkpoint1, committed, candidate, diagnostics, did_commit, &
       receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'replay physical commit succeeds')
  call require(ledger%prepared_ready_for_receipt(prepared, receipt), 'replay receipt matches prepared energy')
  call ledger%commit_prepared(prepared, receipt, record)
  call require(record%ready() .and. record%origin_revision() == 1_int64 .and. &
       record%committed_revision() == 2_int64, 'replay energy record revision identity')
  call record%conservation_balance(balance, available)
  call require(available .and. bitwise_equal(balance%residual_j_m2, 0.0_real64), 'replay energy closes')
  print '(a)', 'EBI01_ROLLBACK_REPLAY_FROM_SAME_COMMITTED_ORIGIN=PASS'

  call require(committed%current_revision() == 2_int64, 'existing mass transaction path still commits')
  print '(a)', 'EBI01_EXISTING_FKT_MASS_PATH_PRESERVED=PASS'
  print '(a)', 'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS'

contains

  subroutine stage_energy_trial(e, lineage, revision, t0, t1, s)
    type(energy_trial_ledger_t), intent(inout) :: e
    integer(int64), intent(in) :: lineage, revision
    real(real64), intent(in) :: t0, t1
    integer, intent(out) :: s

    call e%begin_trial(lineage, revision, t0, t1, ids, initial_energy, s, 1)
    if (s /= ENERGY_LEDGER_OK) return
    call e%record_transfer(ENERGY_EXTERNAL_COMPONENT, SOIL, 30.0_real64, s)
    if (s /= ENERGY_LEDGER_OK) return
    call e%record_transfer(SOIL, CANOPY, 10.0_real64, s)
    if (s /= ENERGY_LEDGER_OK) return
    call e%record_transfer(CANOPY, ENERGY_EXTERNAL_COMPONENT, 5.0_real64, s)
    if (s /= ENERGY_LEDGER_OK) return
    call e%set_end_storage(final_energy, s)
  end subroutine stage_energy_trial

  subroutine setup_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(ebi01_state_t :: physical)
    select type (physical)
    type is (ebi01_state_t)
      physical%storage_value = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'initialize committed test state')
  end subroutine setup_committed

  subroutine setup_solver(p, f, c)
    type(ebi01_parameters_t), intent(out) :: p
    type(ebi01_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%flux_rate = 0.1_real64
    f%scale = 1.0_real64
    c%transaction%temporal_tolerance = 1.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine setup_solver

  subroutine advance_candidate(k, p, f, c, state, checkpoint, t0_in, t1_in, candidate_out, diagnostics_out)
    type(kernel_executor_t), intent(inout) :: k
    type(ebi01_parameters_t), intent(in) :: p
    type(ebi01_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(in) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0_in, t1_in
    type(kernel_candidate_state_t), intent(out) :: candidate_out
    type(kernel_diagnostics_t), intent(out) :: diagnostics_out
    type(kernel_result_t) :: result

    call k%advance_interval(p, state, f, c, t0_in, t1_in, result, candidate_out, diagnostics_out, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-KT trial completes')
    call require(candidate_out%ready(), 'F-KT candidate materialized')
  end subroutine advance_candidate

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

  logical function bitwise_equal(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function bitwise_equal

end program test_ebi01_energy_ledger_receipt_integration
