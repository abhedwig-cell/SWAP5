module mod_fgc24_coupled_restart_test
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_lineage_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_prepare_candidate, &
       groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK
  use mod_groundwater_coupled_restart, only: groundwater_restart_state_t, groundwater_restart_adapter_t, &
       groundwater_coupled_restart_record_t, export_groundwater_coupled_restart, restore_groundwater_coupled_restart, &
       GW_COUPLED_RESTART_OK, GW_COUPLED_RESTART_LEDGER_REJECTED, GW_COUPLED_RESTART_PROVENANCE_MISMATCH, &
       GW_COUPLED_RESTART_SERVICE_NOT_QUIESCENT
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_parameters_t, dummy_model_t, &
       dummy_materializer_t, dummy_groundwater_service_t, setup_common
  implicit none

  integer(int64), parameter :: SWAP_LAYOUT_ID = 2401_int64

  type, extends(groundwater_restart_state_t) :: dummy_groundwater_restart_state_t
    integer(int64) :: service_id = 0_int64
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = -1_int64
    real(real64) :: committed_time = 0.0_real64
    integer :: trial_count = 0
    integer :: response_mode = 0
  contains
    procedure :: clone => dummy_restart_state_clone
    procedure :: valid => dummy_restart_state_valid
  end type dummy_groundwater_restart_state_t

  type, extends(groundwater_restart_adapter_t) :: dummy_groundwater_restart_adapter_t
    type(dummy_groundwater_service_t), pointer :: target => null()
    logical :: fail_restore = .false.
    logical :: violate_success_postcondition = .false.
    integer :: restore_calls = 0
  contains
    procedure :: export_committed => dummy_restart_export
    procedure :: restore_committed => dummy_restart_restore
  end type dummy_groundwater_restart_adapter_t

contains

  subroutine run_mode(mode, path1, path2)
    character(len=*), intent(in) :: mode, path1, path2

    select case (trim(mode))
    case ('continuous')
      call run_continuous(path1)
    case ('export')
      call run_export(path1)
    case ('restore')
      call run_restore(path1, path2)
    case ('selftest')
      call run_selftest()
    case ('postcondition-violation')
      call run_postcondition_violation()
    case default
      error stop 'F-GC24 unknown test mode'
    end select
  end subroutine run_mode

  subroutine run_continuous(signature_path)
    character(len=*), intent(in) :: signature_path
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(canonical_numerical_config_t) :: numerical
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'continuous setup')
    call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
         window, origin)
    call advance_window(window)
    call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
         window, origin)
    call write_signature(signature_path, committed, groundwater, ledger, origin)
  end subroutine run_continuous

  subroutine run_export(restart_path)
    character(len=*), intent(in) :: restart_path
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater
    type(dummy_groundwater_restart_adapter_t) :: restart_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_coupled_restart_record_t) :: record
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized, exported
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'export setup')
    call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
         window, origin)

    restart_adapter%target => groundwater
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, restart_adapter, ledger, origin, &
         record, exported, status)
    call require(exported .and. status == GW_COUPLED_RESTART_OK, 'coupled export')
    call write_restart_record(restart_path, record)
  end subroutine run_export

  subroutine run_restore(restart_path, signature_path)
    character(len=*), intent(in) :: restart_path, signature_path
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater
    type(dummy_groundwater_restart_adapter_t) :: restart_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_coupled_restart_record_t) :: record
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized, restored
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'restore configuration setup')

    ! Simulate a genuinely fresh process composition. Numerical configuration,
    ! immutable parameters and model binding are reconstructed configuration;
    ! all authoritative coupled continuation objects start empty.
    committed = kernel_committed_state_t()
    groundwater = dummy_groundwater_service_t()
    ledger = groundwater_interface_mass_ledger_t()
    origin = groundwater_coupling_origin_t()

    call read_restart_record(restart_path, record)
    restart_adapter%target => groundwater
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, committed, groundwater, restart_adapter, &
         ledger, origin, restored, status)
    call require(restored .and. status == GW_COUPLED_RESTART_OK, 'coupled restore')
    call require(groundwater%last_candidate_token == 0_int64, 'candidate token did not cross process boundary')
    call require(groundwater%pending_t1 == 0.0_real64, 'pending candidate time did not cross process boundary')

    window%t0 = record%accepted_time
    window%t1 = record%accepted_time + 0.25_real64
    call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
         window, origin)
    call write_signature(signature_path, committed, groundwater, ledger, origin)
  end subroutine run_restore

  subroutine run_postcondition_violation()
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed, fresh_committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater, fresh_groundwater
    type(dummy_groundwater_restart_adapter_t) :: source_adapter, violating_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger, fresh_ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin, fresh_origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_coupled_restart_record_t) :: record
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized, exported, restored
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'postcondition setup')
    call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
         window, origin)
    source_adapter%target => groundwater
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, source_adapter, ledger, origin, &
         record, exported, status)
    call require(exported .and. status == GW_COUPLED_RESTART_OK, 'postcondition source export')

    fresh_committed = kernel_committed_state_t()
    fresh_groundwater = dummy_groundwater_service_t()
    fresh_ledger = groundwater_interface_mass_ledger_t()
    fresh_origin = groundwater_coupling_origin_t()
    violating_adapter%target => fresh_groundwater
    violating_adapter%violate_success_postcondition = .true.

    ! This call must terminate fail-hard inside groundwater restore after the
    ! adapter has returned success but before local SWAP/ledger/origin publication.
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         violating_adapter, fresh_ledger, fresh_origin, restored, status)
    error stop 'F-GC24 FAIL: successful adapter postcondition violation returned recoverably'
  end subroutine run_postcondition_violation

  subroutine run_selftest()
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed, fresh_committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_groundwater_service_t), target :: groundwater, fresh_groundwater
    type(dummy_groundwater_restart_adapter_t) :: restart_adapter, fresh_restart_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger, fresh_ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin, fresh_origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_coupled_restart_record_t) :: record, bad_record
    type(groundwater_interface_lineage_t) :: lineage
    type(groundwater_exchange_checkpoint_t) :: transient_checkpoint
    type(groundwater_exchange_candidate_t) :: transient_candidate
    type(groundwater_exchange_prepared_t) :: transient_prepared
    type(groundwater_exchange_trial_result_t) :: transient_result
    class(transaction_state_t), allocatable :: initial_state
    type(groundwater_interface_mass_snapshot_t) :: snap
    logical :: initialized, exported, restored
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'selftest setup')
    restart_adapter%target => groundwater

    call require(groundwater%restart_quiescent(), 'fresh preparable service quiescent')
    call groundwater_capture_checkpoint(groundwater, transient_checkpoint, status)
    call require(status == GW_EXCHANGE_OK .and. transient_checkpoint%ready(), 'quiescence capture')
    call groundwater_trial_from_checkpoint(groundwater, transient_checkpoint, window, 0.0_real64, &
         transient_candidate, transient_result, status)
    call require(status == GW_EXCHANGE_OK .and. transient_candidate%ready(), 'quiescence trial')
    call groundwater_prepare_candidate(groundwater, transient_checkpoint, transient_candidate, transient_prepared, status)
    call require(status == GW_EXCHANGE_OK .and. transient_prepared%ready(), 'quiescence prepare')
    call require(.not. groundwater%restart_quiescent(), 'live prepared reservation is non-quiescent')
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, restart_adapter, ledger, origin, &
         record, exported, status)
    call require(.not. exported .and. status == GW_COUPLED_RESTART_SERVICE_NOT_QUIESCENT, &
         'live prepared reservation rejects restart export')
    call groundwater_abort_prepared(groundwater, transient_checkpoint, transient_prepared, status)
    call require(status == GW_EXCHANGE_OK, 'quiescence abort')
    call require(groundwater%restart_quiescent(), 'aborted prepared reservation restores quiescence')

    lineage%coupling_id = origin%coupling_id
    lineage%swap_lineage_id = origin%swap_lineage_id
    lineage%swap_origin_revision = origin%swap_revision
    lineage%groundwater_lineage_id = origin%groundwater_lineage_id
    lineage%groundwater_origin_revision = origin%groundwater_revision
    lineage%candidate_revision = 1_int64
    call ledger%stage_exchange(window, lineage, 0.001_real64, status)
    call require(status == GW_MASS_LEDGER_OK, 'stage transient ledger exchange')
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, restart_adapter, ledger, origin, &
         record, exported, status)
    call require(.not. exported .and. status == GW_COUPLED_RESTART_LEDGER_REJECTED, &
         'active ledger export fails closed')
    call ledger%discard_trial(status)
    call require(status == GW_MASS_LEDGER_OK, 'discard staged ledger exchange')

    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, restart_adapter, ledger, origin, &
         record, exported, status)
    call require(exported .and. status == GW_COUPLED_RESTART_OK, 'selftest clean export')
    call require(record%ledger%discarded_trial_count == 1, 'discard diagnostic persisted in restart record')

    bad_record = record
    bad_record%origin%swap_revision = bad_record%origin%swap_revision + 1_int64
    fresh_groundwater = dummy_groundwater_service_t()
    fresh_restart_adapter%target => fresh_groundwater
    call restore_groundwater_coupled_restart(bad_record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_restart_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored .and. status == GW_COUPLED_RESTART_PROVENANCE_MISMATCH, &
         'tampered origin rejected before restore')
    call require(fresh_restart_adapter%restore_calls == 0, 'tampered provenance never reaches backend restore')
    call require(.not. fresh_committed%ready() .and. .not. fresh_origin%initialized, &
         'tampered restore leaves SWAP and origin unpublished')
    call fresh_ledger%snapshot(snap)
    call require(.not. snap%identity_bound .and. snap%committed_exchange_count == 0, &
         'tampered restore leaves ledger unpublished')

    fresh_groundwater = dummy_groundwater_service_t()
    fresh_committed = kernel_committed_state_t()
    fresh_ledger = groundwater_interface_mass_ledger_t()
    fresh_origin = groundwater_coupling_origin_t()
    fresh_restart_adapter%target => fresh_groundwater
    fresh_restart_adapter%fail_restore = .true.
    fresh_restart_adapter%restore_calls = 0
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_restart_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored, 'backend restore rejection fails closed')
    call require(.not. fresh_committed%ready() .and. .not. fresh_origin%initialized, &
         'backend rejection leaves SWAP and origin unpublished')
    call fresh_ledger%snapshot(snap)
    call require(.not. snap%identity_bound .and. snap%committed_exchange_count == 0, &
         'backend rejection leaves ledger unpublished')

    write(*,'(A)') 'F-GC24 SELFTEST PASS'
  end subroutine run_selftest

  subroutine run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, &
       policy, window, origin)
    type(kernel_executor_t), intent(inout) :: executor
    type(dummy_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(inout) :: committed
    type(dummy_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(dummy_groundwater_service_t), intent(inout) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_head_convergence_policy_t), intent(in) :: policy
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_coupling_origin_t), intent(inout) :: origin
    type(groundwater_pc_result_t) :: result

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, result)
    call require(result%status == GW_PC_OK .and. result%committed, 'coupling window committed')
    call require(transfer(result%ledger_snapshot%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'coupling window exact interface mass conservation')
  end subroutine run_one_window

  subroutine advance_window(window)
    type(groundwater_coupling_window_t), intent(inout) :: window
    real(real64) :: next_t0

    next_t0 = window%t1
    window%t0 = next_t0
    window%t1 = next_t0 + 0.25_real64
  end subroutine advance_window

  subroutine dummy_restart_state_clone(self, copy)
    class(dummy_groundwater_restart_state_t), intent(in) :: self
    class(groundwater_restart_state_t), allocatable, intent(out) :: copy

    allocate(copy, source=self)
  end subroutine dummy_restart_state_clone

  logical function dummy_restart_state_valid(self) result(valid)
    class(dummy_groundwater_restart_state_t), intent(in) :: self

    valid = self%service_id > 0_int64 .and. self%lineage_id > 0_int64 .and. self%revision >= 0_int64 .and. &
         ieee_is_finite(self%committed_time) .and. self%trial_count >= 0
  end function dummy_restart_state_valid

  subroutine dummy_restart_export(self, service_id, lineage_id, revision, committed_time, state, status)
    class(dummy_groundwater_restart_adapter_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, revision
    real(real64), intent(out) :: committed_time
    class(groundwater_restart_state_t), allocatable, intent(out) :: state
    integer, intent(out) :: status

    service_id = 0_int64
    lineage_id = 0_int64
    revision = -1_int64
    committed_time = 0.0_real64
    status = 1
    if (.not. associated(self%target)) return

    allocate(dummy_groundwater_restart_state_t :: state)
    select type (typed_state => state)
    type is (dummy_groundwater_restart_state_t)
      typed_state%service_id = self%target%service_id_value
      typed_state%lineage_id = self%target%lineage_id_value
      typed_state%revision = self%target%revision
      typed_state%committed_time = self%target%current_time
      typed_state%trial_count = self%target%trial_count
      typed_state%response_mode = self%target%response_mode
      service_id = typed_state%service_id
      lineage_id = typed_state%lineage_id
      revision = typed_state%revision
      committed_time = typed_state%committed_time
      status = 0
    class default
      status = 2
    end select
  end subroutine dummy_restart_export

  subroutine dummy_restart_restore(self, service_id, lineage_id, revision, committed_time, state, status)
    class(dummy_groundwater_restart_adapter_t), intent(inout) :: self
    integer(int64), intent(in) :: service_id, lineage_id, revision
    real(real64), intent(in) :: committed_time
    class(groundwater_restart_state_t), intent(in) :: state
    integer, intent(out) :: status

    status = 1
    self%restore_calls = self%restore_calls + 1
    if (self%fail_restore) return
    if (.not. associated(self%target)) return
    if (self%target%revision /= 0_int64 .or. self%target%trial_count /= 0) return

    select type (typed_state => state)
    type is (dummy_groundwater_restart_state_t)
      if (.not. typed_state%valid()) return
      if (service_id /= typed_state%service_id .or. lineage_id /= typed_state%lineage_id) return
      if (revision /= typed_state%revision) return
      if (transfer(committed_time, 0_int64) /= transfer(typed_state%committed_time, 0_int64)) return
      self%target%service_id_value = service_id
      self%target%lineage_id_value = lineage_id
      self%target%revision = revision
      self%target%current_time = committed_time
      self%target%trial_count = typed_state%trial_count
      self%target%response_mode = typed_state%response_mode
      self%target%pending_t1 = 0.0_real64
      self%target%last_candidate_token = 0_int64
      self%target%last_q_groundwater_m_per_s = 0.0_real64
      if (self%violate_success_postcondition) self%target%current_time = committed_time + 1.0_real64
      status = 0
    class default
      status = 2
    end select
  end subroutine dummy_restart_restore

  subroutine write_restart_record(path, record)
    character(len=*), intent(in) :: path
    type(groundwater_coupled_restart_record_t), intent(in) :: record
    integer :: unit

    open(newunit=unit, file=trim(path), access='stream', form='unformatted', status='replace', action='write')
    write(unit) record%schema_version, record%swap_kernel_schema_version, record%swap_layout_id, &
         record%swap_lineage_id, record%swap_revision, record%accepted_time
    write(unit) record%origin%initialized, record%origin%coupling_id, record%origin%accepted_h_groundwater_m, &
         record%origin%accepted_time, record%origin%swap_lineage_id, record%origin%swap_revision, &
         record%origin%groundwater_service_id, record%origin%groundwater_lineage_id, record%origin%groundwater_revision
    write(unit) record%ledger%schema_version, record%ledger%available, record%ledger%ledger_id, &
         record%ledger%committed_swap_outward_exchange_m, record%ledger%committed_exchange_count, &
         record%ledger%discarded_trial_count, record%ledger%discarded_trial_count_saturated
    write(unit) record%groundwater%schema_version, record%groundwater%service_id, record%groundwater%lineage_id, &
         record%groundwater%revision, record%groundwater%committed_time
    select type (swap_state => record%swap_physical_state)
    type is (dummy_state_t)
      write(unit) swap_state%storage
    class default
      close(unit)
      error stop 'F-GC24 unexpected SWAP restart state type'
    end select
    select type (gw_state => record%groundwater%backend_state)
    type is (dummy_groundwater_restart_state_t)
      write(unit) gw_state%service_id, gw_state%lineage_id, gw_state%revision, gw_state%committed_time, &
           gw_state%trial_count, gw_state%response_mode
    class default
      close(unit)
      error stop 'F-GC24 unexpected groundwater restart state type'
    end select
    close(unit)
  end subroutine write_restart_record

  subroutine read_restart_record(path, record)
    character(len=*), intent(in) :: path
    type(groundwater_coupled_restart_record_t), intent(out) :: record
    type(dummy_state_t), allocatable :: swap_state
    type(dummy_groundwater_restart_state_t), allocatable :: gw_state
    integer :: unit

    record = groundwater_coupled_restart_record_t()
    allocate(swap_state)
    allocate(gw_state)
    open(newunit=unit, file=trim(path), access='stream', form='unformatted', status='old', action='read')
    read(unit) record%schema_version, record%swap_kernel_schema_version, record%swap_layout_id, &
         record%swap_lineage_id, record%swap_revision, record%accepted_time
    read(unit) record%origin%initialized, record%origin%coupling_id, record%origin%accepted_h_groundwater_m, &
         record%origin%accepted_time, record%origin%swap_lineage_id, record%origin%swap_revision, &
         record%origin%groundwater_service_id, record%origin%groundwater_lineage_id, record%origin%groundwater_revision
    read(unit) record%ledger%schema_version, record%ledger%available, record%ledger%ledger_id, &
         record%ledger%committed_swap_outward_exchange_m, record%ledger%committed_exchange_count, &
         record%ledger%discarded_trial_count, record%ledger%discarded_trial_count_saturated
    read(unit) record%groundwater%schema_version, record%groundwater%service_id, record%groundwater%lineage_id, &
         record%groundwater%revision, record%groundwater%committed_time
    read(unit) swap_state%storage
    read(unit) gw_state%service_id, gw_state%lineage_id, gw_state%revision, gw_state%committed_time, &
         gw_state%trial_count, gw_state%response_mode
    close(unit)
    call move_alloc(swap_state, record%swap_physical_state)
    call move_alloc(gw_state, record%groundwater%backend_state)
  end subroutine read_restart_record

  subroutine write_signature(path, committed, groundwater, ledger, origin)
    character(len=*), intent(in) :: path
    type(kernel_committed_state_t), intent(in) :: committed
    type(dummy_groundwater_service_t), intent(in) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(in) :: ledger
    type(groundwater_coupling_origin_t), intent(in) :: origin
    class(transaction_state_t), allocatable :: physical
    type(groundwater_interface_mass_snapshot_t) :: snap
    real(real64) :: committed_time, storage
    logical :: available
    integer :: unit

    call committed%snapshot(physical, available)
    call require(available, 'signature SWAP snapshot')
    storage = 0.0_real64
    select type (typed_state => physical)
    type is (dummy_state_t)
      storage = typed_state%storage
    class default
      error stop 'F-GC24 signature unexpected SWAP state type'
    end select
    call committed%current_time(committed_time, available)
    call require(available, 'signature SWAP time')
    call ledger%snapshot(snap)
    call require(snap%available .and. snap%identity_bound, 'signature ledger snapshot')
    call require(transfer(snap%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'signature exact mass conservation')

    open(newunit=unit, file=trim(path), access='stream', form='unformatted', status='replace', action='write')
    write(unit) storage, committed%current_lineage_id(), committed%current_revision(), committed_time
    write(unit) groundwater%service_id_value, groundwater%lineage_id_value, groundwater%revision, &
         groundwater%current_time, groundwater%trial_count, groundwater%response_mode
    write(unit) snap%ledger_id, snap%committed_swap_outward_exchange_m, snap%committed_groundwater_outward_exchange_m, &
         snap%committed_exchange_count, snap%discarded_trial_count, snap%discarded_trial_count_saturated
    write(unit) origin%initialized, origin%coupling_id, origin%accepted_h_groundwater_m, origin%accepted_time, &
         origin%swap_lineage_id, origin%swap_revision, origin%groundwater_service_id, &
         origin%groundwater_lineage_id, origin%groundwater_revision
    close(unit)
  end subroutine write_signature

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write(*,'(A)') 'F-GC24 FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end module mod_fgc24_coupled_restart_test

program test_fgc24_coupled_restart_split_process
  use mod_fgc24_coupled_restart_test, only: run_mode
  implicit none
  character(len=32) :: mode
  character(len=512) :: path1, path2

  mode = ''
  path1 = ''
  path2 = ''
  call get_command_argument(1, mode)
  call get_command_argument(2, path1)
  call get_command_argument(3, path2)
  call run_mode(trim(mode), trim(path1), trim(path2))
end program test_fgc24_coupled_restart_split_process
