from pathlib import Path

p = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
s = p.read_text()

MARKER = 'F-PM14 drainage response runtime composition'
if MARKER in s:
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(
            f'F-PM14 checked transform failed: expected exactly one occurrence, got {count}:\n{old[:220]}'
        )
    s = s.replace(old, new, 1)


# Reuse the frozen process hydraulic view seam and the F-PM14 response dispatcher.
# Do not add a second transaction-state-to-hydraulic-view implementation.
replace_once(
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
""",
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, fmr_drainage_response_configuration_valid, &
       FMR_DRAIN_BIND_OK
""",
)

# Immutable response/preparation data stay with the physical parameter set.
replace_once(
"""    logical :: soil_temperature_active = .false.
    type(snow_parameters_t), allocatable :: snow
""",
"""    logical :: soil_temperature_active = .false.
    ! F-PM14 drainage response runtime composition. Immutable response and
    ! prepared geometry data belong to parameters, never to persistent state.
    logical :: drainage_response_active = .false.
    type(fmr_drainage_response_level_parameters_t), allocatable :: drainage_response_levels(:)
    type(snow_parameters_t), allocatable :: snow
""",
)

# Dynamic interval controls remain separate from immutable parameters.
replace_once(
"""    real(real64), allocatable :: drainage_flux_by_level(:,:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
""",
"""    real(real64), allocatable :: drainage_flux_by_level(:,:)
    type(fmr_drainage_response_level_control_t), allocatable :: drainage_response_controls(:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
""",
)

# Trial-local diagnostics. The binding itself never commits or publishes mass.
replace_once(
"""    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
  end type fmr_serialized_physical_observation_t
""",
"""    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
    logical :: drainage_response_active = .false.
    integer :: drainage_response_evaluations = 0
    logical :: drainage_response_mass_accounted_in_trial = .false.
    real(real64) :: drainage_response_signed_exchange_native = 0.0_real64
    type(fmr_drainage_response_diagnostics_t) :: drainage_response
  end type fmr_serialized_physical_observation_t
""",
)

# Response qdra and controls are worker/backend scratch, not column state.
replace_once(
"""    real(real64), pointer :: qdra(:,:) => null()
    real(real64), pointer :: qssdi(:) => null()
""",
"""    real(real64), pointer :: qdra(:,:) => null()
    logical :: drainage_response_active = .false.
    type(fmr_drainage_response_level_parameters_t), allocatable :: drainage_response_levels(:)
    type(fmr_drainage_response_level_control_t), allocatable :: drainage_response_controls(:)
    type(fmr_drainage_response_diagnostics_t) :: drainage_response_diagnostics
    integer :: drainage_response_evaluations = 0
    real(real64), pointer :: qssdi(:) => null()
""",
)

# Frozen fixed-weir runtime remains an independent admitted route. F-PM14 does
# not silently compose the two drainage ownership models.
replace_once(
"""    if (self%model%fixed_weir_surface_water_active) then
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
""",
"""    if (self%model%fixed_weir_surface_water_active) then
      if (parameters%drainage_response_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
""",
)

# Execution admission binds the declared active feature to the configured
# worker-local parameter payload and fails closed for mixed fixed-weir use.
replace_once(
"""      if (parameters%soil_temperature_active) then
        ok = ok .and. .not. parameters%snow_active .and. self%soil_temperature_active .and. &
             allocated(parameters%soil_temperature)
        if (ok) ok = parameters%soil_temperature%ready() .and. &
             parameters%soil_temperature%node_count() == parameters%active_nodes
      else
        ok = ok .and. .not. allocated(parameters%soil_temperature) .and. .not. self%soil_temperature_active
      end if
""",
"""      if (parameters%soil_temperature_active) then
        ok = ok .and. .not. parameters%snow_active .and. self%soil_temperature_active .and. &
             allocated(parameters%soil_temperature)
        if (ok) ok = parameters%soil_temperature%ready() .and. &
             parameters%soil_temperature%node_count() == parameters%active_nodes
      else
        ok = ok .and. .not. allocated(parameters%soil_temperature) .and. .not. self%soil_temperature_active
      end if
      if (parameters%drainage_response_active) then
        ok = ok .and. self%drainage_response_active .and. allocated(parameters%drainage_response_levels) .and. &
             allocated(self%drainage_response_levels) .and. .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0 .and. &
             size(parameters%drainage_response_levels) == size(self%drainage_response_levels)
      else
        ok = ok .and. .not. self%drainage_response_active .and. &
             .not. allocated(parameters%drainage_response_levels) .and. &
             .not. allocated(self%drainage_response_levels)
      end if
""",
)

# Configure worker-local immutable parameter scratch. No dynamic process state
# is introduced; prepared geometry is copied by intrinsic derived-type assignment.
replace_once(
"""      self%root_extraction_active = parameters%root_extraction_active
      self%snow_active = parameters%snow_active
      self%soil_temperature_active = parameters%soil_temperature_active
""",
"""      self%root_extraction_active = parameters%root_extraction_active
      self%snow_active = parameters%snow_active
      self%soil_temperature_active = parameters%soil_temperature_active
      self%drainage_response_active = parameters%drainage_response_active
      if (allocated(self%drainage_response_levels)) deallocate(self%drainage_response_levels)
      if (parameters%drainage_response_active .and. allocated(parameters%drainage_response_levels)) then
        allocate(self%drainage_response_levels(size(parameters%drainage_response_levels)))
        self%drainage_response_levels = parameters%drainage_response_levels
      end if
""",
)

# Interval/retry scratch is reset before forcing admission.
replace_once(
"""    self%forcing_admitted = .false.
    self%last_observation = fmr_serialized_physical_observation_t()
""",
"""    self%forcing_admitted = .false.
    self%drainage_response_evaluations = 0
    self%drainage_response_diagnostics = fmr_drainage_response_diagnostics_t()
    if (allocated(self%drainage_response_controls)) deallocate(self%drainage_response_controls)
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%drainage_response_active = self%drainage_response_active
""",
)

# Active response mode takes controls, not a precomputed qdra field. Inactive
# mode preserves the exact legacy/canonical forcing contract.
replace_once(
"""    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%drainage_flux_by_level) .or. .not. allocated(forcing%subsurface_irrigation_source) .or. &
          .not. allocated(forcing%root_extraction_sink)) return
      if (size(forcing%drainage_flux_by_level,1) <= 0 .or. size(forcing%drainage_flux_by_level,2) /= n .or. &
          size(forcing%subsurface_irrigation_source) /= n .or. size(forcing%root_extraction_sink) /= n) return
""",
"""    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%subsurface_irrigation_source) .or. .not. allocated(forcing%root_extraction_sink)) return
      if (size(forcing%subsurface_irrigation_source) /= n .or. size(forcing%root_extraction_sink) /= n) return
      if (self%drainage_response_active) then
        if (allocated(forcing%drainage_flux_by_level) .or. .not. allocated(self%drainage_response_levels) .or. &
            .not. allocated(forcing%drainage_response_controls)) return
        if (.not. fmr_drainage_response_configuration_valid(self%drainage_response_levels, &
             forcing%drainage_response_controls, n)) return
      else
        if (.not. allocated(forcing%drainage_flux_by_level) .or. allocated(forcing%drainage_response_controls)) return
        if (size(forcing%drainage_flux_by_level,1) <= 0 .or. size(forcing%drainage_flux_by_level,2) /= n) return
      end if
""",
)

replace_once(
"""      if (associated(self%qdra)) deallocate(self%qdra)
      if (associated(self%qssdi)) deallocate(self%qssdi)
      if (associated(self%qrot)) deallocate(self%qrot)
      allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n), self%qssdi(n), self%qrot(n))
      self%qdra = forcing%drainage_flux_by_level
      self%qssdi = forcing%subsurface_irrigation_source
""",
"""      if (associated(self%qdra)) deallocate(self%qdra)
      if (associated(self%qssdi)) deallocate(self%qssdi)
      if (associated(self%qrot)) deallocate(self%qrot)
      if (self%drainage_response_active) then
        allocate(self%qdra(size(self%drainage_response_levels),n))
        self%qdra = 0.0_real64
        allocate(self%drainage_response_controls(size(forcing%drainage_response_controls)))
        self%drainage_response_controls = forcing%drainage_response_controls
      else
        allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))
        self%qdra = forcing%drainage_flux_by_level
      end if
      allocate(self%qssdi(n), self%qrot(n))
      self%qssdi = forcing%subsurface_irrigation_source
""",
)

# Preserve active-route visibility across the observation reset at each advance.
replace_once(
"""    call populate_snow_observation(self)
    call populate_fixed_weir_surface_water_observation(self)
    snow_event_applied_this_call = .false.
""",
"""    call populate_snow_observation(self)
    call populate_fixed_weir_surface_water_observation(self)
    self%last_observation%drainage_response_active = self%drainage_response_active
    snow_event_applied_this_call = .false.
""",
)

# Source/sink pointers must be bound only after the response has been evaluated
# from the exact solver base state used by this transactional substep.
replace_once(
"""    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    if (self%root_extraction_active) then
      allocate(source_sink_root_zero(size(self%qrot)))
      source_sink_root_zero = 0.0_real64
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, source_sink_root_zero)
      call bind_b110_root_sink_provider(self%root_sink, self%qrot)
    else
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)
    end if
    request%parameters => self%soil_parameters
    request%evaluation%constitutive => self%constitutive
    request%evaluation%source_sink => self%source_sink
    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink
    request%evaluation%top_boundary => self%top_boundary
    request%step_duration = step_duration
""",
"""    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    request%parameters => self%soil_parameters
    request%step_duration = step_duration
""",
)

# Hydraulic view is built once from request%base_state when either drainage or
# soil-temperature coupling needs it. This is the canonical solver/process seam.
replace_once(
"""      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
        call build_process_hydraulic_view(request%base_state, hydraulic_start, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
      else
        if (allocated(physical%soil_temperature)) return
      end if
    class default
      return
    end select
    call bind_b110_serialized_legacy_context(request, context_ok)
""",
"""      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
      else
        if (allocated(physical%soil_temperature)) return
      end if
      if (self%soil_temperature_active .or. self%drainage_response_active) then
        call build_process_hydraulic_view(request%base_state, hydraulic_start, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
      end if
    class default
      return
    end select

    if (self%drainage_response_active) then
      call evaluate_fmr_drainage_response_bottom_lumped(self%drainage_response_levels, self%drainage_response_controls, &
           hydraulic_start, self%qdra, self%drainage_response_diagnostics)
      self%drainage_response_evaluations = self%drainage_response_evaluations + 1
      self%last_observation%drainage_response_evaluations = self%drainage_response_evaluations
      self%last_observation%drainage_response = self%drainage_response_diagnostics
      if (self%drainage_response_diagnostics%status /= FMR_DRAIN_BIND_OK) return
    end if

    if (self%root_extraction_active) then
      allocate(source_sink_root_zero(size(self%qrot)))
      source_sink_root_zero = 0.0_real64
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, source_sink_root_zero)
      call bind_b110_root_sink_provider(self%root_sink, self%qrot)
    else
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)
    end if
    request%evaluation%constitutive => self%constitutive
    request%evaluation%source_sink => self%source_sink
    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink
    request%evaluation%top_boundary => self%top_boundary

    call bind_b110_serialized_legacy_context(request, context_ok)
""",
)

# Trial mass accounting already owns qdra. Publish only a trial-local receipt;
# transaction acceptance/commit authority remains outside this model.
replace_once(
"""    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, outcome%mass_in, outcome%mass_out)
    outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration
""",
"""    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, outcome%mass_in, outcome%mass_out)
    if (self%drainage_response_active) then
      self%last_observation%drainage_response_mass_accounted_in_trial = .true.
      self%last_observation%drainage_response_signed_exchange_native = &
           self%drainage_response_diagnostics%aggregate%signed_soil_to_drain_rate * step_duration
    end if
    outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration
""",
)

# Guard against accidentally weakening the two independent owner routes.
if 'if (parameters%drainage_response_active) then' not in s:
    raise SystemExit('F-PM14 checked transform failed: fixed-weir conflict guard not installed')
if 'build_fmr_process_hydraulic_view' in s:
    raise SystemExit('F-PM14 checked transform failed: duplicate hydraulic-view builder survived')
if 'drainage_response_mass_accounted_in_trial' not in s:
    raise SystemExit('F-PM14 checked transform failed: trial mass-accounting receipt missing')

p.write_text(s)
