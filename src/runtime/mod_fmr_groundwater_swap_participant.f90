module mod_fmr_groundwater_swap_participant
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD
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

  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: FMR_TANGENT_CACHE_OK = 0
  integer, parameter, public :: FMR_TANGENT_CACHE_INVALID_CONFIG = 1

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
    logical :: tangent_cache_enabled = .false.
    logical :: tangent_cache_valid = .false.
    real(real64) :: tangent_cache_value = 0.0_real64
    real(real64) :: tangent_cache_refresh_head_m = 0.0_real64
    real(real64) :: tangent_cache_head_limit_m = 0.005_real64
    integer :: tangent_cache_max_age = 8
    integer :: tangent_cache_age = 0
    integer :: tangent_cache_fresh_count = 0
    integer :: tangent_cache_reuse_count = 0
    integer(int64) :: tangent_cache_lineage_id = 0_int64
    integer(int64) :: tangent_cache_revision = -1_int64
    real(real64) :: tangent_cache_t0 = 0.0_real64
    real(real64) :: tangent_cache_t1 = 0.0_real64
  contains
    procedure, public :: capture_origin => fmr_swap_capture_origin
    procedure, public :: trial_from_origin => fmr_swap_trial_from_origin
    procedure, public :: discard_candidate => fmr_swap_discard_candidate
    procedure, public :: abandon_origin => fmr_swap_abandon_origin
    procedure, public :: publication_ready => fmr_swap_publication_ready
    procedure, public :: commit_candidate => fmr_swap_commit_candidate
    procedure, public :: has_origin => fmr_swap_has_origin
    procedure, public :: has_live_candidate => fmr_swap_has_live_candidate
    procedure, public :: captured_lineage_id => fmr_swap_lineage_id
    procedure, public :: captured_revision => fmr_swap_revision
    procedure, public :: configure_tangent_cache => fmr_swap_configure_tangent_cache
    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts
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
    call invalidate_tangent_cache(self)
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine fmr_swap_capture_origin

  subroutine fmr_swap_trial_from_origin(self, backend, column, template, parameters, committed, materializer, &
       numerical, datum, window, prescribed_head_m, trial, status, trusted_prepared_parameters)
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
    logical, intent(in), optional :: trusted_prepared_parameters

    class(canonical_forcing_t), allocatable :: forcing
    type(canonical_numerical_config_t) :: trial_numerical
    real(real64) :: duration_day, qbot_mean_cm_per_day, dq_swap_dh_per_s
    integer :: forcing_status, interface_status
    logical :: refresh_tangent

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

    refresh_tangent = .true.
    if (self%tangent_cache_enabled .and. self%tangent_cache_valid) then
      refresh_tangent = self%tangent_cache_lineage_id /= self%origin_lineage_id .or. &
           self%tangent_cache_revision /= self%origin_revision .or. &
           .not. same_time(self%tangent_cache_t0, window%t0) .or. &
           .not. same_time(self%tangent_cache_t1, window%t1) .or. &
           self%tangent_cache_age >= self%tangent_cache_max_age .or. &
           abs(prescribed_head_m-self%tangent_cache_refresh_head_m) > self%tangent_cache_head_limit_m .or. &
           .not. ieee_is_finite(self%tangent_cache_value)
    end if

    trial_numerical = numerical
    trial_numerical%accepted_trajectory_direction%requested = refresh_tangent
    trial_numerical%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD

    select type (typed_forcing => forcing)
    type is (fmr_b110_physical_forcing_t)
      call backend%run_trial(column, template, parameters, committed, typed_forcing, trial_numerical, &
           window%t0, window%t1, self%origin_checkpoint, self%trial_result, self%candidate, self%diagnostics, &
           trusted_prepared_parameters=trusted_prepared_parameters)
    class default
      status = GW_SWAP_PARTICIPANT_FORCING_FAILED
      return
    end select

    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then
      if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      call invalidate_tangent_cache(self)
      status = GW_SWAP_PARTICIPANT_TRIAL_FAILED
      return
    end if

    duration_day = window%t1 - window%t0
    qbot_mean_cm_per_day = -self%trial_result%bottom_outward_exchange_native / duration_day
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day, &
         trial%q_swap_m_per_s, interface_status)
    if (interface_status /= GW_INTERFACE_OK .or. .not. ieee_is_finite(trial%q_swap_m_per_s)) then
      call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      call invalidate_tangent_cache(self)
      status = GW_SWAP_PARTICIPANT_EXCHANGE_FAILED
      return
    end if

    if (refresh_tangent) then
      if (accepted_head_response_tangent(self%trial_result, window)) then
        dq_swap_dh_per_s = -self%trial_result%accepted_trajectory_direction%accepted_bottom_exchange_derivative / &
             (duration_day * DAY_TO_S)
        if (ieee_is_finite(dq_swap_dh_per_s)) then
          trial%response_tangent_available = .true.
          trial%dq_swap_dh_per_s = dq_swap_dh_per_s
          trial%response_tangent_reused = .false.
          trial%response_tangent_age = 0
          trial%response_tangent_refresh_head_m = prescribed_head_m
          trial%response_tangent_provenance = 'accepted-trajectory-fresh'
          if (self%tangent_cache_enabled) then
            self%tangent_cache_valid = .true.
            self%tangent_cache_value = dq_swap_dh_per_s
            self%tangent_cache_refresh_head_m = prescribed_head_m
            self%tangent_cache_age = 0
            self%tangent_cache_lineage_id = self%origin_lineage_id
            self%tangent_cache_revision = self%origin_revision
            self%tangent_cache_t0 = window%t0
            self%tangent_cache_t1 = window%t1
            self%tangent_cache_fresh_count = self%tangent_cache_fresh_count + 1
          end if
        else
          call invalidate_tangent_cache(self)
        end if
      else
        call invalidate_tangent_cache(self)
      end if
    else
      if (self%tangent_cache_valid .and. ieee_is_finite(self%tangent_cache_value)) then
        self%tangent_cache_age = self%tangent_cache_age + 1
        self%tangent_cache_reuse_count = self%tangent_cache_reuse_count + 1
        trial%response_tangent_available = .true.
        trial%dq_swap_dh_per_s = self%tangent_cache_value
        trial%response_tangent_reused = .true.
        trial%response_tangent_age = self%tangent_cache_age
        trial%response_tangent_refresh_head_m = self%tangent_cache_refresh_head_m
        trial%response_tangent_provenance = 'same-origin-cache'
      else
        call invalidate_tangent_cache(self)
      end if
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

  subroutine fmr_swap_abandon_origin(self, status)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    integer, intent(out) :: status

    status = GW_SWAP_PARTICIPANT_CANDIDATE_BUSY
    if (self%live_candidate .or. self%candidate%ready()) return
    self%origin_captured = .false.
    call invalidate_tangent_cache(self)
    self%origin_lineage_id = 0_int64
    self%origin_revision = -1_int64
    self%origin_time = 0.0_real64
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine fmr_swap_abandon_origin

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
    call invalidate_tangent_cache(self)
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

  logical function accepted_head_response_tangent(result, window) result(valid)
    type(kernel_result_t), intent(in) :: result
    type(groundwater_coupling_window_t), intent(in) :: window

    valid = .false.
    if (.not. result%accepted_trajectory_direction%requested) return
    if (.not. result%accepted_trajectory_direction%available) return
    if (result%accepted_trajectory_direction%control_coordinate /= SW_STEP_CONTROL_BOTTOM_HEAD) return
    if (result%accepted_trajectory_direction%accepted_steps <= 0) return
    if (result%accepted_trajectory_direction%additional_full_nonlinear_solves /= 0) return
    if (.not. ieee_is_finite(result%accepted_trajectory_direction%accepted_bottom_exchange_derivative)) return
    if (.not. same_time(result%accepted_trajectory_direction%origin_t0, window%t0)) return
    if (.not. same_time(result%accepted_trajectory_direction%accepted_t1, window%t1)) return
    valid = .true.
  end function accepted_head_response_tangent

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

  subroutine fmr_swap_configure_tangent_cache(self, enabled, head_limit_m, max_age, status)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    logical, intent(in) :: enabled
    real(real64), intent(in), optional :: head_limit_m
    integer, intent(in), optional :: max_age
    integer, intent(out), optional :: status
    integer :: local_status

    local_status = FMR_TANGENT_CACHE_OK
    if (present(head_limit_m)) then
      if (.not. ieee_is_finite(head_limit_m) .or. head_limit_m < 0.0_real64) &
           local_status = FMR_TANGENT_CACHE_INVALID_CONFIG
    end if
    if (present(max_age)) then
      if (max_age < 1) local_status = FMR_TANGENT_CACHE_INVALID_CONFIG
    end if
    if (local_status /= FMR_TANGENT_CACHE_OK) then
      if (present(status)) status = local_status
      return
    end if

    self%tangent_cache_enabled = enabled
    if (present(head_limit_m)) self%tangent_cache_head_limit_m = head_limit_m
    if (present(max_age)) self%tangent_cache_max_age = max_age
    call invalidate_tangent_cache(self)
    self%tangent_cache_fresh_count = 0
    self%tangent_cache_reuse_count = 0
    if (present(status)) status = local_status
  end subroutine fmr_swap_configure_tangent_cache

  subroutine fmr_swap_tangent_cache_counts(self, fresh_count, reuse_count)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    integer, intent(out) :: fresh_count, reuse_count
    fresh_count = self%tangent_cache_fresh_count
    reuse_count = self%tangent_cache_reuse_count
  end subroutine fmr_swap_tangent_cache_counts

  subroutine invalidate_tangent_cache(self)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    self%tangent_cache_valid = .false.
    self%tangent_cache_value = 0.0_real64
    self%tangent_cache_refresh_head_m = 0.0_real64
    self%tangent_cache_age = 0
    self%tangent_cache_lineage_id = 0_int64
    self%tangent_cache_revision = -1_int64
    self%tangent_cache_t0 = 0.0_real64
    self%tangent_cache_t1 = 0.0_real64
  end subroutine invalidate_tangent_cache

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function same_time

end module mod_fmr_groundwater_swap_participant
