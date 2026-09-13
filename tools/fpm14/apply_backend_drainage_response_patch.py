from pathlib import Path

p = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
s = p.read_text()

MARKER = 'F-PM14 drainage response runtime composition'
if MARKER in s:
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global s
    if s.count(old) != 1:
        raise SystemExit(f'F-PM14 checked transform failed: expected exactly one occurrence, got {s.count(old)}:\n{old[:180]}')
    s = s.replace(old, new, 1)

replace_once(
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
""",
"""  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view, &
       validate_process_hydraulic_view
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, fmr_drainage_response_configuration_valid, &
       FMR_DRAIN_BIND_OK
""")

replace_once(
"""    logical :: soil_temperature_active = .false.
    type(snow_parameters_t), allocatable :: snow
""",
"""    logical :: soil_temperature_active = .false.
    ! F-PM14 drainage response runtime composition. Immutable prepared response
    ! data live with the shared physical parameter set, never in column state.
    logical :: drainage_response_active = .false.
    type(fmr_drainage_response_level_parameters_t), allocatable :: drainage_response_levels(:)
    type(snow_parameters_t), allocatable :: snow
""")

replace_once(
"""    real(real64), allocatable :: drainage_flux_by_level(:,:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
""",
"""    real(real64), allocatable :: drainage_flux_by_level(:,:)
    ! Interval controls are separate from immutable response parameters.
    type(fmr_drainage_response_level_control_t), allocatable :: drainage_response_controls(:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
""")

replace_once(
"""    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
  end type fmr_serialized_physical_observation_t
""",
"""    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
    logical :: drainage_response_active = .false.
    integer :: drainage_response_evaluations = 0
    type(fmr_drainage_response_diagnostics_t) :: drainage_response
  end type fmr_serialized_physical_observation_t
""")

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
""")

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
             .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0
      else
        ok = ok .and. .not. self%drainage_response_active .and. &
             .not. allocated(parameters%drainage_response_levels)
      end if
""")

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
      if (parameters%drainage_response_active) then
        if (allocated(parameters%drainage_response_levels)) then
          allocate(self%drainage_response_levels(size(parameters%drainage_response_levels)))
          self%drainage_response_levels = parameters%drainage_response_levels
        end if
      end if
""")

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
""")

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
""")

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
""")

replace_once(
"""    call populate_snow_observation(self)
    call populate_fixed_weir_surface_water_observation(self)
    snow_event_applied_this_call = .false.
""",
"""    call populate_snow_observation(self)
    call populate_fixed_weir_surface_water_observation(self)
    self%last_observation%drainage_response_active = self%drainage_response_active
    snow_event_applied_this_call = .false.
""")

replace_once(
"""    step_duration = t1 - t0
    if (step_duration <= 0.0_real64) return
    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
""",
"""    step_duration = t1 - t0
    if (step_duration <= 0.0_real64) return
    if (self%drainage_response_active) then
      call build_fmr_process_hydraulic_view(state, hydraulic_start, hydraulic_view_ok)
      if (.not. hydraulic_view_ok) return
      call evaluate_fmr_drainage_response_bottom_lumped(self%drainage_response_levels, self%drainage_response_controls, &
           hydraulic_start, self%qdra, self%drainage_response_diagnostics)
      self%drainage_response_evaluations = self%drainage_response_evaluations + 1
      self%last_observation%drainage_response_evaluations = self%drainage_response_evaluations
      self%last_observation%drainage_response = self%drainage_response_diagnostics
      if (self%drainage_response_diagnostics%status /= FMR_DRAIN_BIND_OK) return
    end if
    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
""")

replace_once(
"""  subroutine populate_snow_observation(self)
""",
"""  subroutine build_fmr_process_hydraulic_view(state, hydraulic_view, ok)
    class(transaction_state_t), intent(in) :: state
    type(process_hydraulic_view_t), intent(out) :: hydraulic_view
    logical, intent(out) :: ok

    hydraulic_view = process_hydraulic_view_t()
    ok = .false.
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (physical%active_nodes <= 0 .or. .not. allocated(physical%pressure_head) .or. &
          .not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= physical%active_nodes .or. &
          size(physical%water_content) /= physical%active_nodes) return
      hydraulic_view%active_nodes = physical%active_nodes
      allocate(hydraulic_view%pressure_head(physical%active_nodes), hydraulic_view%water_content(physical%active_nodes))
      hydraulic_view%pressure_head = physical%pressure_head
      hydraulic_view%water_content = physical%water_content
      hydraulic_view%ponding_depth = physical%ponding_depth
      hydraulic_view%groundwater_level = physical%groundwater_level
      call validate_process_hydraulic_view(hydraulic_view, ok)
    class default
      return
    end select
  end subroutine build_fmr_process_hydraulic_view

  subroutine populate_snow_observation(self)
""")

replace_once(
"""    if (self%fixed_weir_surface_water_active) then
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
""".replace('self%model%', 'self%model%'),
"""    if (self%model%fixed_weir_surface_water_active) then
      if (parameters%drainage_response_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
""")

# The previous exact replacement is intentionally guarded by literal source;
# verify the fixed-weir conflict is present after transformation.
if 'if (parameters%drainage_response_active) then' not in s:
    raise SystemExit('F-PM14 checked transform failed: fixed-weir conflict guard not installed')

p.write_text(s)
