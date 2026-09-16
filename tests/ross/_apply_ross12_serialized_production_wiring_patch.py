from pathlib import Path

path = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
text = path.read_text()

changes = [
    (
        """  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF
""",
        """  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF, &
       TX_TEMPORAL_MODEL_CERTIFICATE
""",
    ),
    (
        """  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
""",
        """  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
""",
    ),
    (
        """  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
""",
        """  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_rossfast_solver_selection_binding, only: fmr_rossfast_solver_selection_binding_t, &
       FMR_ROSSFAST_BIND_INTERNAL_ERROR
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX, &
       rossfast_d3r_full_duration_for_index
""",
    ),
    (
        """    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
""",
        """    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(fmr_rossfast_solver_selection_binding_t) :: soil_water_selection
""",
    ),
    (
        """    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
""",
        """    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: configure_soil_water_model => fmr_serialized_backend_configure_soil_water_model
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
""",
    ),
    (
        """  subroutine fmr_serialized_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    self%model%top_boundary => top_boundary
""",
        """  subroutine fmr_serialized_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    logical :: selection_ok
    integer :: selection_status
    self%initialized = .false.
    call self%model%soil_water_selection%configure('', selection_ok, selection_status)
    if (.not. selection_ok) return
    self%model%top_boundary => top_boundary
""",
    ),
    (
        """  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
""",
        """  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_configure_soil_water_model(self, requested_model_key, ok, status, &
                                                                asset_root, material_id)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    character(len=*), intent(in) :: requested_model_key
    logical, intent(out) :: ok
    integer, intent(out) :: status
    character(len=*), intent(in), optional :: asset_root, material_id

    ok = .false.
    status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
    if (.not. self%initialized) return
    self%initialized = .false.
    if (present(asset_root)) then
      if (present(material_id)) then
        call self%model%soil_water_selection%configure(requested_model_key, ok, status, &
             asset_root=asset_root, material_id=material_id)
      else
        call self%model%soil_water_selection%configure(requested_model_key, ok, status, asset_root=asset_root)
      end if
    else if (present(material_id)) then
      call self%model%soil_water_selection%configure(requested_model_key, ok, status, material_id=material_id)
    else
      call self%model%soil_water_selection%configure(requested_model_key, ok, status)
    end if
    self%initialized = ok
  end subroutine fmr_serialized_backend_configure_soil_water_model

  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
""",
    ),
    (
        """  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics)
""",
        """  logical function fmr_serialized_rossfast_parameter_matches(actual, expected) result(matches)
    real(real64), intent(in) :: actual, expected
    real(real64) :: tolerance
    tolerance = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(expected))
    matches = ieee_is_finite(actual) .and. abs(actual - expected) <= tolerance
  end function fmr_serialized_rossfast_parameter_matches

  logical function fmr_serialized_rossfast_preflight(self, template, parameters, forcing, config, t0, t1) result(ok)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(rossfast_d3r_material_t) :: material
    character(len=3) :: material_id
    real(real64) :: duration, tolerance, expected_m
    logical :: found, duration_admitted
    integer :: i, index

    ok = .false.
    if (.not. self%model%soil_water_selection%execution_ready()) return
    if (.not. self%model%soil_water_selection%uses_rossfast()) then
      ok = self%model%soil_water_selection%uses_reference()
      return
    end if
    if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE .or. &
        template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
    if (config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (config%transaction%retry_scale /= ROSSFAST_D3R_RETRY_SCALE .or. &
        config%transaction%max_retries /= ROSSFAST_D3R_MAX_FULL_INDEX) return
    if (.not. ieee_is_finite(config%transaction%mass_tolerance) .or. &
        config%transaction%mass_tolerance <= 0.0_real64 .or. &
        config%transaction%mass_tolerance > ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (config%accepted_trajectory_direction%requested) return
    if (self%bottom_thermal_requested .or. self%top_sensible_boundary_requested .or. &
        self%model%fixed_weir_surface_water_active) return
    if (parameters%active_nodes /= ROSSFAST_D3R_N_CELLS .or. parameters%bottom_mode /= 2) return
    if (.not. allocated(parameters%dz) .or. size(parameters%dz) /= ROSSFAST_D3R_N_CELLS) return
    if (any(.not. ieee_is_finite(parameters%dz)) .or. any(parameters%dz /= ROSSFAST_D3R_DZ_CM)) return
    if (.not. allocated(parameters%cofgen) .or. size(parameters%cofgen,1) < 9 .or. &
        size(parameters%cofgen,2) /= ROSSFAST_D3R_N_CELLS) return
    if (parameters%root_extraction_active .or. parameters%macropore_active .or. parameters%snow_active .or. &
        parameters%hysteresis_active .or. parameters%tabulated_hydraulics_active .or. &
        parameters%elasticity_active .or. parameters%frost_active .or. parameters%soil_temperature_active .or. &
        parameters%drainage_response_active) return
    if (parameters%swkimpl /= 0 .or. parameters%swsophy /= 0) return
    if (.not. allocated(forcing%drainage_flux_by_level) .or. &
        .not. allocated(forcing%subsurface_irrigation_source) .or. .not. allocated(forcing%root_extraction_sink)) return
    if (any(.not. ieee_is_finite(forcing%drainage_flux_by_level)) .or. &
        any(.not. ieee_is_finite(forcing%subsurface_irrigation_source)) .or. &
        any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
    if (any(forcing%drainage_flux_by_level /= 0.0_real64) .or. &
        any(forcing%subsurface_irrigation_source /= 0.0_real64) .or. &
        any(forcing%root_extraction_sink /= 0.0_real64)) return
    if (allocated(forcing%drainage_response_controls) .or. allocated(forcing%snow) .or. &
        allocated(forcing%soil_temperature)) return
    select type (top_boundary => self%model%top_boundary)
    type is (fixed_flux_top_boundary_provider_t)
      continue
    class default
      return
    end select

    material_id = self%model%soil_water_selection%selected_material_id()
    call rossfast_d3r_material_from_id(material_id, material, found)
    if (.not. found) return
    expected_m = 1.0_real64 - 1.0_real64 / material%n
    do i = 1, ROSSFAST_D3R_N_CELLS
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(1,i), material%theta_r)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(2,i), material%theta_s)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(3,i), material%ksatfit_cm_per_day)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(4,i), material%alpha_per_cm)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(5,i), material%lambda)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(6,i), material%n)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(7,i), expected_m)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(9,i), material%h_enpr_cm)) return
    end do

    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    duration_admitted = .false.
    do index = 0, ROSSFAST_D3R_MAX_FULL_INDEX
      duration = rossfast_d3r_full_duration_for_index(index)
      tolerance = 2.0_real64 * max(spacing(t0), spacing(t1), spacing(duration))
      if (abs((t1 - t0) - duration) <= tolerance) then
        duration_admitted = .true.
        exit
      end if
    end do
    if (.not. duration_admitted) return
    ok = .true.
  end function fmr_serialized_rossfast_preflight

  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics)
""",
    ),
    (
        """    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        column%template_id /= template%template_id .or. column%column_id <= 0_int64) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
""",
        """    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        column%template_id /= template%template_id .or. column%column_id <= 0_int64) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (.not. fmr_serialized_rossfast_preflight(self, template, parameters, forcing, config, t0, t1)) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
""",
    ),
    (
        """    logical :: trajectory_begin_ok, trajectory_request_ok, trajectory_stage_ok, trajectory_accept_ok
    logical :: trajectory_solver_used
    integer :: soil_temperature_status, bottom_temperature_status
""",
        """    logical :: trajectory_begin_ok, trajectory_request_ok, trajectory_stage_ok, trajectory_accept_ok
    logical :: trajectory_solver_used, rossfast_certificate_available
    real(real64) :: rossfast_temporal_indicator
    integer :: soil_temperature_status, bottom_temperature_status
""",
    ),
    (
        """    if (trajectory_request_ok) then
      call solve_with_accepted_step_direction(self%solver, request, self%workspace, direction_request, &
           solve_result, direction_result)
      trajectory_solver_used = .true.
      call stage_trajectory_step_result(self%trajectory_direction, direction_token, direction_result, trajectory_stage_ok)
    else
      call self%solver%solve(request, self%workspace, solve_result)
    end if
""",
        """    if (self%soil_water_selection%uses_rossfast()) then
      call self%soil_water_selection%solve(request, solve_result)
    else if (trajectory_request_ok) then
      call solve_with_accepted_step_direction(self%solver, request, self%workspace, direction_request, &
           solve_result, direction_result)
      trajectory_solver_used = .true.
      call stage_trajectory_step_result(self%trajectory_direction, direction_token, direction_result, trajectory_stage_ok)
    else
      call self%solver%solve(request, self%workspace, solve_result)
    end if
""",
    ),
    (
        """    outcome%headcalc_calls = 1
""",
        """    if (self%soil_water_selection%uses_rossfast()) then
      outcome%headcalc_calls = 0
    else
      outcome%headcalc_calls = 1
    end if
""",
    ),
    (
        """    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (self%temporal_indicator_history_enabled) then
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      if (.not. temporal_history_ok) return
    end if
""",
        """    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (self%soil_water_selection%uses_rossfast()) then
      call self%soil_water_selection%temporal_certificate_snapshot(rossfast_certificate_available, &
           rossfast_temporal_indicator)
      if (.not. rossfast_certificate_available .or. .not. ieee_is_finite(rossfast_temporal_indicator) .or. &
          rossfast_temporal_indicator < 0.0_real64) return
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = rossfast_temporal_indicator
      self%last_observation%temporal_certificate_available = .true.
      self%last_observation%temporal_normalized_indicator = rossfast_temporal_indicator
      self%last_observation%temporal_indicator_route = 'rossfast-model-certificate'
      self%last_observation%temporal_certificate_unavailable_reason = 'available'
    else if (self%temporal_indicator_history_enabled) then
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      if (.not. temporal_history_ok) return
    end if
""",
    ),
]

changed = 0
for old, new in changes:
    if new in text:
        print('ROSS12_ALREADY_PATCHED')
        continue
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'ROSS12_PATCH_ANCHOR_MISMATCH count={count}\nANCHOR:\n{old}')
    text = text.replace(old, new, 1)
    changed += 1

path.write_text(text)
print(f'ROSS12_SERIALIZED_PRODUCTION_PATCH_COUNT={changed}')
if changed != len(changes):
    raise SystemExit(f'ROSS12_PATCH_NOT_FRESH changed={changed} expected={len(changes)}')
