module mod_fmr_groundwater_surface_water_swap_participant
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, GW_INTERFACE_OK
  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_fixed_weir_surface_water_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED, FMR_DRAIN_BIND_OK
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  implicit none
  private

  integer, parameter, public :: FMR_GWSW_PARTICIPANT_OK = 0
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_PROFILE_NOT_ADMITTED = 2
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_ORIGIN_CAPTURE_FAILED = 3
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_ORIGIN_DRIFT = 4
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_CANDIDATE_BUSY = 5
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_FORCING_FAILED = 6
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_TRIAL_FAILED = 7
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_GROUNDWATER_EXCHANGE_FAILED = 8
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_FAILED = 9
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_MISMATCH = 10
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_PREFLIGHT_FAILED = 11
  integer, parameter, public :: FMR_GWSW_PARTICIPANT_COMMIT_FAILED = 12

  type, public :: fmr_groundwater_surface_water_trial_t
    logical :: valid = .false.
    real(real64) :: prescribed_groundwater_head_m = 0.0_real64
    real(real64) :: groundwater_q_swap_m_per_s = 0.0_real64
    real(real64) :: bottom_outward_exchange_cm = 0.0_real64
    real(real64) :: signed_soil_to_surface_exchange_cm = 0.0_real64
    real(real64) :: mean_signed_soil_to_surface_rate_cm_per_day = 0.0_real64
    integer :: accepted_substeps = 0
  end type fmr_groundwater_surface_water_trial_t

  type, public :: fmr_groundwater_surface_water_swap_participant_t
    private
    type(kernel_checkpoint_t) :: origin_checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: trial_result
    type(kernel_diagnostics_t) :: diagnostics
    integer(int64) :: origin_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    real(real64) :: origin_time = 0.0_real64
    real(real64) :: candidate_surface_exchange_cm = 0.0_real64
    logical :: origin_captured = .false.
    logical :: live_candidate = .false.
  contains
    procedure, public :: capture_origin => joint_capture_origin
    procedure, public :: trial_from_origin => joint_trial_from_origin
    procedure, public :: discard_candidate => joint_discard_candidate
    procedure, public :: abandon_origin => joint_abandon_origin
    procedure, public :: publication_ready => joint_publication_ready
    procedure, public :: commit_candidate => joint_commit_candidate
    procedure, public :: has_origin => joint_has_origin
    procedure, public :: has_live_candidate => joint_has_live_candidate
    procedure, public :: captured_lineage_id => joint_lineage_id
    procedure, public :: captured_revision => joint_revision
  end type fmr_groundwater_surface_water_swap_participant_t

  public :: fmr_groundwater_surface_water_profile_admitted

contains

  logical function fmr_groundwater_surface_water_profile_admitted(template, parameters, committed, surface_materializer) result(ok)
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_surface_water_head_forcing_materializer_t), intent(in) :: surface_materializer
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    ok = .false.
    if (.not. committed%ready() .or. .not. surface_materializer%ready()) return
    if (template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE) return
    if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
    if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
    if (parameters%bottom_mode /= 5) return
    if (.not. parameters%drainage_response_active) return
    if (parameters%drainage_qbot_smooth_freatic_projection) return
    if (.not. allocated(parameters%drainage_response_levels)) return
    if (size(parameters%drainage_response_levels) /= 1) return
    if (surface_materializer%level_count() /= 1) return
    if (parameters%drainage_response_levels(1)%variant /= FMR_DRAIN_VARIANT_EXTENDED_SIGNED) return
    if (parameters%root_extraction_active .or. parameters%macropore_active .or. parameters%snow_active .or. &
        parameters%hysteresis_active .or. parameters%elasticity_active .or. parameters%frost_active .or. &
        parameters%soil_temperature_active .or. parameters%tabulated_hydraulics_active .or. &
        parameters%black_evaporation_active .or. parameters%boesten_evaporation_active) return

    call committed%snapshot(snapshot, available)
    if (.not. available .or. .not. allocated(snapshot)) return
    select type (physical => snapshot)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      return
    type is (fmr_b110_physical_state_t)
      if (physical%active_nodes /= parameters%active_nodes) return
      if (allocated(physical%snow) .or. allocated(physical%soil_temperature)) return
    class default
      return
    end select
    ok = .true.
  end function fmr_groundwater_surface_water_profile_admitted

  subroutine joint_capture_origin(self, committed, status)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(inout) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    integer, intent(out) :: status
    logical :: available

    status = FMR_GWSW_PARTICIPANT_ORIGIN_CAPTURE_FAILED
    if (self%live_candidate) then
      status = FMR_GWSW_PARTICIPANT_CANDIDATE_BUSY
      return
    end if
    if (.not. committed%ready()) return
    call committed%capture_checkpoint(self%origin_checkpoint, available)
    if (.not. available .or. .not. self%origin_checkpoint%ready()) return
    call self%origin_checkpoint%current_time(self%origin_time, available)
    if (.not. available .or. .not. ieee_is_finite(self%origin_time)) return
    self%origin_lineage_id = self%origin_checkpoint%current_lineage_id()
    self%origin_revision = self%origin_checkpoint%origin_revision()
    if (self%origin_lineage_id <= 0_int64 .or. self%origin_revision < 0_int64) return
    self%origin_captured = .true.
    self%candidate_surface_exchange_cm = 0.0_real64
    status = FMR_GWSW_PARTICIPANT_OK
  end subroutine joint_capture_origin

  subroutine joint_trial_from_origin(self, backend, column, template, parameters, committed, surface_materializer, &
       numerical, datum, window, prescribed_groundwater_head_m, resolved_surface_heads_cm, trial, status)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_surface_water_head_forcing_materializer_t), intent(in) :: surface_materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_groundwater_head_m
    real(real64), intent(in) :: resolved_surface_heads_cm(:)
    type(fmr_groundwater_surface_water_trial_t), intent(out) :: trial
    integer, intent(out) :: status

    type(fmr_b110_physical_forcing_t) :: surface_forcing
    type(fmr_groundwater_head_forcing_materializer_t) :: groundwater_materializer
    type(fmr_serialized_physical_observation_t) :: observation
    class(canonical_forcing_t), allocatable :: combined_forcing
    real(real64) :: duration_day, qbot_mean_cm_per_day
    integer :: surface_status, groundwater_status, interface_status

    trial = fmr_groundwater_surface_water_trial_t()
    status = FMR_GWSW_PARTICIPANT_INVALID_REQUEST
    if (.not. self%origin_captured .or. .not. self%origin_checkpoint%ready()) return
    if (self%live_candidate) then
      status = FMR_GWSW_PARTICIPANT_CANDIDATE_BUSY
      return
    end if
    if (.not. window%valid() .or. .not. datum%valid()) return
    if (.not. ieee_is_finite(prescribed_groundwater_head_m)) return
    if (.not. same_time(window%t0, self%origin_time)) then
      status = FMR_GWSW_PARTICIPANT_ORIGIN_DRIFT
      return
    end if
    if (.not. origin_still_current(self, committed)) then
      status = FMR_GWSW_PARTICIPANT_ORIGIN_DRIFT
      return
    end if
    if (.not. fmr_groundwater_surface_water_profile_admitted(template, parameters, committed, surface_materializer)) then
      status = FMR_GWSW_PARTICIPANT_PROFILE_NOT_ADMITTED
      return
    end if

    call surface_materializer%materialize(resolved_surface_heads_cm, surface_forcing, surface_status)
    if (surface_status /= FMR_SW_HEAD_FORCING_OK) then
      status = FMR_GWSW_PARTICIPANT_FORCING_FAILED
      return
    end if
    call groundwater_materializer%initialize(surface_forcing)
    if (.not. groundwater_materializer%profile_admitted(parameters)) then
      status = FMR_GWSW_PARTICIPANT_PROFILE_NOT_ADMITTED
      return
    end if
    call groundwater_materializer%materialize(prescribed_groundwater_head_m, datum, combined_forcing, groundwater_status)
    if (groundwater_status /= GW_SWAP_FORCING_OK .or. .not. allocated(combined_forcing)) then
      status = FMR_GWSW_PARTICIPANT_FORCING_FAILED
      return
    end if

    select type (forcing => combined_forcing)
    type is (fmr_b110_physical_forcing_t)
      call backend%run_trial(column, template, parameters, committed, forcing, numerical, window%t0, window%t1, &
           self%origin_checkpoint, self%trial_result, self%candidate, self%diagnostics)
    class default
      status = FMR_GWSW_PARTICIPANT_FORCING_FAILED
      return
    end select

    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then
      if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      status = FMR_GWSW_PARTICIPANT_TRIAL_FAILED
      return
    end if

    duration_day = window%t1-window%t0
    qbot_mean_cm_per_day = -self%trial_result%bottom_outward_exchange_native/duration_day
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day, trial%groundwater_q_swap_m_per_s, interface_status)
    if (interface_status /= GW_INTERFACE_OK .or. .not. ieee_is_finite(trial%groundwater_q_swap_m_per_s)) then
      call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      status = FMR_GWSW_PARTICIPANT_GROUNDWATER_EXCHANGE_FAILED
      return
    end if

    observation = backend%observation()
    if (.not. observation%drainage_response_active .or. &
        .not. observation%drainage_response_mass_accounted_in_trial .or. &
        observation%drainage_response%status /= FMR_DRAIN_BIND_OK .or. &
        .not. observation%drainage_response_window_exchange_available .or. &
        .not. ieee_is_finite(observation%drainage_response_window_signed_exchange_native)) then
      call backend%discard_trial_candidate(self%candidate, self%diagnostics)
      status = FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_FAILED
      return
    end if

    self%candidate_surface_exchange_cm = observation%drainage_response_window_signed_exchange_native
    self%live_candidate = .true.
    trial%valid = .true.
    trial%prescribed_groundwater_head_m = prescribed_groundwater_head_m
    trial%bottom_outward_exchange_cm = self%trial_result%bottom_outward_exchange_native
    trial%signed_soil_to_surface_exchange_cm = self%candidate_surface_exchange_cm
    trial%mean_signed_soil_to_surface_rate_cm_per_day = self%candidate_surface_exchange_cm/duration_day
    trial%accepted_substeps = self%diagnostics%accepted_substeps
    status = FMR_GWSW_PARTICIPANT_OK
  end subroutine joint_trial_from_origin

  subroutine joint_discard_candidate(self, backend)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
    self%live_candidate = .false.
    self%candidate_surface_exchange_cm = 0.0_real64
  end subroutine joint_discard_candidate

  subroutine joint_abandon_origin(self, status)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(inout) :: self
    integer, intent(out) :: status
    status = FMR_GWSW_PARTICIPANT_CANDIDATE_BUSY
    if (self%live_candidate .or. self%candidate%ready()) return
    self%origin_captured = .false.
    self%origin_lineage_id = 0_int64
    self%origin_revision = -1_int64
    self%origin_time = 0.0_real64
    self%candidate_surface_exchange_cm = 0.0_real64
    status = FMR_GWSW_PARTICIPANT_OK
  end subroutine joint_abandon_origin

  logical function joint_publication_ready(self, committed, window, realized_surface_exchange_cm, tolerance_cm) result(ready)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: realized_surface_exchange_cm, tolerance_cm
    real(real64) :: candidate_t0,candidate_t1
    logical :: interval_available

    ready = .false.
    if (.not. self%origin_captured .or. .not. self%live_candidate) return
    if (.not. window%valid() .or. .not. committed%ready() .or. .not. self%candidate%ready()) return
    if (.not. ieee_is_finite(realized_surface_exchange_cm) .or. .not. ieee_is_finite(tolerance_cm) .or. tolerance_cm < 0.0_real64) return
    if (.not. origin_still_current(self, committed)) return
    if (self%candidate%current_lineage_id() /= self%origin_lineage_id) return
    if (self%candidate%origin_revision() /= self%origin_revision) return
    call self%candidate%origin_interval(candidate_t0,candidate_t1,interval_available)
    if (.not. interval_available) return
    if (.not. same_time(candidate_t0,window%t0) .or. .not. same_time(candidate_t1,window%t1)) return
    if (.not. self%trial_result%completed .or. .not. self%trial_result%mass%complete) return
    if (.not. self%trial_result%bottom_interface_exchange_available) return
    if (abs(realized_surface_exchange_cm-self%candidate_surface_exchange_cm) > tolerance_cm) return
    ready = .true.
  end function joint_publication_ready

  subroutine joint_commit_candidate(self, backend, committed, window, realized_surface_exchange_cm, tolerance_cm, did_commit, status)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(inout) :: self
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_committed_state_t), intent(inout) :: committed
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: realized_surface_exchange_cm, tolerance_cm
    logical, intent(out) :: did_commit
    integer, intent(out) :: status
    integer :: kernel_status

    did_commit = .false.
    status = FMR_GWSW_PARTICIPANT_PREFLIGHT_FAILED
    if (.not. ieee_is_finite(realized_surface_exchange_cm) .or. .not. ieee_is_finite(tolerance_cm) .or. tolerance_cm < 0.0_real64) return
    if (self%live_candidate .and. abs(realized_surface_exchange_cm-self%candidate_surface_exchange_cm) > tolerance_cm) then
      status = FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_MISMATCH
      return
    end if
    if (.not. self%publication_ready(committed,window,realized_surface_exchange_cm,tolerance_cm)) return

    call backend%commit_trial_candidate(committed,self%candidate,self%diagnostics,did_commit,kernel_status)
    if (.not. did_commit .or. kernel_status /= KERNEL_COMMIT_STATUS_COMMITTED) then
      did_commit = .false.
      status = FMR_GWSW_PARTICIPANT_COMMIT_FAILED
      return
    end if
    self%live_candidate = .false.
    self%origin_captured = .false.
    self%candidate_surface_exchange_cm = 0.0_real64
    status = FMR_GWSW_PARTICIPANT_OK
  end subroutine joint_commit_candidate

  logical function joint_has_origin(self) result(value)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    value = self%origin_captured
  end function joint_has_origin

  logical function joint_has_live_candidate(self) result(value)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    value = self%live_candidate .and. self%candidate%ready()
  end function joint_has_live_candidate

  integer(int64) function joint_lineage_id(self) result(value)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    value = self%origin_lineage_id
  end function joint_lineage_id

  integer(int64) function joint_revision(self) result(value)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    value = self%origin_revision
  end function joint_revision

  logical function origin_still_current(self, committed) result(current)
    class(fmr_groundwater_surface_water_swap_participant_t), intent(in) :: self
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64) :: committed_time
    logical :: available
    current = .false.
    if (.not. self%origin_captured .or. .not. committed%ready()) return
    if (committed%current_lineage_id() /= self%origin_lineage_id) return
    if (committed%current_revision() /= self%origin_revision) return
    call committed%current_time(committed_time,available)
    if (.not. available .or. .not. same_time(committed_time,self%origin_time)) return
    current = .true.
  end function origin_still_current

  logical function accepted_whole_window(result,candidate,window) result(valid)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64) :: candidate_t0,candidate_t1
    logical :: available
    valid = .false.
    if (.not. result%completed .or. .not. result%mass%complete .or. .not. candidate%ready()) return
    if (.not. result%bottom_interface_exchange_available) return
    if (.not. ieee_is_finite(result%bottom_outward_exchange_native) .or. .not. ieee_is_finite(result%terminal_bottom_outward_flux_native)) return
    if (.not. same_time(result%requested_t0,window%t0) .or. .not. same_time(result%requested_t1,window%t1) .or. &
        .not. same_time(result%completed_t,window%t1)) return
    call candidate%origin_interval(candidate_t0,candidate_t1,available)
    if (.not. available) return
    if (.not. same_time(candidate_t0,window%t0) .or. .not. same_time(candidate_t1,window%t1)) return
    valid = .true.
  end function accepted_whole_window

  pure logical function same_time(a,b) result(matches)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale=max(1.0_real64,abs(a),abs(b))
    matches=abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function same_time
end module mod_fmr_groundwater_surface_water_swap_participant
