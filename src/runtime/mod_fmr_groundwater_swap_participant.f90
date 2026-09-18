module mod_fmr_groundwater_swap_participant
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, GW_INTERFACE_OK
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, GW_SWAP_FORCING_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, &
       GW_SWAP_PARTICIPANT_OK, GW_SWAP_PARTICIPANT_INVALID_REQUEST, GW_SWAP_PARTICIPANT_ORIGIN_CAPTURE_FAILED, &
       GW_SWAP_PARTICIPANT_ORIGIN_DRIFT, GW_SWAP_PARTICIPANT_CANDIDATE_BUSY, GW_SWAP_PARTICIPANT_FORCING_FAILED, &
       GW_SWAP_PARTICIPANT_TRIAL_FAILED, GW_SWAP_PARTICIPANT_EXCHANGE_FAILED, &
       GW_SWAP_PARTICIPANT_PREFLIGHT_FAILED, GW_SWAP_PARTICIPANT_COMMIT_FAILED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  implicit none
  private

  ! F-GC44 concrete binding of the admitted F-GC43 participant contract to the
  ! encapsulated FMR backend. The FMR backend keeps its kernel executor private;
  ! this adapter therefore holds only checkpoint/candidate provenance and calls
  ! backend-owned trial/rollback/commit operations.
  type, public :: fmr_groundwater_swap_participant_t
    private
    type(kernel_checkpoint_t) :: origin_checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: trial_result
    type(kernel_diagnostics_t) :: diagnostics
    integer(int64) :: origin_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    real(real64) :: origin_time = 0.0_real64
    logical :: origin_captured = .false.
    logical :: live_candidate = .false.
  contains
    procedure, public :: capture_origin => fmr_swap_capture_origin
    procedure, public :: trial_from_origin => fmr_swap_trial_from_origin
    procedure, public :: discard_candidate => fmr_swap_discard_candidate
    procedure, public :: publication_ready => fmr_swap_publication_ready
    procedure, public :: commit_candidate => fmr_swap_commit_candidate
    procedure, public :: has_origin => fmr_swap_has_origin
    procedure, public :: has_live_candidate => fmr_swap_has_live_candidate
    procedure, public :: captured_lineage_id => fmr_swap_lineage_id
    procedure, public :: captured_revision => fmr_swap_revision
  end type fmr_groundwater_swap_participant_t

contains

  subroutine fmr_swap_capture_origin(self, committed, status)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    integer, intent(out) :: status
    logical :: available

    status = GW_SWAP_PARTICIPANT_ORIGIN_CAPTURE_FAILED
    if (self%live_candidate) then
      status = GW_SWAP_PARTICIPANT_CANDIDATE_BUSY
      return
    end if
    if (.not. committed%ready()) return
    call committed%capture_checkpoint(self%origin_checkpoint, available)
    if (.not. available) return
    if (.not. self%origin_checkpoint%ready()) return
    call self%origin_checkpoint%current_time(self%origin_time, available)
    if (.not. available) return
    if (.not. ieee_is_finite(self%origin_time)) return
    self%origin_lineage_id = self%origin_checkpoint%current_lineage_id()
    self%origin_revision = self%origin_checkpoint%origin_revision()
    if (self%origin_lineage_id <= 0_int64 .or. self%origin_revision < 0_int64) return
    self%origin_captured = .true.
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine fmr_swap_capture_origin

  subroutine fmr_swap_trial_from_origin(self, backend, column, template, parameters, committed, materializer, &
       numerical, datum, window, prescribed_head_m, trial, status)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    class(groundwater_swap_forcing_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_head_m
    type(groundwater_swap_trial_t), intent(out) :: trial
    integer, intent(out) :: status

    class(canonical_forcing_t), allocatable :: forcing
    real(real64) :: duration_day, qbot_mean_cm_per_day
    integer :: forcing_status, interface_status

    trial = groundwater_swap_trial_t()
    status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    if (.not. self%origin_captured) return
    if (.not. self%origin_checkpoint%ready()) return
    if (self%live_candidate) then
      status = GW_SWAP_PARTICIPANT_CANDIDATE_BUSY
      return
    end if
    if (.not. window%valid()) return
    if (.not. datum%valid()) return
    if (.not. ieee_is_finite(prescribed_head_m)) return
    if (.not. same_time(window%t0, self%origin_time)) then
      status = GW_SWAP_PARTICIPANT_ORIGIN_DRIFT
      return
    end if
    if (.not. origin_still_current(self, committed)) then
      status = GW_SWAP_PARTICIPANT_ORIGIN_DRIFT
      return
    end if
    if (.not. materializer%profile_admitted(parameters)) then
      status = GW_SWAP_PARTICIPANT_FORCING_FAILED
      return
    end if

    call materializer%materialize(prescribed_head_m, datum, forcing, forcing_status)
    if (forcing_status /= GW_SWAP_FORCING_OK .or. .not. allocated(forcing)) then
      status = GW_SWAP_PARTICIPANT_FORCING_FAILED
      return
    end if

    select type (typed_forcing => forcing)
    type is (fmr_b110_physical_forcing_t)
      call backend%run_trial(column, template, parameters, committed, typed_forcing, numerical, &
           window%t0, window%t1, self%origin_checkpoint, self%trial_result, self%candidate, self%diagnostics)
    class default
      status = GW_SWAP_PARTICIPANT_FORCING_FAILED
      return
    end select

    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then
      if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      status = GW_SWAP_PARTICIPANT_TRIAL_FAILED
      return
    end if

    duration_day = window%t1 - window%t0
    qbot_mean_cm_per_day = -self%trial_result%bottom_outward_exchange_native / duration_day
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day, &
         trial%q_swap_m_per_s, interface_status)
    if (interface_status /= GW_INTERFACE_OK .or. .not. ieee_is_finite(trial%q_swap_m_per_s)) then
      call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      status = GW_SWAP_PARTICIPANT_EXCHANGE_FAILED
      return
    end if

    self%live_candidate = .true.
    trial%valid = .true.
    trial%prescribed_head_m = prescribed_head_m
    trial%bottom_outward_exchange_cm = self%trial_result%bottom_outward_exchange_native
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine fmr_swap_trial_from_origin

  subroutine fmr_swap_discard_candidate(self, backend)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
    self%live_candidate = .false.
  end subroutine fmr_swap_discard_candidate

  logical function fmr_swap_publication_ready(self, committed, window) result(ready)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64) :: committed_time, candidate_t0, candidate_t1
    logical :: committed_time_available, candidate_interval_available

    ready = .false.
    if (.not. self%origin_captured) return
    if (.not. self%live_candidate) return
    if (.not. window%valid()) return
    if (.not. committed%ready()) return
    if (.not. self%candidate%ready()) return
    if (.not. origin_still_current(self, committed)) return
    call committed%current_time(committed_time, committed_time_available)
    if (.not. committed_time_available) return
    if (.not. same_time(committed_time, window%t0)) return
    if (.not. same_time(self%origin_time, window%t0)) return
    if (self%candidate%current_lineage_id() /= self%origin_lineage_id) return
    if (self%candidate%origin_revision() /= self%origin_revision) return
    call self%candidate%origin_interval(candidate_t0, candidate_t1, candidate_interval_available)
    if (.not. candidate_interval_available) return
    if (.not. same_time(candidate_t0, window%t0) .or. .not. same_time(candidate_t1, window%t1)) return
    if (.not. self%trial_result%completed) return
    if (.not. same_time(self%trial_result%requested_t0, window%t0)) return
    if (.not. same_time(self%trial_result%requested_t1, window%t1)) return
    if (.not. same_time(self%trial_result%completed_t, window%t1)) return
    ready = .true.
  end function fmr_swap_publication_ready

  subroutine fmr_swap_commit_candidate(self, backend, committed, window, did_commit, status)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_committed_state_t), intent(inout) :: committed
    type(groundwater_coupling_window_t), intent(in) :: window
    logical, intent(out) :: did_commit
    integer, intent(out) :: status
    integer :: kernel_status

    did_commit = .false.
    status = GW_SWAP_PARTICIPANT_PREFLIGHT_FAILED
    if (.not. self%publication_ready(committed, window)) return
    call backend%commit_trial_candidate(committed, self%candidate, self%diagnostics, did_commit, kernel_status)
    if (.not. did_commit .or. kernel_status /= KERNEL_COMMIT_STATUS_COMMITTED) then
      did_commit = .false.
      status = GW_SWAP_PARTICIPANT_COMMIT_FAILED
      return
    end if
    self%live_candidate = .false.
    self%origin_captured = .false.
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine fmr_swap_commit_candidate

  logical function origin_still_current(self, committed) result(current)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64) :: committed_time
    logical :: time_available
    current = .false.
    if (.not. self%origin_captured) return
    if (.not. committed%ready()) return
    if (committed%current_lineage_id() /= self%origin_lineage_id) return
    if (committed%current_revision() /= self%origin_revision) return
    call committed%current_time(committed_time, time_available)
    if (.not. time_available) return
    if (.not. same_time(committed_time, self%origin_time)) return
    current = .true.
  end function origin_still_current

  logical function accepted_whole_window(result, candidate, window) result(valid)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64) :: candidate_t0, candidate_t1
    logical :: interval_available
    valid = .false.
    if (.not. result%completed) return
    if (.not. candidate%ready()) return
    if (.not. result%bottom_interface_exchange_available) return
    if (.not. ieee_is_finite(result%bottom_outward_exchange_native)) return
    if (.not. ieee_is_finite(result%terminal_bottom_outward_flux_native)) return
    if (.not. same_time(result%requested_t0, window%t0)) return
    if (.not. same_time(result%requested_t1, window%t1)) return
    if (.not. same_time(result%completed_t, window%t1)) return
    call candidate%origin_interval(candidate_t0, candidate_t1, interval_available)
    if (.not. interval_available) return
    if (.not. same_time(candidate_t0, window%t0) .or. .not. same_time(candidate_t1, window%t1)) return
    valid = .true.
  end function accepted_whole_window

  logical function fmr_swap_has_origin(self) result(value)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    value = self%origin_captured
  end function fmr_swap_has_origin

  logical function fmr_swap_has_live_candidate(self) result(value)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    value = .false.
    if (.not. self%live_candidate) return
    value = self%candidate%ready()
  end function fmr_swap_has_live_candidate

  integer(int64) function fmr_swap_lineage_id(self) result(value)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    value = self%origin_lineage_id
  end function fmr_swap_lineage_id

  integer(int64) function fmr_swap_revision(self) result(value)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    value = self%origin_revision
  end function fmr_swap_revision

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function same_time

end module mod_fmr_groundwater_swap_participant
