program test_fgc21_restricted_predictor_corrector_window
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_executor_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, &
       GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, &
       GW_SWAP_FORCING_OK, GW_SWAP_FORCING_PROFILE_NOT_ADMITTED, GW_SWAP_FORCING_INVALID_HEAD
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK, GW_PC_NOT_CONVERGED, GW_PC_INVALID_ORIGIN, &
       GW_PC_PREDICTOR_GROUNDWATER_FAILED
  implicit none

  integer :: failures

  type, extends(canonical_state_t) :: dummy_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => dummy_state_clone
  end type dummy_state_t

  type, extends(canonical_forcing_t) :: dummy_forcing_t
    real(real64) :: interface_head_m = 0.0_real64
  end type dummy_forcing_t

  type, extends(kernel_parameters_t) :: dummy_parameters_t
    logical :: admitted = .true.
  end type dummy_parameters_t

  type, extends(groundwater_swap_forcing_materializer_t) :: dummy_materializer_t
  contains
    procedure :: profile_admitted => dummy_profile_admitted
    procedure :: materialize => dummy_materialize
  end type dummy_materializer_t

  type, extends(kernel_model_t) :: dummy_model_t
    logical :: configured = .false.
    real(real64) :: current_head_m = 0.0_real64
    integer :: prepare_count = 0
    integer :: advance_count = 0
  contains
    procedure :: configure_parameters => dummy_configure_parameters
    procedure :: execution_admitted => dummy_execution_admitted
    procedure :: prepare_interval => dummy_prepare_interval
    procedure :: advance => dummy_advance
    procedure :: storage => dummy_storage
    procedure :: temporal_error => dummy_temporal_error
    procedure :: storage_accounting_status => dummy_storage_accounting_status
  end type dummy_model_t

  type, extends(groundwater_preparable_exchange_service_t) :: dummy_groundwater_service_t
    integer(int64) :: service_id_value = 701_int64
    integer(int64) :: lineage_id_value = 801_int64
    integer(int64) :: revision = 0_int64
    real(real64) :: current_time = 0.0_real64
    real(real64) :: pending_t1 = 0.0_real64
    integer :: response_mode = 0
    integer :: fail_trial_number = 0
    logical :: fail_prepare = .false.
    integer :: capture_count = 0
    integer :: trial_count = 0
    integer :: discard_count = 0
    integer :: prepare_count = 0
    integer :: commit_count = 0
    integer :: abort_count = 0
    integer(int64) :: last_candidate_token = 0_int64
    real(real64) :: last_q_groundwater_m_per_s = 0.0_real64
  contains
    procedure :: capture_backend => dummy_gw_capture
    procedure :: trial_backend => dummy_gw_trial
    procedure :: commit_backend => dummy_gw_commit
    procedure :: discard_backend => dummy_gw_discard
    procedure :: prepare_backend => dummy_gw_prepare
    procedure :: commit_prepared_backend => dummy_gw_commit_prepared
    procedure :: abort_prepared_backend => dummy_gw_abort_prepared
  end type dummy_groundwater_service_t

  failures = 0
  call test_converged_commit(failures)
  call test_nonconverged_rolls_back_everything(failures)
  call test_stale_origin_fails_before_trials(failures)
  call test_predictor_groundwater_rejection_is_fail_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC21 OWNER HARNESS FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC21 OWNER HARNESS PASS'

contains

  subroutine test_converged_commit(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(groundwater_pc_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    class(transaction_state_t), allocatable :: initial_state, snapshot
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    real(real64) :: committed_time, expected_rate, expected_exchange_cm, expected_q_swap, expected_storage
    logical :: initialized, time_available, snapshot_available
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call check(initialized, 'converged: committed state initialized', failures)
    call check(status == GW_MASS_LEDGER_OK, 'converged: ledger identity bound', failures)

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, result)

    expected_rate = 0.2_real64 + 0.01_real64 * 0.5_real64
    expected_exchange_cm = expected_rate * (window%t1 - window%t0)
    expected_q_swap = expected_rate * 0.01_real64 / 86400.0_real64
    expected_storage = 10.0_real64 - expected_exchange_cm

    call check(result%status == GW_PC_OK, 'converged: status OK', failures)
    call check(result%completed .and. result%committed, 'converged: committed result', failures)
    call check(.not. result%request_smaller_window, 'converged: no shrink request', failures)
    call check(model%prepare_count == 2, 'converged: exactly two SWAP trajectories prepared', failures)
    call check(model%advance_count == 2, 'converged: exactly two SWAP physical advances', failures)
    call check(result%diagnostics%predictor_swap%checkpoint_uses == 1, &
         'converged: predictor used reusable checkpoint', failures)
    call check(result%diagnostics%corrector_swap%checkpoint_uses == 1, &
         'converged: corrector used same-origin checkpoint route', failures)
    call check(result%diagnostics%predictor_swap%committed_state_mutations == 0, &
         'converged: predictor never committed', failures)
    call check(result%diagnostics%predictor_swap%candidate_rollbacks == 1, &
         'converged: predictor SWAP candidate rolled back', failures)
    call check(result%diagnostics%corrector_swap%committed_state_mutations == 1, &
         'converged: corrector committed once', failures)

    call check(groundwater%trial_count == 2, 'converged: exactly two groundwater trials', failures)
    call check(groundwater%discard_count == 1, 'converged: predictor groundwater discarded', failures)
    call check(groundwater%prepare_count == 1, 'converged: corrector groundwater prepared once', failures)
    call check(groundwater%commit_count == 1, 'converged: groundwater committed once', failures)
    call check(groundwater%abort_count == 0, 'converged: no groundwater abort', failures)

    call check_close(result%corrector_swap_outward_exchange_cm, expected_exchange_cm, 1.0e-13_real64, &
         'converged: exact whole-window corrector exchange propagated', failures)
    call check_close(result%corrector_q_swap_m_per_s, expected_q_swap, 1.0e-18_real64, &
         'converged: q derived from whole-window exchange', failures)
    call check(abs(result%corrector_q_swap_m_per_s - 7.0_real64 * 0.01_real64 / 86400.0_real64) > 1.0e-9_real64, &
         'converged: terminal flux was not treated as window mean', failures)
    call check(transfer(result%corrector_q_groundwater_m_per_s, 0_int64) == &
         transfer(-result%corrector_q_swap_m_per_s, 0_int64), &
         'converged: q_groundwater is exact opposite assignment', failures)
    call check(transfer(result%residual%flux_residual_m_per_s, 0_int64) == transfer(0.0_real64, 0_int64), &
         'converged: exact zero flux residual', failures)
    call check_close(result%residual%head_residual_m, 0.0_real64, 1.0e-15_real64, &
         'converged: zero head residual', failures)

    call committed%current_time(committed_time, time_available)
    call check(time_available, 'converged: committed time available', failures)
    call check_close(committed_time, window%t1, 1.0e-14_real64, 'converged: SWAP committed to t1', failures)
    call check(committed%current_revision() == 1_int64, 'converged: SWAP revision advanced once', failures)
    call committed%snapshot(snapshot, snapshot_available)
    call check(snapshot_available, 'converged: committed snapshot available', failures)
    if (snapshot_available) then
      select type (typed_snapshot => snapshot)
      type is (dummy_state_t)
        call check_close(typed_snapshot%storage, expected_storage, 1.0e-13_real64, &
             'converged: corrector physical state committed', failures)
      class default
        call check(.false., 'converged: committed snapshot type', failures)
      end select
    end if

    call check_close(groundwater%current_time, window%t1, 1.0e-14_real64, &
         'converged: groundwater committed to t1', failures)
    call check(groundwater%revision == 1_int64, 'converged: groundwater revision advanced once', failures)
    call check_close(origin%accepted_time, window%t1, 1.0e-14_real64, 'converged: next origin time', failures)
    call check_close(origin%accepted_h_groundwater_m, 0.5_real64, 1.0e-15_real64, &
         'converged: next predictor head is accepted corrector groundwater head', failures)
    call check(origin%swap_revision == 1_int64 .and. origin%groundwater_revision == 1_int64, &
         'converged: next origin revisions advanced', failures)

    call ledger%snapshot(ledger_snapshot)
    call check(ledger_snapshot%available, 'converged: ledger snapshot available', failures)
    call check(ledger_snapshot%committed_exchange_count == 1, 'converged: one ledger commit', failures)
    call check_close(ledger_snapshot%committed_swap_outward_exchange_m, expected_exchange_cm * 0.01_real64, &
         1.0e-15_real64, 'converged: ledger carries exact accepted exchange', failures)
    call check(transfer(ledger_snapshot%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'converged: ledger conservation exact zero', failures)
  end subroutine test_converged_commit

  subroutine test_nonconverged_rolls_back_everything(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(groundwater_coupling_origin_t) :: original_origin
    type(groundwater_pc_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    class(transaction_state_t), allocatable :: initial_state, snapshot
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    real(real64) :: committed_time
    logical :: initialized, time_available, snapshot_available
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    groundwater%response_mode = 1
    original_origin = origin

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, result)

    call check(result%status == GW_PC_NOT_CONVERGED, 'nonconverged: explicit status', failures)
    call check(.not. result%committed .and. .not. result%completed, 'nonconverged: no coupled commit', failures)
    call check(result%request_smaller_window, 'nonconverged: outer shrink requested', failures)
    call check(model%prepare_count == 2 .and. model%advance_count == 2, &
         'nonconverged: bounded predictor plus one corrector only', failures)
    call check(groundwater%trial_count == 2, 'nonconverged: two groundwater trials only', failures)
    call check(groundwater%discard_count == 2, 'nonconverged: predictor and corrector groundwater discarded', failures)
    call check(groundwater%prepare_count == 0 .and. groundwater%commit_count == 0, &
         'nonconverged: no groundwater publication', failures)
    call check(committed%current_revision() == 0_int64, 'nonconverged: SWAP revision unchanged', failures)
    call committed%current_time(committed_time, time_available)
    call check(time_available, 'nonconverged: SWAP time available', failures)
    call check_close(committed_time, window%t0, 1.0e-14_real64, 'nonconverged: SWAP time unchanged', failures)
    call committed%snapshot(snapshot, snapshot_available)
    call check(snapshot_available, 'nonconverged: snapshot available', failures)
    if (snapshot_available) then
      select type (typed_snapshot => snapshot)
      type is (dummy_state_t)
        call check_close(typed_snapshot%storage, 10.0_real64, 1.0e-14_real64, &
             'nonconverged: SWAP physical state unchanged', failures)
      class default
        call check(.false., 'nonconverged: snapshot type', failures)
      end select
    end if
    call check(groundwater%revision == 0_int64, 'nonconverged: groundwater revision unchanged', failures)
    call check_close(groundwater%current_time, window%t0, 1.0e-14_real64, &
         'nonconverged: groundwater time unchanged', failures)
    call check(origin%coupling_id == original_origin%coupling_id .and. &
         origin%swap_revision == original_origin%swap_revision .and. &
         origin%groundwater_revision == original_origin%groundwater_revision, &
         'nonconverged: coupling provenance unchanged', failures)
    call check_close(origin%accepted_h_groundwater_m, original_origin%accepted_h_groundwater_m, 1.0e-15_real64, &
         'nonconverged: accepted predictor head unchanged', failures)

    call ledger%snapshot(ledger_snapshot)
    call check(ledger_snapshot%available, 'nonconverged: ledger snapshot available', failures)
    call check(ledger_snapshot%committed_exchange_count == 0, 'nonconverged: ledger committed count unchanged', failures)
    call check(.not. ledger_snapshot%trial_active .and. .not. ledger_snapshot%prepared_active, &
         'nonconverged: no staged/prepared ledger state remains', failures)
    call check(transfer(ledger_snapshot%committed_swap_outward_exchange_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'nonconverged: no committed interface water', failures)
  end subroutine test_nonconverged_rolls_back_everything

  subroutine test_stale_origin_fails_before_trials(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(groundwater_pc_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    class(transaction_state_t), allocatable :: initial_state
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    logical :: initialized
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    origin%swap_revision = 99_int64

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, result)

    call check(result%status == GW_PC_INVALID_ORIGIN, 'stale-origin: rejected', failures)
    call check(.not. result%request_smaller_window, 'stale-origin: provenance error is not numerical shrink', failures)
    call check(model%prepare_count == 0 .and. model%advance_count == 0, &
         'stale-origin: no SWAP trial started', failures)
    call check(groundwater%trial_count == 0, 'stale-origin: no groundwater trial started', failures)
    call check(committed%current_revision() == 0_int64 .and. groundwater%revision == 0_int64, &
         'stale-origin: both committed revisions unchanged', failures)
    call ledger%snapshot(ledger_snapshot)
    call check(ledger_snapshot%committed_exchange_count == 0 .and. .not. ledger_snapshot%trial_active, &
         'stale-origin: ledger untouched', failures)
  end subroutine test_stale_origin_fails_before_trials

  subroutine test_predictor_groundwater_rejection_is_fail_closed(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(groundwater_pc_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    class(transaction_state_t), allocatable :: initial_state
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    logical :: initialized
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    groundwater%fail_trial_number = 1

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, result)

    call check(result%status == GW_PC_PREDICTOR_GROUNDWATER_FAILED, 'predictor-reject: explicit status', failures)
    call check(result%request_smaller_window, 'predictor-reject: smaller outer window requested', failures)
    call check(.not. result%committed, 'predictor-reject: no coupled commit', failures)
    call check(model%advance_count == 1, 'predictor-reject: only predictor SWAP ran', failures)
    call check(groundwater%trial_count == 0, 'predictor-reject: rejected groundwater trial not published as success', failures)
    call check(committed%current_revision() == 0_int64 .and. groundwater%revision == 0_int64, &
         'predictor-reject: committed revisions unchanged', failures)
    call ledger%snapshot(ledger_snapshot)
    call check(ledger_snapshot%committed_exchange_count == 0 .and. .not. ledger_snapshot%trial_active, &
         'predictor-reject: ledger untouched', failures)
  end subroutine test_predictor_groundwater_rejection_is_fail_closed

  subroutine setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
       committed, initial_state, initialized, ledger_status)
    type(kernel_executor_t), intent(out) :: executor
    type(dummy_model_t), target, intent(out) :: model
    type(dummy_parameters_t), intent(out) :: parameters
    type(dummy_groundwater_service_t), intent(out) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledger
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_coupling_origin_t), intent(out) :: origin
    type(canonical_numerical_config_t), intent(out) :: numerical
    type(kernel_committed_state_t), intent(out) :: committed
    class(transaction_state_t), allocatable, intent(out) :: initial_state
    logical, intent(out) :: initialized
    integer, intent(out) :: ledger_status
    real(real64), parameter :: T0 = 123.375_real64
    real(real64), parameter :: T1 = 123.625_real64

    executor = kernel_executor_t()
    model = dummy_model_t()
    parameters = dummy_parameters_t()
    groundwater = dummy_groundwater_service_t()
    ledger = groundwater_interface_mass_ledger_t()
    datum = groundwater_head_datum_t()
    policy = groundwater_head_convergence_policy_t()
    window = groundwater_coupling_window_t()
    origin = groundwater_coupling_origin_t()
    numerical = canonical_numerical_config_t()
    committed = kernel_committed_state_t()

    allocate(dummy_state_t :: initial_state)
    select type (typed_initial => initial_state)
    type is (dummy_state_t)
      typed_initial%storage = 10.0_real64
    end select
    call committed%initialize(901_int64, initial_state, initialized, initial_time=T0)
    call executor%bind_model(model)

    groundwater%current_time = T0
    call ledger%bind_identity(1001_int64, ledger_status)

    datum%available = .true.
    datum%datum_id = 501_int64
    datum%bottom_boundary_elevation_m = -2.0_real64

    policy%available = .true.
    policy%policy_id = 601_int64
    policy%policy_version = 1
    policy%provenance_class = GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
    policy%provenance_id = 602_int64
    policy%provenance_qualified = .true.
    policy%head_tolerance_m = 0.01_real64

    window%t0 = T0
    window%t1 = T1

    origin%initialized = .true.
    origin%coupling_id = 10001_int64
    origin%accepted_h_groundwater_m = 0.4_real64
    origin%accepted_time = T0
    origin%swap_lineage_id = 901_int64
    origin%swap_revision = 0_int64
    origin%groundwater_service_id = groundwater%service_id_value
    origin%groundwater_lineage_id = groundwater%lineage_id_value
    origin%groundwater_revision = 0_int64

    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%temporal_tolerance = 1.0e-12_real64
    numerical%transaction%mass_tolerance = 1.0e-12_real64
    numerical%transaction%retry_scale = 0.5_real64
    numerical%transaction%max_retries = 2
    numerical%max_committed_substeps = 4
    numerical%progress_tolerance = 0.0_real64
  end subroutine setup_common

  subroutine dummy_state_clone(self, copy)
    class(dummy_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(dummy_state_t :: copy)
    select type (typed_copy => copy)
    type is (dummy_state_t)
      typed_copy%storage = self%storage
    end select
  end subroutine dummy_state_clone

  logical function dummy_profile_admitted(self, parameters) result(admitted)
    class(dummy_materializer_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    admitted = same_type_as(self, self)
    select type (typed_parameters => parameters)
    type is (dummy_parameters_t)
      admitted = admitted .and. typed_parameters%admitted
    class default
      admitted = .false.
    end select
  end function dummy_profile_admitted

  subroutine dummy_materialize(self, interface_head_m, datum, forcing, status)
    class(dummy_materializer_t), intent(in) :: self
    real(real64), intent(in) :: interface_head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    class(canonical_forcing_t), allocatable, intent(out) :: forcing
    integer, intent(out) :: status

    if (allocated(forcing)) deallocate(forcing)
    status = GW_SWAP_FORCING_INVALID_HEAD
    if (.not. same_type_as(self, self)) return
    if (.not. ieee_is_finite(interface_head_m) .or. .not. datum%valid()) return
    allocate(dummy_forcing_t :: forcing)
    select type (typed_forcing => forcing)
    type is (dummy_forcing_t)
      typed_forcing%interface_head_m = interface_head_m
      status = GW_SWAP_FORCING_OK
    class default
      status = GW_SWAP_FORCING_PROFILE_NOT_ADMITTED
    end select
  end subroutine dummy_materialize

  subroutine dummy_configure_parameters(self, parameters)
    class(dummy_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    self%configured = .false.
    select type (typed_parameters => parameters)
    type is (dummy_parameters_t)
      self%configured = typed_parameters%admitted
    end select
  end subroutine dummy_configure_parameters

  logical function dummy_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(dummy_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    admitted = self%advance_count >= 0 .and. numerical_config%max_committed_substeps > 0
    select type (typed_parameters => parameters)
    type is (dummy_parameters_t)
      admitted = admitted .and. typed_parameters%admitted
    class default
      admitted = .false.
    end select
  end function dummy_execution_admitted

  subroutine dummy_prepare_interval(self, forcing, interval, config)
    class(dummy_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%configured = self%configured .and. interval%t1 > interval%t0 .and. config%max_committed_substeps > 0
    self%prepare_count = self%prepare_count + 1
    select type (typed_forcing => forcing)
    type is (dummy_forcing_t)
      self%current_head_m = typed_forcing%interface_head_m
    class default
      self%configured = .false.
    end select
  end subroutine dummy_prepare_interval

  subroutine dummy_advance(self, state, t0, t1, outcome)
    class(dummy_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: exchange_rate_cm_per_day, exchange_cm

    outcome = trial_outcome_t()
    self%advance_count = self%advance_count + 1
    if (.not. self%configured .or. t1 <= t0) return
    exchange_rate_cm_per_day = 0.2_real64 + 0.01_real64 * self%current_head_m
    exchange_cm = exchange_rate_cm_per_day * (t1 - t0)
    if (.not. ieee_is_finite(exchange_cm)) return

    select type (typed_state => state)
    type is (dummy_state_t)
      typed_state%storage = typed_state%storage - exchange_cm
      outcome%solver_ok = .true.
      outcome%mass_in = 0.0_real64
      outcome%mass_out = exchange_cm
      outcome%bottom_interface_exchange_available = .true.
      outcome%bottom_outward_exchange_native = exchange_cm
      outcome%terminal_bottom_outward_flux_native = 7.0_real64
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = 0.0_real64
      outcome%nonlinear_iterations = 1
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine dummy_advance

  real(real64) function dummy_storage(self, state) result(value)
    class(dummy_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    value = 0.0_real64
    if (.not. same_type_as(self, self)) return
    select type (typed_state => state)
    type is (dummy_state_t)
      value = typed_state%storage
    end select
  end function dummy_storage

  real(real64) function dummy_temporal_error(self, full_state, half_state) result(value)
    class(dummy_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state

    value = 0.0_real64
    if (.not. same_type_as(self, self)) value = huge(0.0_real64)
    if (.not. same_type_as(full_state, half_state)) value = huge(0.0_real64)
  end function dummy_temporal_error

  subroutine dummy_storage_accounting_status(self, state, complete, missing_mask)
    class(dummy_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = same_type_as(self, self)
    select type (typed_state => state)
    type is (dummy_state_t)
      complete = complete .and. ieee_is_finite(typed_state%storage)
    class default
      complete = .false.
    end select
    if (complete) then
      missing_mask = TX_MASS_MISSING_NONE
    else
      missing_mask = int(z'20', int64)
    end if
  end subroutine dummy_storage_accounting_status

  subroutine dummy_gw_capture(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    self%capture_count = self%capture_count + 1
    service_id = self%service_id_value
    lineage_id = self%lineage_id_value
    origin_revision = self%revision
    origin_time = self%current_time
    token = self%revision + 1_int64
    status = GW_EXCHANGE_OK
  end subroutine dummy_gw_capture

  subroutine dummy_gw_trial(self, checkpoint_token, window, q_groundwater_m_per_s, candidate_token, h_groundwater_m, status)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: attempted_trial

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    attempted_trial = self%trial_count + 1
    if (checkpoint_token <= 0_int64 .or. .not. window%valid() .or. .not. ieee_is_finite(q_groundwater_m_per_s)) then
      status = GW_EXCHANGE_BACKEND_REJECTED
      return
    end if
    if (self%fail_trial_number == attempted_trial) then
      status = GW_EXCHANGE_BACKEND_REJECTED
      return
    end if

    self%trial_count = attempted_trial
    self%last_q_groundwater_m_per_s = q_groundwater_m_per_s
    self%pending_t1 = window%t1
    candidate_token = 100_int64 + int(self%trial_count, int64)
    self%last_candidate_token = candidate_token
    if (self%trial_count == 1) then
      h_groundwater_m = 0.5_real64
    else if (self%response_mode == 1) then
      h_groundwater_m = 0.7_real64
    else
      h_groundwater_m = 0.5_real64
    end if
    status = GW_EXCHANGE_OK
  end subroutine dummy_gw_trial

  subroutine dummy_gw_commit(self, checkpoint_token, candidate_token, status)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status

    status = GW_EXCHANGE_BACKEND_REJECTED
    if (checkpoint_token <= 0_int64 .or. candidate_token /= self%last_candidate_token) return
    self%revision = self%revision + 1_int64
    self%current_time = self%pending_t1
    self%commit_count = self%commit_count + 1
    status = GW_EXCHANGE_OK
  end subroutine dummy_gw_commit

  subroutine dummy_gw_discard(self, candidate_token, status)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status

    status = GW_EXCHANGE_BACKEND_REJECTED
    if (candidate_token <= 0_int64) return
    self%discard_count = self%discard_count + 1
    status = GW_EXCHANGE_OK
  end subroutine dummy_gw_discard

  subroutine dummy_gw_prepare(self, checkpoint_token, candidate_token, prepare_token, status)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status

    prepare_token = 0_int64
    status = GW_EXCHANGE_BACKEND_REJECTED
    if (self%fail_prepare) return
    if (checkpoint_token <= 0_int64 .or. candidate_token /= self%last_candidate_token) return
    self%prepare_count = self%prepare_count + 1
    prepare_token = 1000_int64 + candidate_token
    status = GW_EXCHANGE_OK
  end subroutine dummy_gw_prepare

  subroutine dummy_gw_commit_prepared(self, prepare_token)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (prepare_token <= 0_int64) error stop 'dummy groundwater invalid prepared token'
    self%revision = self%revision + 1_int64
    self%current_time = self%pending_t1
    self%commit_count = self%commit_count + 1
  end subroutine dummy_gw_commit_prepared

  subroutine dummy_gw_abort_prepared(self, prepare_token)
    class(dummy_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (prepare_token <= 0_int64) error stop 'dummy groundwater invalid abort token'
    self%abort_count = self%abort_count + 1
  end subroutine dummy_gw_abort_prepared

  subroutine check(condition, message, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A)') 'FAIL: '//trim(message)
    end if
  end subroutine check

  subroutine check_close(actual, expected, tolerance, message, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    integer, intent(inout) :: failures

    call check(ieee_is_finite(actual) .and. abs(actual-expected) <= tolerance, message, failures)
  end subroutine check_close

end program test_fgc21_restricted_predictor_corrector_window
