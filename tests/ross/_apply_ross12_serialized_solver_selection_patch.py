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
        """  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
""",
        """  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_fmr_rossfast_solver_selection_binding, only: fmr_rossfast_solver_selection_binding_t, &
       FMR_ROSSFAST_BIND_OK, FMR_ROSSFAST_BIND_INTERNAL_ERROR
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

    call self%model%soil_water_selection%configure('', selection_ok, selection_status)
    if (.not. selection_ok .or. selection_status /= FMR_ROSSFAST_BIND_OK) &
      error stop 'F-ROSS12 serialized backend: Reference default selection failed'
    self%model%top_boundary => top_boundary
""",
    ),
    (
        """  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
""",
        """  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_configure_soil_water_model(self, requested_model_key, ok, status, asset_root, material_id)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    character(len=*), intent(in) :: requested_model_key
    logical, intent(out) :: ok
    integer, intent(out) :: status
    character(len=*), intent(in), optional :: asset_root, material_id

    ok = .false.
    status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
    if (.not. self%initialized) return
    if (present(asset_root) .and. present(material_id)) then
      call self%model%soil_water_selection%configure(requested_model_key, ok, status, &
           asset_root=asset_root, material_id=material_id)
    else if (present(asset_root)) then
      call self%model%soil_water_selection%configure(requested_model_key, ok, status, asset_root=asset_root)
    else if (present(material_id)) then
      call self%model%soil_water_selection%configure(requested_model_key, ok, status, material_id=material_id)
    else
      call self%model%soil_water_selection%configure(requested_model_key, ok, status)
    end if
  end subroutine fmr_serialized_backend_configure_soil_water_model

  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
""",
    ),
    (
        """    ok = associated(self%top_boundary) .and. numerical_config%max_committed_substeps > 0 .and. &
         self%state_profile_admitted
""",
        """    ok = associated(self%top_boundary) .and. numerical_config%max_committed_substeps > 0 .and. &
         self%state_profile_admitted .and. self%soil_water_selection%execution_ready()
""",
    ),
    (
        """      if (parameters%drainage_response_active) then
        ok = ok .and. allocated(parameters%drainage_response_levels) .and. &
             .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0
      else
        ok = ok .and. .not. allocated(parameters%drainage_response_levels)
      end if
""",
        """      if (parameters%drainage_response_active) then
        ok = ok .and. allocated(parameters%drainage_response_levels) .and. &
             .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0
      else
        ok = ok .and. .not. allocated(parameters%drainage_response_levels)
      end if
      if (self%soil_water_selection%uses_rossfast()) then
        ok = ok .and. numerical_config%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE .and. &
             .not. numerical_config%accepted_trajectory_direction%requested .and. &
             .not. self%temporal_indicator_history_enabled .and. .not. self%fixed_weir_surface_water_active .and. &
             .not. parameters%root_extraction_active .and. .not. parameters%snow_active .and. &
             .not. parameters%soil_temperature_active .and. .not. parameters%drainage_response_active
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
        """    trajectory_accept_ok = .false.
    trajectory_solver_used = .false.
""",
        """    trajectory_accept_ok = .false.
    trajectory_solver_used = .false.
    rossfast_certificate_available = .false.
    rossfast_temporal_indicator = huge(0.0_real64)
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
      if (trajectory_request_ok) return
      call self%soil_water_selection%solve(request, solve_result)
      call self%soil_water_selection%temporal_certificate_snapshot(rossfast_certificate_available, &
           rossfast_temporal_indicator)
      outcome%temporal_certificate_available = rossfast_certificate_available
      outcome%temporal_indicator = rossfast_temporal_indicator
      self%last_observation%temporal_certificate_available = rossfast_certificate_available
      if (rossfast_certificate_available) then
        self%last_observation%temporal_normalized_indicator = rossfast_temporal_indicator
        self%last_observation%temporal_certificate_unavailable_reason = 'available'
      else
        self%last_observation%temporal_certificate_unavailable_reason = 'rossfast-certificate-unavailable'
      end if
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
        """    outcome%nonlinear_iterations = solve_result%diagnostics%nonlinear_iterations
    outcome%internal_retries = solve_result%diagnostics%internal_retries
    outcome%headcalc_calls = 1
""",
        """    outcome%nonlinear_iterations = solve_result%diagnostics%nonlinear_iterations
    outcome%internal_retries = solve_result%diagnostics%internal_retries
    if (self%soil_water_selection%uses_rossfast()) then
      outcome%headcalc_calls = 0
    else
      outcome%headcalc_calls = 1
    end if
""",
    ),
]

changed = 0
for old, new in changes:
    if new in text:
        print('F_ROSS12_ALREADY_PATCHED')
        continue
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F_ROSS12_PATCH_ANCHOR_MISMATCH count={count} anchor={old[:80]!r}')
    text = text.replace(old, new, 1)
    changed += 1

path.write_text(text)
print(f'F_ROSS12_SERIALIZED_SOLVER_SELECTION_PATCH_COUNT={changed}')
