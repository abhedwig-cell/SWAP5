from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
expected_blob = '21e0e4229f202f1a3a74c4da004aa32a2c855f03'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'EB-I18R backend blob precondition failed: {actual_blob} != {expected_blob}')

text = path.read_text()


def once(old: str, new: str, label: str) -> None:
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'EB-I18R backend patch anchor {label!r} matched {n} times')
    text = text.replace(old, new, 1)


once(
"""  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF
""",
"""  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF
""",
'import attempt context')

once(
"""  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
""",
"""  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
""",
'import bottom thermal carrier')

once(
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
""",
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_soil_temperature_contract, only: soil_temperature_at_node
""",
'import bottom temperature accessor')

once(
"""    type(fmr_drainage_response_diagnostics_t) :: drainage_response
  end type fmr_serialized_physical_observation_t

  type, extends(kernel_model_t) :: fmr_serialized_reference_model_t
""",
"""    type(fmr_drainage_response_diagnostics_t) :: drainage_response
  end type fmr_serialized_physical_observation_t

  ! Worker-local transactional scratch for thermal transfer provenance. This is
  ! attempt context, never compact committed column state.
  type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t
    logical :: bottom_thermal_active = .false.
    logical :: bottom_thermal_valid = .true.
    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier
  end type fmr_serialized_attempt_context_t

  type, extends(kernel_model_t) :: fmr_serialized_reference_model_t
""",
'attempt context type')

once(
"""    type(fixed_weir_surface_water_result_t) :: fixed_weir_surface_water_result
    type(fmr_serialized_physical_observation_t) :: last_observation
""",
"""    type(fixed_weir_surface_water_result_t) :: fixed_weir_surface_water_result
    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier
    logical :: bottom_thermal_carrier_active = .false.
    logical :: bottom_thermal_carrier_valid = .true.
    type(fmr_serialized_physical_observation_t) :: last_observation
""",
'model thermal scratch fields')

once(
"""    procedure :: temporal_error => fmr_serialized_temporal_identity
  end type fmr_serialized_reference_model_t
""",
"""    procedure :: temporal_error => fmr_serialized_temporal_identity
    procedure :: capture_attempt_context => fmr_serialized_capture_attempt_context
    procedure :: restore_attempt_context => fmr_serialized_restore_attempt_context
  end type fmr_serialized_reference_model_t
""",
'model rollback methods')

once(
"""    type(fmr_serialized_reference_model_t) :: model
    type(kernel_executor_t) :: kernel
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
    procedure, public :: observation => fmr_serialized_backend_observation
""",
"""    type(fmr_serialized_reference_model_t) :: model
    type(kernel_executor_t) :: kernel
    logical :: initialized = .false.
    logical :: bottom_thermal_requested = .false.
    type(fmr_bottom_thermal_candidate_t) :: bottom_thermal_candidate
  contains
    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
    procedure, public :: observation => fmr_serialized_backend_observation
    procedure, public :: set_bottom_thermal_carrier_enabled => fmr_serialized_backend_set_bottom_thermal_carrier_enabled
    procedure, public :: bottom_thermal_snapshot => fmr_serialized_backend_bottom_thermal_snapshot
""",
'backend thermal API')

once(
"""    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    call self%clear_fixed_weir_surface_water()
""",
"""    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    self%bottom_thermal_requested = .false.
    call self%model%bottom_thermal_carrier%clear()
    call self%bottom_thermal_candidate%clear()
    call self%clear_fixed_weir_surface_water()
""",
'backend initialization')

once(
"""  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water(self, parameters, forcing, numerical, ok)
""",
"""  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    logical, intent(in) :: enabled
    self%bottom_thermal_requested = enabled
    call self%bottom_thermal_candidate%clear()
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
  end subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled

  function fmr_serialized_backend_bottom_thermal_snapshot(self) result(candidate)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_bottom_thermal_candidate_t) :: candidate
    call self%bottom_thermal_candidate%copy_to(candidate)
  end function fmr_serialized_backend_bottom_thermal_snapshot

  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water(self, parameters, forcing, numerical, ok)
""",
'backend thermal methods')

once(
"""    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    self%model%temporal_indicator_history_enabled = .false.
""",
"""    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    logical :: bottom_thermal_ok

    call self%bottom_thermal_candidate%clear()
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    self%model%temporal_indicator_history_enabled = .false.
""",
'run trial scratch reset')

once(
"""    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
  end subroutine fmr_serialized_backend_run_trial
""",
"""    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
    if (self%bottom_thermal_requested .and. parameters%soil_temperature_active .and. &
        self%model%state_profile_admitted .and. config%max_committed_substeps <= huge(0)/2) then
      call self%model%bottom_thermal_carrier%initialize(2 * config%max_committed_substeps, bottom_thermal_ok)
      self%model%bottom_thermal_carrier_active = bottom_thermal_ok
      self%model%bottom_thermal_carrier_valid = bottom_thermal_ok
    end if
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &
        result%completed .and. candidate%ready()) then
      call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &
           bottom_thermal_ok)
      if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()
    end if
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
  end subroutine fmr_serialized_backend_run_trial
""",
'run trial materialization')

once(
"""  logical function fmr_serialized_execution_admitted(self, parameters, numerical_config)
""",
"""  subroutine fmr_serialized_capture_attempt_context(self, context)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context

    allocate(fmr_serialized_attempt_context_t :: context)
    select type (typed => context)
    type is (fmr_serialized_attempt_context_t)
      typed%bottom_thermal_active = self%bottom_thermal_carrier_active
      typed%bottom_thermal_valid = self%bottom_thermal_carrier_valid
      call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)
    end select
  end subroutine fmr_serialized_capture_attempt_context

  subroutine fmr_serialized_restore_attempt_context(self, context)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context

    select type (typed => context)
    type is (fmr_serialized_attempt_context_t)
      self%bottom_thermal_carrier_active = typed%bottom_thermal_active
      self%bottom_thermal_carrier_valid = typed%bottom_thermal_valid
      call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)
    class default
      self%bottom_thermal_carrier_active = .false.
      self%bottom_thermal_carrier_valid = .false.
      call self%bottom_thermal_carrier%clear()
    end select
  end subroutine fmr_serialized_restore_attempt_context

  logical function fmr_serialized_execution_admitted(self, parameters, numerical_config)
""",
'attempt context implementations')

once(
"""    real(real64), allocatable, target :: source_sink_root_zero(:)
    real(real64) :: step_duration
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok
    integer :: soil_temperature_status
""",
"""    real(real64), allocatable, target :: source_sink_root_zero(:)
    real(real64) :: step_duration, bottom_temperature_start_c
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok
    logical :: bottom_temperature_start_available
    integer :: soil_temperature_status, bottom_temperature_status
""",
'advance thermal declarations')

once(
"""    self%last_observation%soil_temperature_active = self%soil_temperature_active
    self%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    if (.not. self%temporal_indicator_history_enabled) then
""",
"""    self%last_observation%soil_temperature_active = self%soil_temperature_active
    self%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    bottom_temperature_start_c = 0.0_real64
    bottom_temperature_start_available = .false.
    if (.not. self%temporal_indicator_history_enabled) then
""",
'advance thermal initialization')

once(
"""      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
      else
""",
"""      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
        if (self%bottom_thermal_carrier_active) then
          call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, bottom_temperature_start_c, &
               bottom_temperature_status)
          bottom_temperature_start_available = bottom_temperature_status == SOIL_TEMP_OK
        end if
      else
""",
'bottom donor start temperature')

once(
"""    outcome%bottom_interface_exchange_available = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%solver_ok = .true.
  end subroutine fmr_serialized_advance

  subroutine account_external_fluxes(self, step_duration, solver_top_flux, bottom_flux, snow_event_applied, &
""",
"""    outcome%bottom_interface_exchange_available = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (self%bottom_thermal_carrier_active .and. self%bottom_thermal_carrier_valid) then
      call record_bottom_thermal_sample(self, state, t0, t1, outcome%bottom_outward_exchange_native, &
           bottom_temperature_start_c, bottom_temperature_start_available)
    end if
    outcome%solver_ok = .true.
  end subroutine fmr_serialized_advance

  subroutine record_bottom_thermal_sample(self, state, t0, t1, outward_exchange, start_temperature_c, &
                                          start_temperature_available)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64), intent(in) :: t0, t1, outward_exchange, start_temperature_c
    logical, intent(in) :: start_temperature_available
    real(real64) :: end_temperature_c
    integer :: temperature_status
    logical :: appended

    if (.not. self%bottom_thermal_carrier_active .or. .not. self%bottom_thermal_carrier_valid) return
    appended = .false.
    if (outward_exchange > 0.0_real64) then
      if (.not. start_temperature_available) then
        self%bottom_thermal_carrier_valid = .false.
        return
      end if
      select type (physical => state)
      class is (fmr_b110_physical_state_t)
        if (.not. allocated(physical%soil_temperature)) then
          self%bottom_thermal_carrier_valid = .false.
          return
        end if
        call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, end_temperature_c, temperature_status)
        if (temperature_status /= SOIL_TEMP_OK) then
          self%bottom_thermal_carrier_valid = .false.
          return
        end if
      class default
        self%bottom_thermal_carrier_valid = .false.
        return
      end select
      call self%bottom_thermal_carrier%append_local(t0, t1, outward_exchange, start_temperature_c, end_temperature_c, appended)
    else if (outward_exchange < 0.0_real64) then
      call self%bottom_thermal_carrier%append_external_incomplete(t0, t1, outward_exchange, appended)
    else
      call self%bottom_thermal_carrier%append_zero(t0, t1, appended)
    end if
    if (.not. appended) self%bottom_thermal_carrier_valid = .false.
  end subroutine record_bottom_thermal_sample

  subroutine account_external_fluxes(self, step_duration, solver_top_flux, bottom_flux, snow_event_applied, &
""",
'record accepted-route thermal sample')

required_preservation = [
    'use mod_fmr_drainage_response_binding',
    'logical :: drainage_response_active = .false.',
    'parameters%bottom_mode == 2',
    'self%bottom_mode /= 2',
    'evaluate_temporal_history_service',
]
for marker in required_preservation:
    if marker not in text:
        raise SystemExit(f'EB-I18R backend preservation marker lost: {marker}')

path.write_text(text)
print('EB_I18R_CURRENT_BACKEND_SURGICAL_PATCH=PASS')
print('EB_I18R_DRAINAGE_MODE2_TEMPORAL_PRESERVATION=PASS')
