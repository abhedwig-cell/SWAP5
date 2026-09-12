module mod_groundwater_predictor_corrector_window
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_candidate_state_t, kernel_executor_t, kernel_result_t, kernel_diagnostics_t, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, GW_SWAP_FORCING_OK
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_lineage_t, groundwater_interface_state_t, groundwater_interface_residual_t, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, pair_groundwater_flux_from_swap, &
       evaluate_groundwater_interface_residual, GW_INTERFACE_OK
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, GW_HEAD_POLICY_OK
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, &
       groundwater_exchange_trial_result_t, groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, &
       groundwater_discard_candidate, groundwater_prepare_candidate, groundwater_commit_prepared, &
       groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64

  integer, parameter, public :: GW_PC_OK = 0
  integer, parameter, public :: GW_PC_INVALID_REQUEST = 1
  integer, parameter, public :: GW_PC_INVALID_ORIGIN = 2
  integer, parameter, public :: GW_PC_PROFILE_NOT_ADMITTED = 3
  integer, parameter, public :: GW_PC_SWAP_CHECKPOINT_FAILED = 4
  integer, parameter, public :: GW_PC_GROUNDWATER_CHECKPOINT_FAILED = 5
  integer, parameter, public :: GW_PC_PREDICTOR_FORCING_FAILED = 6
  integer, parameter, public :: GW_PC_PREDICTOR_SWAP_FAILED = 7
  integer, parameter, public :: GW_PC_PREDICTOR_EXCHANGE_FAILED = 8
  integer, parameter, public :: GW_PC_PREDICTOR_GROUNDWATER_FAILED = 9
  integer, parameter, public :: GW_PC_PREDICTOR_DISCARD_FAILED = 10
  integer, parameter, public :: GW_PC_CORRECTOR_FORCING_FAILED = 11
  integer, parameter, public :: GW_PC_CORRECTOR_SWAP_FAILED = 12
  integer, parameter, public :: GW_PC_CORRECTOR_EXCHANGE_FAILED = 13
  integer, parameter, public :: GW_PC_CORRECTOR_GROUNDWATER_FAILED = 14
  integer, parameter, public :: GW_PC_INTERFACE_FAILED = 15
  integer, parameter, public :: GW_PC_NOT_CONVERGED = 16
  integer, parameter, public :: GW_PC_LEDGER_STAGE_FAILED = 17
  integer, parameter, public :: GW_PC_GROUNDWATER_PREPARE_FAILED = 18
  integer, parameter, public :: GW_PC_LEDGER_PREPARE_FAILED = 19
  integer, parameter, public :: GW_PC_PUBLICATION_PREFLIGHT_FAILED = 20
  integer, parameter, public :: GW_PC_SWAP_COMMIT_FAILED = 21
  integer, parameter, public :: GW_PC_PREPUBLICATION_ABORT_FAILED = 22

  type, public :: groundwater_coupling_origin_t
    logical :: initialized = .false.
    integer(int64) :: coupling_id = 0_int64
    real(real64) :: accepted_h_groundwater_m = 0.0_real64
    real(real64) :: accepted_time = 0.0_real64
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: swap_revision = -1_int64
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_revision = -1_int64
  contains
    procedure, public :: finite_and_structurally_valid => groundwater_coupling_origin_valid
  end type groundwater_coupling_origin_t

  type, public :: groundwater_pc_diagnostics_t
    character(len=48) :: route = 'not-run'
    character(len=64) :: failure_stage = 'none'
    integer :: forcing_status = 0
    integer :: groundwater_status = 0
    integer :: ledger_status = 0
    integer :: interface_status = 0
    integer :: policy_status = 0
    integer :: swap_commit_status = -1
    logical :: predictor_swap_completed = .false.
    logical :: predictor_groundwater_completed = .false.
    logical :: predictor_discarded = .false.
    logical :: corrector_swap_completed = .false.
    logical :: corrector_groundwater_completed = .false.
    logical :: head_converged = .false.
    logical :: groundwater_prepared = .false.
    logical :: ledger_prepared = .false.
    logical :: publication_preflight_passed = .false.
    logical :: swap_committed = .false.
    logical :: groundwater_committed = .false.
    logical :: ledger_committed = .false.
    type(kernel_diagnostics_t) :: predictor_swap
    type(kernel_diagnostics_t) :: corrector_swap
  end type groundwater_pc_diagnostics_t

  type, public :: groundwater_pc_result_t
    integer :: status = GW_PC_INVALID_REQUEST
    logical :: completed = .false.
    logical :: committed = .false.
    logical :: request_smaller_window = .false.
    real(real64) :: predictor_swap_outward_exchange_cm = 0.0_real64
    real(real64) :: predictor_q_swap_m_per_s = 0.0_real64
    real(real64) :: predictor_q_groundwater_m_per_s = 0.0_real64
    real(real64) :: predictor_h_groundwater_m = 0.0_real64
    real(real64) :: corrector_swap_outward_exchange_cm = 0.0_real64
    real(real64) :: corrector_q_swap_m_per_s = 0.0_real64
    real(real64) :: corrector_q_groundwater_m_per_s = 0.0_real64
    real(real64) :: prescribed_corrector_h_swap_m = 0.0_real64
    real(real64) :: corrector_h_groundwater_m = 0.0_real64
    type(groundwater_interface_state_t) :: accepted_interface
    type(groundwater_interface_residual_t) :: residual
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    type(groundwater_pc_diagnostics_t) :: diagnostics
  end type groundwater_pc_result_t

  public :: run_restricted_groundwater_coupling_window

contains

  pure logical function groundwater_coupling_origin_valid(self) result(valid)
    class(groundwater_coupling_origin_t), intent(in) :: self

    valid = .false.
    if (.not. self%initialized) return
    if (self%coupling_id <= 0_int64) return
    if (.not. ieee_is_finite(self%accepted_h_groundwater_m)) return
    if (.not. ieee_is_finite(self%accepted_time)) return
    if (self%swap_lineage_id <= 0_int64 .or. self%swap_revision < 0_int64) return
    if (self%groundwater_service_id <= 0_int64) return
    if (self%groundwater_lineage_id <= 0_int64 .or. self%groundwater_revision < 0_int64) return
    valid = .true.
  end function groundwater_coupling_origin_valid

  subroutine run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
       groundwater, ledger, datum, head_policy, window, origin, result)
    type(kernel_executor_t), intent(inout) :: executor
    class(kernel_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(inout) :: committed
    class(groundwater_swap_forcing_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_head_convergence_policy_t), intent(in) :: head_policy
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_coupling_origin_t), intent(inout) :: origin
    type(groundwater_pc_result_t), intent(out) :: result

    type(kernel_checkpoint_t) :: swap_checkpoint
    type(kernel_candidate_state_t) :: predictor_swap_candidate, corrector_swap_candidate
    type(kernel_result_t) :: predictor_swap_result, corrector_swap_result
    type(groundwater_exchange_checkpoint_t) :: groundwater_checkpoint
    type(groundwater_exchange_candidate_t) :: predictor_groundwater_candidate, corrector_groundwater_candidate
    type(groundwater_exchange_prepared_t) :: prepared_groundwater
    type(groundwater_exchange_trial_result_t) :: predictor_groundwater_result, corrector_groundwater_result
    type(groundwater_interface_mass_prepared_t) :: prepared_ledger
    type(groundwater_interface_lineage_t) :: lineage
    type(groundwater_coupling_origin_t) :: next_origin
    class(canonical_forcing_t), allocatable :: forcing
    real(real64) :: swap_time, groundwater_time
    logical :: swap_checkpoint_ok, swap_time_available, groundwater_time_available
    logical :: converged, did_commit
    integer :: status, cleanup_status, commit_status, ledger_failure_status

    result = groundwater_pc_result_t()
    result%diagnostics%route = 'restricted-pc1'

    if (.not. window%valid() .or. .not. datum%valid() .or. .not. head_policy%valid()) then
      call fail_result(result, GW_PC_INVALID_REQUEST, .false., 'request-contract')
      return
    end if
    if (.not. materializer%profile_admitted(parameters)) then
      call fail_result(result, GW_PC_PROFILE_NOT_ADMITTED, .false., 'restricted-profile')
      return
    end if
    if (.not. origin%finite_and_structurally_valid()) then
      call fail_result(result, GW_PC_INVALID_ORIGIN, .false., 'coupling-origin')
      return
    end if
    if (.not. ledger%has_identity() .or. ledger%has_active_trial() .or. ledger%has_prepared_trial()) then
      call fail_result(result, GW_PC_INVALID_ORIGIN, .false., 'ledger-origin')
      return
    end if

    call committed%capture_checkpoint(swap_checkpoint, swap_checkpoint_ok)
    if (.not. swap_checkpoint_ok .or. .not. swap_checkpoint%ready()) then
      call fail_result(result, GW_PC_SWAP_CHECKPOINT_FAILED, .true., 'swap-checkpoint')
      return
    end if
    call groundwater_capture_checkpoint(groundwater, groundwater_checkpoint, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. groundwater_checkpoint%ready()) then
      call fail_result(result, GW_PC_GROUNDWATER_CHECKPOINT_FAILED, .true., 'groundwater-checkpoint')
      return
    end if

    call swap_checkpoint%current_time(swap_time, swap_time_available)
    call groundwater_checkpoint%origin_time(groundwater_time, groundwater_time_available)
    if (.not. validate_coupling_origin(origin, window, swap_checkpoint, swap_time, swap_time_available, &
         groundwater_checkpoint, groundwater_time, groundwater_time_available)) then
      call fail_result(result, GW_PC_INVALID_ORIGIN, .false., 'origin-provenance')
      return
    end if

    call materializer%materialize(origin%accepted_h_groundwater_m, datum, forcing, status)
    result%diagnostics%forcing_status = status
    if (status /= GW_SWAP_FORCING_OK .or. .not. allocated(forcing)) then
      call fail_result(result, GW_PC_PREDICTOR_FORCING_FAILED, .true., 'predictor-forcing')
      return
    end if
    call executor%advance_interval(parameters, committed, forcing, numerical, window%t0, window%t1, &
         predictor_swap_result, predictor_swap_candidate, result%diagnostics%predictor_swap, checkpoint=swap_checkpoint)
    if (.not. accepted_whole_window_swap_result(predictor_swap_result, window, predictor_swap_candidate)) then
      call rollback_swap_candidate(executor, predictor_swap_candidate, result%diagnostics%predictor_swap)
      call fail_result(result, GW_PC_PREDICTOR_SWAP_FAILED, .true., 'predictor-swap')
      return
    end if
    result%diagnostics%predictor_swap_completed = .true.
    result%predictor_swap_outward_exchange_cm = predictor_swap_result%bottom_outward_exchange_native
    call whole_window_exchange_to_flux_pair(result%predictor_swap_outward_exchange_cm, window, &
         result%predictor_q_swap_m_per_s, result%predictor_q_groundwater_m_per_s, status)
    result%diagnostics%interface_status = status
    if (status /= GW_INTERFACE_OK) then
      call rollback_swap_candidate(executor, predictor_swap_candidate, result%diagnostics%predictor_swap)
      call fail_result(result, GW_PC_PREDICTOR_EXCHANGE_FAILED, .true., 'predictor-exchange')
      return
    end if

    call groundwater_trial_from_checkpoint(groundwater, groundwater_checkpoint, window, &
         result%predictor_q_groundwater_m_per_s, predictor_groundwater_candidate, predictor_groundwater_result, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. predictor_groundwater_candidate%ready()) then
      call rollback_swap_candidate(executor, predictor_swap_candidate, result%diagnostics%predictor_swap)
      call fail_result(result, GW_PC_PREDICTOR_GROUNDWATER_FAILED, .true., 'predictor-groundwater')
      return
    end if
    result%diagnostics%predictor_groundwater_completed = .true.
    result%predictor_h_groundwater_m = predictor_groundwater_result%h_groundwater_m

    call groundwater_discard_candidate(groundwater, predictor_groundwater_candidate, cleanup_status)
    result%diagnostics%groundwater_status = cleanup_status
    call rollback_swap_candidate(executor, predictor_swap_candidate, result%diagnostics%predictor_swap)
    if (cleanup_status /= GW_EXCHANGE_OK) then
      call fail_result(result, GW_PC_PREDICTOR_DISCARD_FAILED, .true., 'predictor-discard')
      return
    end if
    result%diagnostics%predictor_discarded = .true.

    if (allocated(forcing)) deallocate(forcing)
    call materializer%materialize(result%predictor_h_groundwater_m, datum, forcing, status)
    result%diagnostics%forcing_status = status
    if (status /= GW_SWAP_FORCING_OK .or. .not. allocated(forcing)) then
      call fail_result(result, GW_PC_CORRECTOR_FORCING_FAILED, .true., 'corrector-forcing')
      return
    end if
    call executor%advance_interval(parameters, committed, forcing, numerical, window%t0, window%t1, &
         corrector_swap_result, corrector_swap_candidate, result%diagnostics%corrector_swap, checkpoint=swap_checkpoint)
    if (.not. accepted_whole_window_swap_result(corrector_swap_result, window, corrector_swap_candidate)) then
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      call fail_result(result, GW_PC_CORRECTOR_SWAP_FAILED, .true., 'corrector-swap')
      return
    end if
    result%diagnostics%corrector_swap_completed = .true.
    result%corrector_swap_outward_exchange_cm = corrector_swap_result%bottom_outward_exchange_native
    call whole_window_exchange_to_flux_pair(result%corrector_swap_outward_exchange_cm, window, &
         result%corrector_q_swap_m_per_s, result%corrector_q_groundwater_m_per_s, status)
    result%diagnostics%interface_status = status
    if (status /= GW_INTERFACE_OK) then
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      call fail_result(result, GW_PC_CORRECTOR_EXCHANGE_FAILED, .true., 'corrector-exchange')
      return
    end if

    call groundwater_trial_from_checkpoint(groundwater, groundwater_checkpoint, window, &
         result%corrector_q_groundwater_m_per_s, corrector_groundwater_candidate, corrector_groundwater_result, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. corrector_groundwater_candidate%ready()) then
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      call fail_result(result, GW_PC_CORRECTOR_GROUNDWATER_FAILED, .true., 'corrector-groundwater')
      return
    end if
    result%diagnostics%corrector_groundwater_completed = .true.
    result%prescribed_corrector_h_swap_m = result%predictor_h_groundwater_m
    result%corrector_h_groundwater_m = corrector_groundwater_result%h_groundwater_m

    result%accepted_interface%h_swap_m = result%prescribed_corrector_h_swap_m
    result%accepted_interface%h_groundwater_m = result%corrector_h_groundwater_m
    result%accepted_interface%q_swap_m_per_s = result%corrector_q_swap_m_per_s
    result%accepted_interface%q_groundwater_m_per_s = result%corrector_q_groundwater_m_per_s
    call evaluate_groundwater_interface_residual(result%accepted_interface, result%residual, status)
    result%diagnostics%interface_status = status
    if (status /= GW_INTERFACE_OK .or. abs(result%residual%flux_residual_m_per_s) > 0.0_real64) then
      call discard_corrector_candidates(executor, corrector_swap_candidate, result%diagnostics%corrector_swap, &
           groundwater, corrector_groundwater_candidate, cleanup_status)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'interface-discard')
      else
        call fail_result(result, GW_PC_INTERFACE_FAILED, .true., 'interface-residual')
      end if
      return
    end if

    call head_policy%evaluate(result%residual%head_residual_m, converged, status)
    result%diagnostics%policy_status = status
    result%diagnostics%head_converged = converged .and. status == GW_HEAD_POLICY_OK
    if (status /= GW_HEAD_POLICY_OK) then
      call discard_corrector_candidates(executor, corrector_swap_candidate, result%diagnostics%corrector_swap, &
           groundwater, corrector_groundwater_candidate, cleanup_status)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'head-policy-discard')
      else
        call fail_result(result, GW_PC_INTERFACE_FAILED, .true., 'head-policy')
      end if
      return
    end if
    if (.not. converged) then
      call discard_corrector_candidates(executor, corrector_swap_candidate, result%diagnostics%corrector_swap, &
           groundwater, corrector_groundwater_candidate, cleanup_status)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'nonconverged-discard')
      else
        call fail_result(result, GW_PC_NOT_CONVERGED, .true., 'head-not-converged')
      end if
      return
    end if

    call build_lineage(origin, corrector_groundwater_result, lineage)
    call ledger%stage_exchange(window, lineage, result%corrector_swap_outward_exchange_cm * CM_TO_M, status)
    result%diagnostics%ledger_status = status
    if (status /= GW_MASS_LEDGER_OK) then
      call discard_corrector_candidates(executor, corrector_swap_candidate, result%diagnostics%corrector_swap, &
           groundwater, corrector_groundwater_candidate, cleanup_status)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'ledger-stage-discard')
      else
        call fail_result(result, GW_PC_LEDGER_STAGE_FAILED, .true., 'ledger-stage')
      end if
      return
    end if

    call groundwater_prepare_candidate(groundwater, groundwater_checkpoint, corrector_groundwater_candidate, &
         prepared_groundwater, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK) then
      cleanup_status = GW_EXCHANGE_OK
      if (corrector_groundwater_candidate%ready()) then
        call groundwater_discard_candidate(groundwater, corrector_groundwater_candidate, cleanup_status)
      end if
      ledger_failure_status = GW_MASS_LEDGER_OK
      if (ledger%has_active_trial()) call ledger%discard_trial(ledger_failure_status)
      result%diagnostics%ledger_status = ledger_failure_status
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK .or. ledger_failure_status /= GW_MASS_LEDGER_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'groundwater-prepare-cleanup')
      else
        call fail_result(result, GW_PC_GROUNDWATER_PREPARE_FAILED, .true., 'groundwater-prepare')
      end if
      return
    end if
    result%diagnostics%groundwater_prepared = .true.

    call ledger%prepare_trial(prepared_ledger, status)
    ledger_failure_status = status
    result%diagnostics%ledger_status = ledger_failure_status
    if (ledger_failure_status /= GW_MASS_LEDGER_OK) then
      call groundwater_abort_prepared(groundwater, groundwater_checkpoint, prepared_groundwater, cleanup_status)
      status = GW_MASS_LEDGER_OK
      if (ledger%has_active_trial()) call ledger%discard_trial(status)
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK .or. status /= GW_MASS_LEDGER_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'ledger-prepare-abort')
      else
        call fail_result(result, GW_PC_LEDGER_PREPARE_FAILED, .true., 'ledger-prepare')
      end if
      result%diagnostics%ledger_status = ledger_failure_status
      return
    end if
    result%diagnostics%ledger_prepared = .true.

    call make_next_origin(origin, window, committed, corrector_groundwater_result, next_origin, status)
    if (status /= GW_PC_OK .or. .not. publication_preflight(committed, corrector_swap_candidate, window, &
         groundwater_checkpoint, prepared_groundwater, ledger, prepared_ledger, next_origin)) then
      call abort_prepared_pair(groundwater, groundwater_checkpoint, prepared_groundwater, ledger, prepared_ledger, cleanup_status)
      call rollback_swap_candidate(executor, corrector_swap_candidate, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'publication-preflight-abort')
      else
        call fail_result(result, GW_PC_PUBLICATION_PREFLIGHT_FAILED, .true., 'publication-preflight')
      end if
      return
    end if
    result%diagnostics%publication_preflight_passed = .true.

    call executor%commit_candidate(committed, corrector_swap_candidate, result%diagnostics%corrector_swap, &
         did_commit, commit_status)
    result%diagnostics%swap_commit_status = commit_status
    if (.not. did_commit .or. commit_status /= KERNEL_COMMIT_STATUS_COMMITTED) then
      call abort_prepared_pair(groundwater, groundwater_checkpoint, prepared_groundwater, ledger, prepared_ledger, cleanup_status)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_result(result, GW_PC_PREPUBLICATION_ABORT_FAILED, .true., 'swap-commit-abort')
      else
        call fail_result(result, GW_PC_SWAP_COMMIT_FAILED, .true., 'swap-commit')
      end if
      return
    end if
    result%diagnostics%swap_committed = .true.

    ! From here publication is irreversible for this in-process workunit. The
    ! admitted F-GC18 prepared backend has no recoverable callback status after
    ! its wrapper reservation has been consumed. An unexpected status here is a
    ! programming/ownership invariant violation, not a recoverable coupling path.
    call groundwater_commit_prepared(groundwater, groundwater_checkpoint, prepared_groundwater, status)
    if (status /= GW_EXCHANGE_OK) then
      error stop 'F-GC21 atomic publication invariant: groundwater commit failed after SWAP commit'
    end if
    result%diagnostics%groundwater_status = status
    result%diagnostics%groundwater_committed = .true.

    call ledger%commit_prepared(prepared_ledger)
    result%diagnostics%ledger_committed = .true.
    origin = next_origin

    call ledger%snapshot(result%ledger_snapshot)
    if (.not. result%ledger_snapshot%available .or. &
        abs(result%ledger_snapshot%conservation_residual_m) > 0.0_real64) then
      error stop 'F-GC21 hard mass invariant: committed interface ledger is not exactly conservative'
    end if

    result%status = GW_PC_OK
    result%completed = .true.
    result%committed = .true.
    result%request_smaller_window = .false.
    result%diagnostics%route = 'restricted-pc1-committed'
    result%diagnostics%failure_stage = 'none'
  end subroutine run_restricted_groundwater_coupling_window

  logical function validate_coupling_origin(origin, window, swap_checkpoint, swap_time, swap_time_available, &
       groundwater_checkpoint, groundwater_time, groundwater_time_available) result(valid)
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_checkpoint_t), intent(in) :: swap_checkpoint
    real(real64), intent(in) :: swap_time, groundwater_time
    logical, intent(in) :: swap_time_available, groundwater_time_available
    type(groundwater_exchange_checkpoint_t), intent(in) :: groundwater_checkpoint

    valid = .false.
    if (.not. swap_time_available .or. .not. groundwater_time_available) return
    if (.not. same_time(origin%accepted_time, window%t0)) return
    if (.not. same_time(swap_time, window%t0) .or. .not. same_time(groundwater_time, window%t0)) return
    if (swap_checkpoint%current_lineage_id() /= origin%swap_lineage_id) return
    if (swap_checkpoint%origin_revision() /= origin%swap_revision) return
    if (groundwater_checkpoint%service_id() /= origin%groundwater_service_id) return
    if (groundwater_checkpoint%lineage_id() /= origin%groundwater_lineage_id) return
    if (groundwater_checkpoint%origin_revision() /= origin%groundwater_revision) return
    valid = .true.
  end function validate_coupling_origin

  logical function accepted_whole_window_swap_result(swap_result, window, candidate) result(valid)
    type(kernel_result_t), intent(in) :: swap_result
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64) :: candidate_t0, candidate_t1
    logical :: candidate_interval_available

    valid = .false.
    if (.not. swap_result%completed .or. .not. candidate%ready()) return
    if (.not. swap_result%bottom_interface_exchange_available) return
    if (.not. ieee_is_finite(swap_result%bottom_outward_exchange_native)) return
    if (.not. ieee_is_finite(swap_result%terminal_bottom_outward_flux_native)) return
    if (.not. same_time(swap_result%requested_t0, window%t0)) return
    if (.not. same_time(swap_result%requested_t1, window%t1)) return
    if (.not. same_time(swap_result%completed_t, window%t1)) return
    call candidate%origin_interval(candidate_t0, candidate_t1, candidate_interval_available)
    if (.not. candidate_interval_available) return
    if (.not. same_time(candidate_t0, window%t0) .or. .not. same_time(candidate_t1, window%t1)) return
    valid = .true.
  end function accepted_whole_window_swap_result

  subroutine whole_window_exchange_to_flux_pair(exchange_cm, window, q_swap_m_per_s, q_groundwater_m_per_s, status)
    real(real64), intent(in) :: exchange_cm
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(out) :: q_swap_m_per_s, q_groundwater_m_per_s
    integer, intent(out) :: status
    real(real64) :: duration_day, qbot_mean_cm_per_day

    q_swap_m_per_s = 0.0_real64
    q_groundwater_m_per_s = 0.0_real64
    status = -1
    if (.not. window%valid() .or. .not. ieee_is_finite(exchange_cm)) return
    duration_day = window%t1 - window%t0
    if (.not. ieee_is_finite(duration_day) .or. duration_day <= 0.0_real64) return
    qbot_mean_cm_per_day = -exchange_cm / duration_day
    if (.not. ieee_is_finite(qbot_mean_cm_per_day)) return
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day, q_swap_m_per_s, status)
    if (status /= GW_INTERFACE_OK) return
    call pair_groundwater_flux_from_swap(q_swap_m_per_s, q_groundwater_m_per_s, status)
  end subroutine whole_window_exchange_to_flux_pair

  subroutine build_lineage(origin, groundwater_result, lineage)
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_exchange_trial_result_t), intent(in) :: groundwater_result
    type(groundwater_interface_lineage_t), intent(out) :: lineage

    lineage = groundwater_interface_lineage_t()
    lineage%coupling_id = origin%coupling_id
    lineage%swap_lineage_id = origin%swap_lineage_id
    lineage%swap_origin_revision = origin%swap_revision
    lineage%groundwater_lineage_id = origin%groundwater_lineage_id
    lineage%groundwater_origin_revision = origin%groundwater_revision
    lineage%candidate_revision = groundwater_result%candidate_revision
  end subroutine build_lineage

  subroutine make_next_origin(origin, window, committed, groundwater_result, next_origin, status)
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_committed_state_t), intent(in) :: committed
    type(groundwater_exchange_trial_result_t), intent(in) :: groundwater_result
    type(groundwater_coupling_origin_t), intent(out) :: next_origin
    integer, intent(out) :: status
    integer(int64) :: current_revision

    next_origin = groundwater_coupling_origin_t()
    status = GW_PC_PUBLICATION_PREFLIGHT_FAILED
    current_revision = committed%current_revision()
    if (current_revision < 0_int64 .or. current_revision >= huge(0_int64)) return
    if (.not. ieee_is_finite(groundwater_result%h_groundwater_m)) return
    if (groundwater_result%candidate_revision < 0_int64) return

    next_origin%initialized = .true.
    next_origin%coupling_id = origin%coupling_id
    next_origin%accepted_h_groundwater_m = groundwater_result%h_groundwater_m
    next_origin%accepted_time = window%t1
    next_origin%swap_lineage_id = origin%swap_lineage_id
    next_origin%swap_revision = current_revision + 1_int64
    next_origin%groundwater_service_id = origin%groundwater_service_id
    next_origin%groundwater_lineage_id = origin%groundwater_lineage_id
    next_origin%groundwater_revision = groundwater_result%candidate_revision
    if (.not. next_origin%finite_and_structurally_valid()) return
    status = GW_PC_OK
  end subroutine make_next_origin

  logical function publication_preflight(committed, swap_candidate, window, groundwater_checkpoint, prepared_groundwater, &
       ledger, prepared_ledger, next_origin) result(ready)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_candidate_state_t), intent(in) :: swap_candidate
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_exchange_checkpoint_t), intent(in) :: groundwater_checkpoint
    type(groundwater_exchange_prepared_t), intent(in) :: prepared_groundwater
    type(groundwater_interface_mass_ledger_t), intent(in) :: ledger
    type(groundwater_interface_mass_prepared_t), intent(in) :: prepared_ledger
    type(groundwater_coupling_origin_t), intent(in) :: next_origin
    real(real64) :: committed_time, candidate_t0, candidate_t1
    type(groundwater_coupling_window_t) :: prepared_window
    logical :: committed_time_available, candidate_interval_available, prepared_window_available
    integer(int64) :: current_revision

    ready = .false.
    if (.not. committed%ready() .or. .not. swap_candidate%ready()) return
    current_revision = committed%current_revision()
    if (current_revision < 0_int64 .or. current_revision >= huge(0_int64)) return
    if (swap_candidate%current_lineage_id() /= committed%current_lineage_id()) return
    if (swap_candidate%origin_revision() /= current_revision) return
    call committed%current_time(committed_time, committed_time_available)
    if (.not. committed_time_available .or. .not. same_time(committed_time, window%t0)) return
    call swap_candidate%origin_interval(candidate_t0, candidate_t1, candidate_interval_available)
    if (.not. candidate_interval_available) return
    if (.not. same_time(candidate_t0, window%t0) .or. .not. same_time(candidate_t1, window%t1)) return

    if (.not. groundwater_checkpoint%ready() .or. .not. groundwater_checkpoint%is_prepared()) return
    if (.not. prepared_groundwater%ready()) return
    if (prepared_groundwater%service_id() /= groundwater_checkpoint%service_id()) return
    if (prepared_groundwater%lineage_id() /= groundwater_checkpoint%lineage_id()) return
    if (prepared_groundwater%origin_revision() /= groundwater_checkpoint%origin_revision()) return
    call prepared_groundwater%origin_window(prepared_window, prepared_window_available)
    if (.not. prepared_window_available) return
    if (.not. same_time(prepared_window%t0, window%t0) .or. .not. same_time(prepared_window%t1, window%t1)) return

    if (.not. ledger%prepared_ready_for_commit(prepared_ledger)) return
    if (.not. next_origin%finite_and_structurally_valid()) return
    if (.not. same_time(next_origin%accepted_time, window%t1)) return
    if (next_origin%swap_revision /= current_revision + 1_int64) return
    if (next_origin%groundwater_revision /= prepared_groundwater%candidate_revision()) return
    ready = .true.
  end function publication_preflight

  subroutine rollback_swap_candidate(executor, candidate, diagnostics)
    type(kernel_executor_t), intent(inout) :: executor
    type(kernel_candidate_state_t), intent(inout) :: candidate
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    if (candidate%ready()) call executor%rollback_candidate(candidate, diagnostics)
  end subroutine rollback_swap_candidate

  subroutine discard_corrector_candidates(executor, swap_candidate, swap_diagnostics, groundwater, &
       groundwater_candidate, groundwater_status)
    type(kernel_executor_t), intent(inout) :: executor
    type(kernel_candidate_state_t), intent(inout) :: swap_candidate
    type(kernel_diagnostics_t), intent(inout) :: swap_diagnostics
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_exchange_candidate_t), intent(inout) :: groundwater_candidate
    integer, intent(out) :: groundwater_status

    groundwater_status = GW_EXCHANGE_OK
    if (groundwater_candidate%ready()) call groundwater_discard_candidate(groundwater, groundwater_candidate, groundwater_status)
    call rollback_swap_candidate(executor, swap_candidate, swap_diagnostics)
  end subroutine discard_corrector_candidates

  subroutine abort_prepared_pair(groundwater, groundwater_checkpoint, prepared_groundwater, ledger, prepared_ledger, status)
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_exchange_checkpoint_t), intent(inout) :: groundwater_checkpoint
    type(groundwater_exchange_prepared_t), intent(inout) :: prepared_groundwater
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    type(groundwater_interface_mass_prepared_t), intent(inout) :: prepared_ledger
    integer, intent(out) :: status

    status = GW_EXCHANGE_OK
    if (prepared_groundwater%ready() .and. groundwater_checkpoint%is_prepared()) then
      call groundwater_abort_prepared(groundwater, groundwater_checkpoint, prepared_groundwater, status)
    end if
    if (prepared_ledger%ready() .and. ledger%has_prepared_trial()) call ledger%abort_prepared(prepared_ledger)
  end subroutine abort_prepared_pair

  subroutine fail_result(result, status, request_smaller_window, stage)
    type(groundwater_pc_result_t), intent(inout) :: result
    integer, intent(in) :: status
    logical, intent(in) :: request_smaller_window
    character(len=*), intent(in) :: stage

    result%status = status
    result%completed = .false.
    result%committed = .false.
    result%request_smaller_window = request_smaller_window
    result%diagnostics%failure_stage = stage
  end subroutine fail_result

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_groundwater_predictor_corrector_window
