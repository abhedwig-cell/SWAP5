module mod_fvq97_external_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_external_gateway, only: external_groundwater_backend_t, GW_EXTERNAL_BACKEND_OK
  implicit none
  private

  real(real64), parameter, public :: FVQ97_T0 = 123.375_real64
  real(real64), parameter, public :: FVQ97_T1 = 123.625_real64

  type, extends(external_groundwater_backend_t), public :: fvq97_backend_t
    integer(int64) :: cell_id(2) = [7001_int64, 7002_int64]
    integer(int64) :: lineage_id(2) = [8101_int64, 8102_int64]
    integer(int64) :: revision(2) = [0_int64, 0_int64]
    real(real64) :: current_time(2) = [FVQ97_T0, FVQ97_T0]
    real(real64) :: pending_t1(2) = [FVQ97_T0, FVQ97_T0]
    integer :: capture_count(2) = [0, 0]
    integer :: trial_attempts(2) = [0, 0]
    integer :: trial_successes(2) = [0, 0]
    integer :: discard_count(2) = [0, 0]
    integer :: prepare_count(2) = [0, 0]
    integer :: commit_count(2) = [0, 0]
    integer :: abort_count(2) = [0, 0]
    integer(int64) :: last_candidate(2) = [0_int64, 0_int64]
    integer(int64) :: prepared_token(2) = [0_int64, 0_int64]
    real(real64) :: last_flux_native(2) = [0.0_real64, 0.0_real64]
    integer :: fail_trial_slot = 0
    integer :: fail_trial_ordinal = 0
  contains
    procedure :: capture => fvq97_capture
    procedure :: trial => fvq97_trial
    procedure :: commit_candidate => fvq97_commit_candidate
    procedure :: discard_candidate => fvq97_discard_candidate
    procedure :: prepare => fvq97_prepare
    procedure :: commit_prepared => fvq97_commit_prepared
    procedure :: abort_prepared => fvq97_abort_prepared
    procedure :: slot_for => fvq97_slot_for
  end type fvq97_backend_t

contains

  integer function fvq97_slot_for(self, requested_cell_id) result(slot)
    class(fvq97_backend_t), intent(in) :: self
    integer(int64), intent(in) :: requested_cell_id
    integer :: i

    slot = 0
    do i = 1, size(self%cell_id)
      if (self%cell_id(i) == requested_cell_id) then
        slot = i
        return
      end if
    end do
  end function fvq97_slot_for

  subroutine fvq97_capture(self, cell_id, lineage_id, origin_revision, origin_time, checkpoint_token, status)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id
    integer(int64), intent(out) :: lineage_id, origin_revision, checkpoint_token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    integer :: slot

    lineage_id = 0_int64
    origin_revision = -1_int64
    checkpoint_token = 0_int64
    origin_time = 0.0_real64
    status = 97
    slot = self%slot_for(cell_id)
    if (slot == 0) return

    self%capture_count(slot) = self%capture_count(slot) + 1
    lineage_id = self%lineage_id(slot)
    origin_revision = self%revision(slot)
    origin_time = self%current_time(slot)
    checkpoint_token = 10000_int64 * int(slot, int64) + self%revision(slot) + 1_int64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine fvq97_capture

  subroutine fvq97_trial(self, cell_id, checkpoint_token, t0, t1, flux_native, candidate_token, head_native, status)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token
    real(real64), intent(in) :: t0, t1, flux_native
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: head_native
    integer, intent(out) :: status
    integer :: slot, attempt
    integer(int64) :: expected_checkpoint

    candidate_token = 0_int64
    head_native = 0.0_real64
    status = 98
    slot = self%slot_for(cell_id)
    if (slot == 0) return
    expected_checkpoint = 10000_int64 * int(slot, int64) + self%revision(slot) + 1_int64
    if (checkpoint_token /= expected_checkpoint) return
    if (t1 <= t0) return

    self%trial_attempts(slot) = self%trial_attempts(slot) + 1
    attempt = self%trial_attempts(slot)
    if (slot == self%fail_trial_slot .and. attempt == self%fail_trial_ordinal) return

    self%trial_successes(slot) = self%trial_successes(slot) + 1
    self%last_flux_native(slot) = flux_native
    self%pending_t1(slot) = t1
    candidate_token = 100000_int64 * int(slot, int64) + int(attempt, int64)
    self%last_candidate(slot) = candidate_token
    ! With zero=-1.5 m and scale=0.25 m/native, native head 8 gives +0.5 m.
    head_native = 8.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine fvq97_trial

  subroutine fvq97_commit_candidate(self, cell_id, checkpoint_token, candidate_token, status)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: slot
    integer(int64) :: expected_checkpoint

    status = 99
    slot = self%slot_for(cell_id)
    if (slot == 0) return
    expected_checkpoint = 10000_int64 * int(slot, int64) + self%revision(slot) + 1_int64
    if (checkpoint_token /= expected_checkpoint) return
    if (candidate_token /= self%last_candidate(slot)) return
    self%revision(slot) = self%revision(slot) + 1_int64
    self%current_time(slot) = self%pending_t1(slot)
    self%commit_count(slot) = self%commit_count(slot) + 1
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine fvq97_commit_candidate

  subroutine fvq97_discard_candidate(self, cell_id, candidate_token, status)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, candidate_token
    integer, intent(out) :: status
    integer :: slot

    status = 100
    slot = self%slot_for(cell_id)
    if (slot == 0 .or. candidate_token <= 0_int64) return
    self%discard_count(slot) = self%discard_count(slot) + 1
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine fvq97_discard_candidate

  subroutine fvq97_prepare(self, cell_id, checkpoint_token, candidate_token, prepare_token, status)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    integer :: slot
    integer(int64) :: expected_checkpoint

    prepare_token = 0_int64
    status = 101
    slot = self%slot_for(cell_id)
    if (slot == 0) return
    expected_checkpoint = 10000_int64 * int(slot, int64) + self%revision(slot) + 1_int64
    if (checkpoint_token /= expected_checkpoint) return
    if (candidate_token /= self%last_candidate(slot)) return
    self%prepare_count(slot) = self%prepare_count(slot) + 1
    prepare_token = candidate_token + 500000_int64
    self%prepared_token(slot) = prepare_token
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine fvq97_prepare

  subroutine fvq97_commit_prepared(self, cell_id, prepare_token)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: slot

    slot = self%slot_for(cell_id)
    if (slot == 0) error stop 'FVQ97 invalid commit cell'
    if (prepare_token <= 0_int64 .or. prepare_token /= self%prepared_token(slot)) &
         error stop 'FVQ97 invalid prepared token'
    self%revision(slot) = self%revision(slot) + 1_int64
    self%current_time(slot) = self%pending_t1(slot)
    self%commit_count(slot) = self%commit_count(slot) + 1
    self%prepared_token(slot) = 0_int64
  end subroutine fvq97_commit_prepared

  subroutine fvq97_abort_prepared(self, cell_id, prepare_token)
    class(fvq97_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: slot

    slot = self%slot_for(cell_id)
    if (slot == 0) error stop 'FVQ97 invalid abort cell'
    if (prepare_token <= 0_int64 .or. prepare_token /= self%prepared_token(slot)) &
         error stop 'FVQ97 invalid abort token'
    self%abort_count(slot) = self%abort_count(slot) + 1
    self%prepared_token(slot) = 0_int64
  end subroutine fvq97_abort_prepared

end module mod_fvq97_external_backend

program test_fvq97_fgc27_restricted_direct_groundwater_e2e
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD
  use mod_groundwater_accuracy_binding, only: groundwater_accuracy_binding_receipt_t, bind_groundwater_head_accuracy, &
       GW_ACCURACY_BIND_OK
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK, GW_PC_CORRECTOR_GROUNDWATER_FAILED
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, GW_MULTI_OK
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_groundwater_external_gateway, only: groundwater_external_gateway_t, groundwater_external_gateway_config_t, &
       GW_EXTERNAL_GATEWAY_OK
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_model_t, &
       dummy_parameters_t, dummy_materializer_t
  use mod_fvq97_external_backend, only: fvq97_backend_t, FVQ97_T0, FVQ97_T1
  implicit none

  integer :: failures

  failures = 0
  call test_direct_gateway_success(failures)
  call test_direct_gateway_failure_rolls_back(failures)
  call test_multiswap_two_cells_shared_backend(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ97_FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'FVQ97_FGC22_POLICY_BINDING_IN_EXECUTION=PASS'
  write(*,'(A)') 'FVQ97_DIRECT_GC21_GC26_E2E=PASS'
  write(*,'(A)') 'FVQ97_EXTERNAL_FAILURE_FAILS_CLOSED=PASS'
  write(*,'(A)') 'FVQ97_NO_SAME_WINDOW_RETRY=PASS'
  write(*,'(A)') 'FVQ97_MULTISWAP_GC20_GC25_GC26_E2E=PASS'
  write(*,'(A)') 'FVQ97_SHARED_BACKEND_NO_CROSSTALK_E2E=PASS'
  write(*,'(A)') 'FVQ97_INDEPENDENT_E2E_ORACLE=PASS'

contains

  subroutine require(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FVQ97_ASSERT_FAIL=', trim(label)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call require(abs(actual - expected) <= tolerance, label, failures)
  end subroutine require_close

  subroutine configure_accuracy(policy, numerical, ready, status)
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(canonical_numerical_config_t), intent(out) :: numerical
    logical, intent(out) :: ready
    integer, intent(out) :: status
    type(coupling_application_accuracy_contract_t) :: accuracy
    type(groundwater_accuracy_binding_receipt_t) :: receipt
    logical :: temporal_materialized

    accuracy = coupling_application_accuracy_contract_t()
    accuracy%contract_id = 9101_int64
    accuracy%contract_version = 1
    accuracy%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD
    accuracy%h_app_available = .true.
    accuracy%h_app_cm = 2.0_real64
    accuracy%h_app_externally_qualified = .true.
    accuracy%application_provenance_id = 9102_int64
    accuracy%a_temporal_available = .true.
    accuracy%a_temporal = 0.25_real64
    accuracy%a_temporal_externally_qualified = .true.
    accuracy%temporal_allocation_provenance_id = 9103_int64

    call bind_groundwater_head_accuracy(accuracy, 9201_int64, 1, 9202_int64, 0.5_real64, &
         policy, receipt, status)
    numerical = canonical_numerical_config_t()
    call accuracy%materialize_model_temporal_budget(numerical, temporal_materialized)
    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%temporal_tolerance = 1.0e-12_real64
    numerical%transaction%mass_tolerance = 1.0e-12_real64
    numerical%transaction%retry_scale = 0.5_real64
    numerical%transaction%max_retries = 2
    numerical%max_committed_substeps = 4
    numerical%progress_tolerance = 0.0_real64
    ready = status == GW_ACCURACY_BIND_OK .and. receipt%ready() .and. temporal_materialized
  end subroutine configure_accuracy

  subroutine bind_gateway(slot, backend, gateway, config, status)
    integer, intent(in) :: slot
    type(fvq97_backend_t), target, intent(inout) :: backend
    type(groundwater_external_gateway_t), intent(out) :: gateway
    type(groundwater_external_gateway_config_t), intent(out) :: config
    integer, intent(out) :: status

    config = groundwater_external_gateway_config_t()
    config%service_id = 7100_int64 + int(slot, int64)
    config%cell_id = backend%cell_id(slot)
    config%head_native_to_m_scale = 0.25_real64
    config%head_native_zero_m = -1.5_real64
    config%flux_native_to_m_per_s_scale = 2.0e-8_real64
    config%native_flux_sign_relative_to_groundwater = -1
    call gateway%bind(backend, config, status)
  end subroutine bind_gateway

  subroutine setup_direct(slot, backend, executor, model, parameters, materializer, gateway, config, ledger, datum, &
       policy, window, origin, numerical, committed, accuracy_ready, status)
    integer, intent(in) :: slot
    type(fvq97_backend_t), target, intent(inout) :: backend
    type(kernel_executor_t), intent(out) :: executor
    type(dummy_model_t), target, intent(out) :: model
    type(dummy_parameters_t), intent(out) :: parameters
    type(dummy_materializer_t), intent(out) :: materializer
    type(groundwater_external_gateway_t), intent(out) :: gateway
    type(groundwater_external_gateway_config_t), intent(out) :: config
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledger
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_coupling_origin_t), intent(out) :: origin
    type(canonical_numerical_config_t), intent(out) :: numerical
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: accuracy_ready
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    integer :: bind_status, ledger_status, accuracy_status
    integer(int64) :: swap_lineage

    executor = kernel_executor_t()
    model = dummy_model_t()
    parameters = dummy_parameters_t()
    materializer = dummy_materializer_t()
    ledger = groundwater_interface_mass_ledger_t()
    datum = groundwater_head_datum_t()
    window = groundwater_coupling_window_t()
    origin = groundwater_coupling_origin_t()
    committed = kernel_committed_state_t()
    call executor%bind_model(model)

    swap_lineage = 900_int64 + int(slot, int64)
    allocate(dummy_state_t :: initial_state)
    select type (typed_initial => initial_state)
    type is (dummy_state_t)
      typed_initial%storage = 10.0_real64
    end select
    call committed%initialize(swap_lineage, initial_state, initialized, initial_time=FVQ97_T0)
    deallocate(initial_state)
    if (.not. initialized) then
      status = -201
      accuracy_ready = .false.
      return
    end if

    call ledger%bind_identity(1000_int64 + int(slot, int64), ledger_status)
    if (ledger_status /= GW_MASS_LEDGER_OK) then
      status = ledger_status
      accuracy_ready = .false.
      return
    end if

    call bind_gateway(slot, backend, gateway, config, bind_status)
    if (bind_status /= GW_EXTERNAL_GATEWAY_OK) then
      status = bind_status
      accuracy_ready = .false.
      return
    end if

    datum%available = .true.
    datum%datum_id = 501_int64
    datum%bottom_boundary_elevation_m = -2.0_real64
    window%t0 = FVQ97_T0
    window%t1 = FVQ97_T1
    call configure_accuracy(policy, numerical, accuracy_ready, accuracy_status)
    if (.not. accuracy_ready) then
      status = accuracy_status
      return
    end if

    origin%initialized = .true.
    origin%coupling_id = 10001_int64 + int(slot, int64)
    origin%accepted_h_groundwater_m = 0.4_real64
    origin%accepted_time = FVQ97_T0
    origin%swap_lineage_id = swap_lineage
    origin%swap_revision = 0_int64
    origin%groundwater_service_id = config%service_id
    origin%groundwater_lineage_id = backend%lineage_id(slot)
    origin%groundwater_revision = 0_int64
    status = 0
  end subroutine setup_direct

  subroutine test_direct_gateway_success(failures)
    integer, intent(inout) :: failures
    type(fvq97_backend_t), target :: backend
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(groundwater_external_gateway_t) :: gateway
    type(groundwater_external_gateway_config_t) :: config
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_pc_result_t) :: result
    logical :: accuracy_ready
    integer :: status
    real(real64) :: reconstructed_q

    backend = fvq97_backend_t()
    call setup_direct(1, backend, executor, model, parameters, materializer, gateway, config, ledger, datum, &
         policy, window, origin, numerical, committed, accuracy_ready, status)
    call require(status == 0 .and. accuracy_ready, 'direct success setup and F-GC22 binding', failures)

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         gateway, ledger, datum, policy, window, origin, result)

    call require(result%status == GW_PC_OK .and. result%completed .and. result%committed, &
         'direct success status and commit', failures)
    call require(.not. result%request_smaller_window, 'direct success no shrink', failures)
    call require(model%advance_count == 2, 'direct success predictor plus one corrector only', failures)
    call require(backend%trial_attempts(1) == 2 .and. backend%trial_successes(1) == 2, &
         'direct success exactly two external trials', failures)
    call require(backend%discard_count(1) == 1 .and. backend%prepare_count(1) == 1 .and. &
         backend%commit_count(1) == 1, 'direct success transaction publication counts', failures)
    call require(backend%revision(1) == 1_int64, 'direct success backend revision once', failures)
    call require_close(backend%current_time(1), FVQ97_T1, 1.0e-14_real64, &
         'direct success backend time', failures)
    call require_close(result%corrector_h_groundwater_m, 0.5_real64, 1.0e-15_real64, &
         'direct success explicit datum conversion', failures)
    call require(transfer(result%corrector_q_groundwater_m_per_s, 0_int64) == &
         transfer(-result%corrector_q_swap_m_per_s, 0_int64), 'direct success exact action reaction', failures)
    call require(transfer(result%residual%flux_residual_m_per_s, 0_int64) == transfer(0.0_real64, 0_int64), &
         'direct success exact zero flux residual', failures)
    reconstructed_q = backend%last_flux_native(1) * config%flux_native_to_m_per_s_scale / &
         real(config%native_flux_sign_relative_to_groundwater, real64)
    call require_close(reconstructed_q, result%corrector_q_groundwater_m_per_s, 1.0e-20_real64, &
         'direct success native flux sign and unit roundtrip', failures)
    call require(committed%current_revision() == 1_int64 .and. origin%swap_revision == 1_int64 .and. &
         origin%groundwater_revision == 1_int64, 'direct success coupled provenance advanced once', failures)
  end subroutine test_direct_gateway_success

  subroutine test_direct_gateway_failure_rolls_back(failures)
    integer, intent(inout) :: failures
    type(fvq97_backend_t), target :: backend
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(groundwater_external_gateway_t) :: gateway
    type(groundwater_external_gateway_config_t) :: config
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_pc_result_t) :: result
    logical :: accuracy_ready
    integer :: status
    real(real64) :: storage
    logical :: storage_available

    backend = fvq97_backend_t()
    call setup_direct(1, backend, executor, model, parameters, materializer, gateway, config, ledger, datum, &
         policy, window, origin, numerical, committed, accuracy_ready, status)
    call require(status == 0 .and. accuracy_ready, 'direct failure setup', failures)
    backend%fail_trial_slot = 1
    backend%fail_trial_ordinal = 2

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         gateway, ledger, datum, policy, window, origin, result)

    call require(result%status == GW_PC_CORRECTOR_GROUNDWATER_FAILED, &
         'direct failure explicit corrector groundwater status', failures)
    call require(result%request_smaller_window .and. .not. result%committed, &
         'direct failure asks outer shrink and does not commit', failures)
    call require(model%advance_count == 2 .and. backend%trial_attempts(1) == 2, &
         'direct failure has no same-window retry', failures)
    call require(backend%revision(1) == 0_int64 .and. backend%commit_count(1) == 0, &
         'direct failure backend committed state unchanged', failures)
    call require(committed%current_revision() == 0_int64 .and. origin%swap_revision == 0_int64 .and. &
         origin%groundwater_revision == 0_int64, 'direct failure provenance unchanged', failures)
    call get_committed_storage(committed, storage, storage_available)
    call require(storage_available, 'direct failure committed storage available', failures)
    call require_close(storage, 10.0_real64, 1.0e-14_real64, &
         'direct failure committed physical state unchanged', failures)
    call require(gateway%restart_quiescent(), 'direct failure leaves gateway quiescent', failures)
  end subroutine test_direct_gateway_failure_rolls_back

  subroutine setup_multiswap_case(slot, backend, executor, model, parameters, materializer, gateway, config, ledgers, &
       datum, policy, window, origins, numerical, committed, bindings, accuracy_ready, status)
    integer, intent(in) :: slot
    type(fvq97_backend_t), target, intent(inout) :: backend
    type(kernel_executor_t), intent(out) :: executor
    type(dummy_model_t), target, intent(out) :: model
    type(dummy_parameters_t), intent(out) :: parameters(2)
    type(dummy_materializer_t), intent(out) :: materializer
    type(groundwater_external_gateway_t), intent(out) :: gateway
    type(groundwater_external_gateway_config_t), intent(out) :: config
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledgers(2)
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_coupling_origin_t), intent(out) :: origins(2)
    type(canonical_numerical_config_t), intent(out) :: numerical
    type(kernel_committed_state_t), intent(out) :: committed(2)
    type(groundwater_direct_tile_binding_t), intent(out) :: bindings(2)
    logical, intent(out) :: accuracy_ready
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    integer :: i, ledger_status, bind_status, accuracy_status
    integer(int64) :: swap_lineage

    executor = kernel_executor_t()
    model = dummy_model_t()
    materializer = dummy_materializer_t()
    datum = groundwater_head_datum_t()
    window = groundwater_coupling_window_t()
    call executor%bind_model(model)
    call bind_gateway(slot, backend, gateway, config, bind_status)
    if (bind_status /= GW_EXTERNAL_GATEWAY_OK) then
      status = bind_status
      accuracy_ready = .false.
      return
    end if

    do i = 1, 2
      parameters(i) = dummy_parameters_t()
      committed(i) = kernel_committed_state_t()
      swap_lineage = 900_int64 + 10_int64 * int(slot-1, int64) + int(i, int64)
      allocate(dummy_state_t :: initial_state)
      select type (typed_initial => initial_state)
      type is (dummy_state_t)
        typed_initial%storage = 10.0_real64 + real(i-1, real64)
      end select
      call committed(i)%initialize(swap_lineage, initial_state, initialized, initial_time=FVQ97_T0)
      deallocate(initial_state)
      if (.not. initialized) then
        status = -301
        accuracy_ready = .false.
        return
      end if
      ledgers(i) = groundwater_interface_mass_ledger_t()
      call ledgers(i)%bind_identity(2000_int64 + 10_int64 * int(slot, int64) + int(i, int64), ledger_status)
      if (ledger_status /= GW_MASS_LEDGER_OK) then
        status = ledger_status
        accuracy_ready = .false.
        return
      end if
      origins(i) = groundwater_coupling_origin_t()
      origins(i)%initialized = .true.
      origins(i)%coupling_id = 11000_int64 + int(slot, int64)
      origins(i)%accepted_h_groundwater_m = 0.4_real64
      origins(i)%accepted_time = FVQ97_T0
      origins(i)%swap_lineage_id = swap_lineage
      origins(i)%swap_revision = 0_int64
      origins(i)%groundwater_service_id = config%service_id
      origins(i)%groundwater_lineage_id = backend%lineage_id(slot)
      origins(i)%groundwater_revision = 0_int64
      bindings(i)%groundwater_cell_id = config%cell_id
      bindings(i)%tile_id = 100_int64 * int(slot, int64) + int(i, int64)
    end do
    bindings(1)%area_fraction = 0.25_real64
    bindings(2)%area_fraction = 0.75_real64

    datum%available = .true.
    datum%datum_id = 501_int64
    datum%bottom_boundary_elevation_m = -2.0_real64
    window%t0 = FVQ97_T0
    window%t1 = FVQ97_T1
    call configure_accuracy(policy, numerical, accuracy_ready, accuracy_status)
    if (.not. accuracy_ready) then
      status = accuracy_status
      return
    end if
    status = 0
  end subroutine setup_multiswap_case

  subroutine test_multiswap_two_cells_shared_backend(failures)
    integer, intent(inout) :: failures
    type(fvq97_backend_t), target :: backend
    type(kernel_executor_t) :: executor1, executor2
    type(kernel_committed_state_t) :: committed1(2), committed2(2)
    type(dummy_model_t), target :: model1, model2
    type(dummy_parameters_t) :: parameters1(2), parameters2(2)
    type(dummy_materializer_t) :: materializer1, materializer2
    type(groundwater_external_gateway_t) :: gateway1, gateway2
    type(groundwater_external_gateway_config_t) :: config1, config2
    type(groundwater_interface_mass_ledger_t) :: ledgers1(2), ledgers2(2)
    type(groundwater_head_datum_t) :: datum1, datum2
    type(groundwater_head_convergence_policy_t) :: policy1, policy2
    type(groundwater_coupling_window_t) :: window1, window2
    type(groundwater_coupling_origin_t) :: origins1(2), origins2(2)
    type(canonical_numerical_config_t) :: numerical1, numerical2
    type(groundwater_direct_tile_binding_t) :: bindings1(2), bindings2(2)
    type(groundwater_multiswap_result_t) :: result1, result2
    logical :: ready1, ready2
    integer :: status1, status2
    integer(int64) :: cell1_revision_after_first

    backend = fvq97_backend_t()
    call setup_multiswap_case(1, backend, executor1, model1, parameters1, materializer1, gateway1, config1, ledgers1, &
         datum1, policy1, window1, origins1, numerical1, committed1, bindings1, ready1, status1)
    call require(status1 == 0 .and. ready1, 'multiswap cell1 setup', failures)
    call run_restricted_groundwater_multiswap_cell_window(executor1, parameters1, committed1, bindings1, &
         materializer1, numerical1, gateway1, ledgers1, datum1, policy1, window1, origins1, result1)

    call require(result1%status == GW_MULTI_OK .and. result1%committed, 'multiswap cell1 committed', failures)
    call require(model1%advance_count == 4 .and. backend%trial_attempts(1) == 2, &
         'multiswap cell1 predictor plus corrector for two tiles', failures)
    call require(size(result1%tile_weighted_exchange_m) == 2, 'multiswap weighted outputs present', failures)
    if (allocated(result1%tile_weighted_exchange_m)) then
      call require_close(sum(result1%tile_weighted_exchange_m), result1%accepted_cell_exchange_m, 1.0e-15_real64, &
           'multiswap area weighted aggregate is production result', failures)
      call require_close(result1%tile_weighted_exchange_m(2), 3.0_real64 * result1%tile_weighted_exchange_m(1), &
           1.0e-15_real64, 'multiswap 0.25/0.75 weighting ratio', failures)
    end if
    call require(transfer(result1%residual%flux_residual_m_per_s, 0_int64) == transfer(0.0_real64, 0_int64), &
         'multiswap exact action reaction residual', failures)
    call require(committed1(1)%current_revision() == 1_int64 .and. committed1(2)%current_revision() == 1_int64, &
         'multiswap all tiles committed once', failures)
    cell1_revision_after_first = backend%revision(1)

    call setup_multiswap_case(2, backend, executor2, model2, parameters2, materializer2, gateway2, config2, ledgers2, &
         datum2, policy2, window2, origins2, numerical2, committed2, bindings2, ready2, status2)
    call require(status2 == 0 .and. ready2, 'multiswap cell2 setup on shared backend', failures)
    call run_restricted_groundwater_multiswap_cell_window(executor2, parameters2, committed2, bindings2, &
         materializer2, numerical2, gateway2, ledgers2, datum2, policy2, window2, origins2, result2)

    call require(result2%status == GW_MULTI_OK .and. result2%committed, 'multiswap cell2 committed', failures)
    call require(backend%revision(1) == cell1_revision_after_first, &
         'shared backend cell2 does not mutate cell1 revision', failures)
    call require(backend%revision(2) == 1_int64 .and. backend%commit_count(2) == 1, &
         'shared backend cell2 commits independently', failures)
    call require(backend%capture_count(1) == 1 .and. backend%capture_count(2) == 1, &
         'shared backend capture isolation', failures)
    call require(config1%service_id /= config2%service_id .and. config1%cell_id /= config2%cell_id, &
         'shared backend gateways independently configured', failures)
  end subroutine test_multiswap_two_cells_shared_backend

  subroutine get_committed_storage(committed, storage, available)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: storage
    logical, intent(out) :: available
    class(transaction_state_t), allocatable :: snapshot

    storage = 0.0_real64
    call committed%snapshot(snapshot, available)
    if (.not. available) return
    select type (typed_snapshot => snapshot)
    type is (dummy_state_t)
      storage = typed_snapshot%storage
    class default
      available = .false.
    end select
  end subroutine get_committed_storage

end program test_fvq97_fgc27_restricted_direct_groundwater_e2e
