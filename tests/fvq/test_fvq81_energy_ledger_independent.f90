module mod_fvq81_energy_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq81_state_t
    real(real64) :: water_store = 3.0_real64
  contains
    procedure :: clone => fvq81_clone
  end type fvq81_state_t

  type, extends(kernel_parameters_t), public :: fvq81_parameters_t
    real(real64) :: inflow_rate = 0.2_real64
  end type fvq81_parameters_t

  type, extends(canonical_forcing_t), public :: fvq81_forcing_t
    real(real64) :: multiplier = 1.0_real64
  end type fvq81_forcing_t

  type, extends(kernel_model_t), public :: fvq81_model_t
    real(real64) :: inflow_rate = 0.2_real64
    real(real64) :: multiplier = 1.0_real64
  contains
    procedure :: configure_parameters => fvq81_configure
    procedure :: execution_admitted => fvq81_admitted
    procedure :: prepare_interval => fvq81_prepare
    procedure :: advance => fvq81_advance
    procedure :: storage => fvq81_storage
    procedure :: temporal_error => fvq81_temporal_error
    procedure :: storage_accounting_status => fvq81_storage_status
  end type fvq81_model_t

contains

  subroutine fvq81_clone(self, copy)
    class(fvq81_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq81_state_t :: copy)
    select type (copy)
    type is (fvq81_state_t)
      copy%water_store = self%water_store
    end select
  end subroutine fvq81_clone

  subroutine fvq81_configure(self, parameters)
    class(fvq81_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fvq81_parameters_t)
      self%inflow_rate = parameters%inflow_rate
    class default
      self%inflow_rate = -1.0_real64
    end select
  end subroutine fvq81_configure

  logical function fvq81_admitted(self, parameters, numerical_config)
    class(fvq81_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (fvq81_parameters_t)
      parameter_ok = parameters%inflow_rate >= 0.0_real64
    end select
    fvq81_admitted = parameter_ok .and. self%multiplier >= 0.0_real64 .and. numerical_config%max_committed_substeps > 0
  end function fvq81_admitted

  subroutine fvq81_prepare(self, forcing, interval, config)
    class(fvq81_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fvq81_forcing_t)
      self%multiplier = forcing%multiplier
    class default
      self%multiplier = -1.0_real64
    end select
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) self%multiplier = -1.0_real64
  end subroutine fvq81_prepare

  subroutine fvq81_advance(self, state, t0, t1, outcome)
    class(fvq81_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount
    outcome = trial_outcome_t()
    amount = self%inflow_rate * self%multiplier * (t1 - t0)
    select type (state)
    type is (fvq81_state_t)
      state%water_store = state%water_store + amount
      outcome%solver_ok = .true.
      outcome%mass_in = amount
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%nonlinear_iterations = 1
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine fvq81_advance

  real(real64) function fvq81_storage(self, state) result(value)
    class(fvq81_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq81_state_t)
      value = state%water_store
    end select
  end function fvq81_storage

  real(real64) function fvq81_temporal_error(self, full_state, half_state) result(value)
    class(fvq81_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) return
    value = 0.0_real64
  end function fvq81_temporal_error

  subroutine fvq81_storage_status(self, state, complete, missing_mask)
    class(fvq81_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_NONE
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq81_state_t)
      complete = .true.
    end select
  end subroutine fvq81_storage_status

end module mod_fvq81_energy_model

program test_fvq81_energy_ledger_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_energy_conservation_types, only: energy_balance_t, ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger
  use mod_fvq81_energy_model
  implicit none

  integer(int64), parameter :: LINEAGE = 81081_int64, STORE = 901_int64
  type(kernel_executor_t) :: kernel
  type(fvq81_model_t), target :: model
  type(fvq81_parameters_t) :: parameters
  type(fvq81_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_accepted_commit_receipt_t) :: receipt, old_receipt, invalid_receipt
  type(energy_trial_ledger_t) :: ledger, algebra
  type(prepared_energy_trial_t) :: prepared, stale_prepared, current_prepared
  type(energy_commit_record_t) :: record
  type(energy_balance_t) :: balance
  integer :: status, receipt_status, commit_status
  logical :: ok, did_commit, available
  real(real64) :: rt0, rt1
  integer(int64) :: ids1(1), ids2(2), subset(1)
  real(real64) :: e0_1(1), e1_1(1), e0_2(2), e1_2(2)

  call setup_config(parameters, forcing, config)
  call kernel%bind_model(model)
  call initialize_committed(committed)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'initial checkpoint')
  call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 1.0_real64, result, candidate, diagnostics, checkpoint)
  call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed .and. candidate%ready(), 'real F-KT candidate')
  call require(result%mass%complete .and. abs(result%mass%residual) <= 1.0e-12_real64, 'real F-KT mass complete')

  ids1 = [STORE]; e0_1 = [50.0_real64]; e1_1 = [58.0_real64]
  call ledger%begin_trial(LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids1, e0_1, status, 2)
  call require(status == ENERGY_LEDGER_OK, 'begin accepted energy trial')
  call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, STORE, 8.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'record accepted energy transfer')
  call ledger%set_end_storage(e1_1, status)
  call require(status == ENERGY_LEDGER_OK, 'set accepted energy storage')
  call ledger%prepare_trial(prepared, status)
  call require(status == ENERGY_LEDGER_OK .and. prepared%ready(), 'prepare accepted energy')

  call ledger%commit_prepared(prepared, invalid_receipt, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE .and. .not. record%ready(), 'invalid receipt rejected')
  call require(prepared%ready() .and. ledger%has_prepared_trial(), 'invalid receipt preserves current prepared state')
  print '(a)', 'FVQ81_INVALID_RECEIPT_NO_PUBLICATION=PASS'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate, diagnostics, did_commit, receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), 'real accepted receipt')
  call require(ledger%prepared_ready_for_receipt(prepared, receipt), 'accepted receipt matches prepared energy')
  call ledger%commit_prepared(prepared, receipt, record, status)
  call require(status == ENERGY_LEDGER_OK .and. record%ready(), 'accepted energy published')
  call require(record%current_lineage_id() == LINEAGE .and. record%origin_revision() == 0_int64 .and. &
       record%committed_revision() == 1_int64, 'accepted publication revision provenance')
  call record%origin_interval(rt0, rt1, available)
  call require(available .and. rt0 == 0.0_real64 .and. rt1 == 1.0_real64, 'accepted publication interval provenance')
  call record%conservation_balance(balance, available)
  call require(available .and. abs(balance%residual_j_m2) <= 1.0e-12_real64, 'accepted energy balance closes')
  call require(committed%current_revision() == 1_int64, 'physical revision committed once')
  old_receipt = receipt
  print '(a)', 'FVQ81_ACCEPTED_RECEIPT_PUBLISHES_EXACT_PROVENANCE=PASS'

  call ledger%commit_prepared(prepared, receipt, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE .and. .not. record%ready(), 'double publication rejected')
  call require(.not. ledger%has_prepared_trial(), 'consumed prepared state remains consumed')
  print '(a)', 'FVQ81_DOUBLE_PUBLICATION_FAIL_CLOSED=PASS'

  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'revision-one checkpoint')
  call kernel%advance_interval(parameters, committed, forcing, config, 1.0_real64, 2.0_real64, result, candidate, diagnostics, checkpoint)
  call require(result%completed .and. candidate%ready(), 'replay candidate')
  call ledger%begin_trial(LINEAGE, 1_int64, 1.0_real64, 2.0_real64, ids1, e0_1, status, 2)
  call require(status == ENERGY_LEDGER_OK, 'begin revision-one energy')
  call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, STORE, 8.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'record revision-one transfer')
  call ledger%set_end_storage(e1_1, status)
  call require(status == ENERGY_LEDGER_OK, 'set revision-one storage')
  call ledger%prepare_trial(prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'prepare revision-one energy')
  call ledger%commit_prepared(prepared, old_receipt, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE .and. .not. record%ready(), 'stale receipt rejected')
  call require(prepared%ready() .and. ledger%has_prepared_trial(), 'stale receipt preserves current prepared')
  call kernel%rollback_candidate(candidate, diagnostics)
  call ledger%abort_prepared(prepared, status)
  call require(status == ENERGY_LEDGER_OK .and. .not. ledger%has_prepared_trial(), 'rollback aborts prepared energy')
  call require(committed%current_revision() == 1_int64, 'rollback leaves committed revision unchanged')
  print '(a)', 'FVQ81_STALE_RECEIPT_AND_ROLLBACK_NO_LEAK=PASS'

  call stage_small_prepared(ledger, stale_prepared, 2.0_real64, 3.0_real64)
  call ledger%abort_prepared(stale_prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'consume old generation')
  call stage_small_prepared(ledger, current_prepared, 3.0_real64, 4.0_real64)
  call ledger%abort_prepared(stale_prepared, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'stale generation abort rejected')
  call require(current_prepared%ready() .and. ledger%has_prepared_trial(), 'stale generation preserves current state')
  call ledger%abort_prepared(current_prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'current generation abort succeeds')
  print '(a)', 'FVQ81_STALE_GENERATION_NONTERMINATING=PASS'

  ids2 = [1001_int64, 1002_int64]; subset = [1001_int64]
  e0_2 = [10.0_real64, 20.0_real64]; e1_2 = [12.0_real64, 22.0_real64]
  call algebra%begin_trial(90001_int64, 4_int64, 7.0_real64, 8.0_real64, ids2, e0_2, status, 4)
  call require(status == ENERGY_LEDGER_OK, 'begin algebra trial')
  call algebra%record_transfer(ENERGY_EXTERNAL_COMPONENT, 1001_int64, 5.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'external input')
  call algebra%record_transfer(1001_int64, 1002_int64, 3.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'internal transfer')
  call algebra%record_transfer(1002_int64, ENERGY_EXTERNAL_COMPONENT, 1.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'external output')
  call algebra%set_end_storage(e1_2, status)
  call require(status == ENERGY_LEDGER_OK, 'algebra final storage')
  call algebra%summarize_control_volume(ids2, balance, status)
  call require(status == ENERGY_LEDGER_OK .and. abs(balance%residual_j_m2) <= 1.0e-12_real64, 'whole control volume closes')
  call require(abs(balance%boundary_input_j_m2 - 5.0_real64) <= 1.0e-12_real64 .and. &
       abs(balance%boundary_output_j_m2 - 1.0_real64) <= 1.0e-12_real64, 'internal transfer cancels in whole control volume')
  call algebra%summarize_control_volume(subset, balance, status)
  call require(status == ENERGY_LEDGER_OK .and. abs(balance%residual_j_m2) <= 1.0e-12_real64, 'nested control volume closes')
  call require(abs(balance%boundary_output_j_m2 - 3.0_real64) <= 1.0e-12_real64, 'internal transfer becomes nested boundary')
  call algebra%discard_trial(status)
  call require(status == ENERGY_LEDGER_OK, 'discard algebra trial')
  print '(a)', 'FVQ81_CONTROL_VOLUME_CONSERVATION_INDEPENDENT=PASS'

  print '(a)', 'FVQ81_ENERGY_LEDGER_INDEPENDENT_ORACLE=PASS'

contains

  subroutine setup_config(p, f, c)
    type(fvq81_parameters_t), intent(out) :: p
    type(fvq81_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%inflow_rate = 0.2_real64
    f%multiplier = 1.0_real64
    c%transaction%temporal_tolerance = 1.0e-12_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 1
    c%max_committed_substeps = 4
    c%progress_tolerance = 0.0_real64
  end subroutine setup_config

  subroutine initialize_committed(state)
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fvq81_state_t :: physical)
    select type (physical)
    type is (fvq81_state_t)
      physical%water_store = 3.0_real64
    end select
    call state%initialize(LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize F-VQ81 committed state')
  end subroutine initialize_committed

  subroutine stage_small_prepared(e, p, t0, t1)
    type(energy_trial_ledger_t), intent(inout) :: e
    type(prepared_energy_trial_t), intent(out) :: p
    real(real64), intent(in) :: t0, t1
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: s
    ids = [STORE]; initial_energy = [4.0_real64]; final_energy = [5.0_real64]
    call e%begin_trial(LINEAGE, 1_int64, t0, t1, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin small prepared')
    call e%record_transfer(ENERGY_EXTERNAL_COMPONENT, STORE, 1.0_real64, s)
    call require(s == ENERGY_LEDGER_OK, 'small prepared transfer')
    call e%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'small prepared storage')
    call e%prepare_trial(p, s)
    call require(s == ENERGY_LEDGER_OK .and. p%ready(), 'small prepared ready')
  end subroutine stage_small_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ81_FAIL ', trim(label)
      error stop 81
    end if
  end subroutine require

end program test_fvq81_energy_ledger_independent
