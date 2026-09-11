#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BACKEND=ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90'
RESTART=ROOT/'src/runtime/mod_fmr_restart_state_contract.f90'
EXPECTED_BACKEND='9af5a494526810324dc00706b444e448e770cba9'
EXPECTED_RESTART='f1359f97d02408d8b700b0c93fe961a6ba46742c'

def blob(path):
    return subprocess.check_output(['git','hash-object',str(path.relative_to(ROOT))],cwd=ROOT,text=True).strip()

def replace_once(text, old, new, label):
    n=text.count(old)
    if n != 1:
        raise SystemExit(f'FMR39 materializer anchor {label}: expected 1, found {n}')
    return text.replace(old,new,1)

if blob(BACKEND) != EXPECTED_BACKEND:
    raise SystemExit('FMR39 backend source drift before materialization')
if blob(RESTART) != EXPECTED_RESTART:
    raise SystemExit('FMR39 restart-contract source drift before materialization')

s=BACKEND.read_text()

s=replace_once(s,
"""  use mod_snow_process, only: snow_parameters_t, snow_state_t, snow_forcing_t, snow_flux_result_t, &
       snow_mass_contribution_t, snow_diagnostics_t, evaluate_snow_reference_call, SNOW_OK
""",
"""  use mod_snow_process, only: snow_parameters_t, snow_state_t, snow_forcing_t, snow_flux_result_t, &
       snow_mass_contribution_t, snow_diagnostics_t, evaluate_snow_reference_call, SNOW_OK
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, soil_temperature_parameters_t, &
       soil_temperature_numerical_config_t, soil_temperature_forcing_t, soil_temperature_state_t, &
       soil_temperature_workspace_t, soil_temperature_result_t, soil_temperature_diagnostics_t, &
       trial_restricted_soil_temperature, commit_soil_temperature_state
""",'imports')

s=replace_once(s,
"""    type(fmr_snow_runtime_state_t), allocatable :: snow
  contains
""",
"""    type(fmr_snow_runtime_state_t), allocatable :: snow
    type(soil_temperature_state_t), allocatable :: soil_temperature
  contains
""",'physical thermal state')

s=replace_once(s,
"""    logical :: frost_active = .false.
    type(snow_parameters_t), allocatable :: snow
  end type fmr_b110_physical_parameters_t
""",
"""    logical :: frost_active = .false.
    logical :: soil_temperature_active = .false.
    type(snow_parameters_t), allocatable :: snow
    type(soil_temperature_parameters_t), allocatable :: soil_temperature
  end type fmr_b110_physical_parameters_t
""",'thermal parameters')

s=replace_once(s,
"""    type(snow_forcing_t), allocatable :: snow
  end type fmr_b110_physical_forcing_t
""",
"""    type(snow_forcing_t), allocatable :: snow
    type(soil_temperature_forcing_t), allocatable :: soil_temperature
  end type fmr_b110_physical_forcing_t
""",'thermal forcing')

s=replace_once(s,
"""    type(snow_mass_contribution_t) :: snow_mass
  end type fmr_serialized_physical_observation_t
""",
"""    type(snow_mass_contribution_t) :: snow_mass
    logical :: soil_temperature_active = .false.
    logical :: soil_temperature_executed = .false.
    integer :: soil_temperature_status = 0
    logical :: soil_temperature_energy_accounting_complete = .false.
    real(real64) :: soil_temperature_energy_residual_j_cm2 = 0.0_real64
    real(real64) :: soil_temperature_top_heat_flux_j_cm2_day = 0.0_real64
    real(real64) :: soil_temperature_storage_change_j_cm2 = 0.0_real64
    real(real64) :: soil_temperature_boundary_energy_j_cm2 = 0.0_real64
  end type fmr_serialized_physical_observation_t
""",'thermal observation')

s=replace_once(s,
"""    type(snow_diagnostics_t) :: snow_diagnostics
    type(fmr_serialized_physical_observation_t) :: last_observation
""",
"""    type(snow_diagnostics_t) :: snow_diagnostics
    logical :: soil_temperature_active = .false.
    type(soil_temperature_parameters_t), allocatable :: soil_temperature_parameters
    type(soil_temperature_forcing_t), allocatable :: soil_temperature_forcing
    type(soil_temperature_numerical_config_t) :: soil_temperature_numerical
    type(soil_temperature_workspace_t) :: soil_temperature_workspace
    type(fmr_serialized_physical_observation_t) :: last_observation
""",'worker-local thermal model state')

s=replace_once(s,
"""    if (allocated(source%snow)) then
      allocate(target%snow)
      target%snow = source%snow
    end if
  end subroutine copy_b110_physical_state
""",
"""    if (allocated(source%snow)) then
      allocate(target%snow)
      target%snow = source%snow
    end if
    if (allocated(target%soil_temperature)) deallocate(target%soil_temperature)
    if (allocated(source%soil_temperature)) then
      allocate(target%soil_temperature)
      target%soil_temperature = source%soil_temperature
    end if
  end subroutine copy_b110_physical_state
""",'thermal clone')

s=replace_once(s,
"""    model%snow_active = .false.
    model%snow_event_prepared = .false.
    model%state_profile_admitted = .false.
""",
"""    model%snow_active = .false.
    model%soil_temperature_active = .false.
    model%snow_event_prepared = .false.
    model%state_profile_admitted = .false.
""",'clear thermal profile')

s=replace_once(s,
"""    model%snow_active = parameters%snow_active
    model%snow_outer_t0 = t0
""",
"""    model%snow_active = parameters%snow_active
    model%soil_temperature_active = parameters%soil_temperature_active
    model%snow_outer_t0 = t0
""",'prepare thermal active')

s=replace_once(s,
"""      if (parameters%snow_active) then
        if (.not. allocated(parameters%snow) .or. .not. allocated(forcing%snow) .or. &
            .not. allocated(physical%snow)) return
        call evaluate_snow_reference_call(parameters%snow, physical%snow%process, forcing%snow, t0, t1, &
             model%snow_candidate, model%snow_fluxes, model%snow_diagnostics)
        if (model%snow_diagnostics%status /= SNOW_OK .or. .not. model%snow_diagnostics%mass%available) return
        model%snow_event_prepared = .true.
        model%snow_melt_rate = model%snow_fluxes%melt / (t1 - t0)
        model%state_profile_admitted = .true.
      else
        if (allocated(parameters%snow) .or. allocated(forcing%snow) .or. allocated(physical%snow)) return
        model%state_profile_admitted = .true.
      end if
""",
"""      if (parameters%snow_active) then
        if (.not. allocated(parameters%snow) .or. .not. allocated(forcing%snow) .or. &
            .not. allocated(physical%snow)) return
        call evaluate_snow_reference_call(parameters%snow, physical%snow%process, forcing%snow, t0, t1, &
             model%snow_candidate, model%snow_fluxes, model%snow_diagnostics)
        if (model%snow_diagnostics%status /= SNOW_OK .or. .not. model%snow_diagnostics%mass%available) return
        model%snow_event_prepared = .true.
        model%snow_melt_rate = model%snow_fluxes%melt / (t1 - t0)
      else
        if (allocated(parameters%snow) .or. allocated(forcing%snow) .or. allocated(physical%snow)) return
      end if
      if (parameters%soil_temperature_active) then
        if (parameters%snow_active) return
        if (.not. allocated(parameters%soil_temperature) .or. .not. allocated(forcing%soil_temperature) .or. &
            .not. allocated(physical%soil_temperature)) return
        if (.not. parameters%soil_temperature%ready() .or. .not. physical%soil_temperature%ready()) return
        if (parameters%soil_temperature%node_count() /= parameters%active_nodes .or. &
            physical%soil_temperature%node_count() /= parameters%active_nodes) return
      else
        if (allocated(parameters%soil_temperature) .or. allocated(forcing%soil_temperature) .or. &
            allocated(physical%soil_temperature)) return
      end if
      model%state_profile_admitted = .true.
""",'combined optional process profile validation')

s=replace_once(s,
"""    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
""",
"""    if (parameters%soil_temperature_active) then
      if (template%optional_state_layout_id <= 0_int64 .or. parameters%snow_active) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    end if
    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
""",'thermal template admission')

s=replace_once(s,
"""      if (parameters%snow_active) then
        ok = ok .and. allocated(parameters%snow) .and. self%snow_event_prepared
      else
        ok = ok .and. .not. allocated(parameters%snow) .and. .not. self%snow_event_prepared
      end if
""",
"""      if (parameters%snow_active) then
        ok = ok .and. allocated(parameters%snow) .and. self%snow_event_prepared
      else
        ok = ok .and. .not. allocated(parameters%snow) .and. .not. self%snow_event_prepared
      end if
      if (parameters%soil_temperature_active) then
        ok = ok .and. .not. parameters%snow_active .and. self%soil_temperature_active .and. &
             allocated(parameters%soil_temperature)
        if (ok) ok = parameters%soil_temperature%ready() .and. &
             parameters%soil_temperature%node_count() == parameters%active_nodes
      else
        ok = ok .and. .not. allocated(parameters%soil_temperature) .and. .not. self%soil_temperature_active
      end if
""",'execution thermal admission')

s=replace_once(s,
"""      self%root_extraction_active = parameters%root_extraction_active
      self%snow_active = parameters%snow_active
""",
"""      self%root_extraction_active = parameters%root_extraction_active
      self%snow_active = parameters%snow_active
      self%soil_temperature_active = parameters%soil_temperature_active
      if (allocated(self%soil_temperature_parameters)) deallocate(self%soil_temperature_parameters)
      if (parameters%soil_temperature_active) then
        allocate(self%soil_temperature_parameters)
        self%soil_temperature_parameters = parameters%soil_temperature
      end if
""",'configure thermal parameters')

s=replace_once(s,
"""      if (self%snow_active) then
        if (.not. self%snow_event_prepared .or. .not. allocated(forcing%snow)) return
        if (.not. same_real_bits(interval%t0, self%snow_outer_t0) .or. .not. same_real_bits(interval%t1, self%snow_outer_t1)) return
      else
        if (allocated(forcing%snow)) return
      end if
      if (associated(self%qdra)) deallocate(self%qdra)
""",
"""      if (self%snow_active) then
        if (.not. self%snow_event_prepared .or. .not. allocated(forcing%snow)) return
        if (.not. same_real_bits(interval%t0, self%snow_outer_t0) .or. .not. same_real_bits(interval%t1, self%snow_outer_t1)) return
      else
        if (allocated(forcing%snow)) return
      end if
      if (allocated(self%soil_temperature_forcing)) deallocate(self%soil_temperature_forcing)
      if (self%soil_temperature_active) then
        if (.not. allocated(forcing%soil_temperature)) return
        allocate(self%soil_temperature_forcing)
        self%soil_temperature_forcing = forcing%soil_temperature
      else
        if (allocated(forcing%soil_temperature)) return
      end if
      if (associated(self%qdra)) deallocate(self%qdra)
""",'prepare thermal forcing')

s=replace_once(s,
"""    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    real(real64), allocatable, target :: source_sink_root_zero(:)
    real(real64) :: step_duration
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok
""",
"""    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    type(process_hydraulic_view_t) :: hydraulic_start, hydraulic_end
    type(soil_temperature_state_t) :: soil_temperature_trial
    type(soil_temperature_result_t) :: soil_temperature_result
    type(soil_temperature_diagnostics_t) :: soil_temperature_diagnostics
    real(real64), allocatable, target :: source_sink_root_zero(:)
    real(real64) :: step_duration
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok
    integer :: soil_temperature_status
""",'advance thermal locals')

s=replace_once(s,
"""    outcome = trial_outcome_t()
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
""",
"""    outcome = trial_outcome_t()
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%soil_temperature_active = self%soil_temperature_active
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
""",'advance thermal observation active')

s=replace_once(s,
"""      request%base_state%pressure_head = physical%pressure_head
      request%base_state%water_content = physical%water_content
      request%base_state%ponding_depth = physical%ponding_depth
      request%base_state%groundwater_level = physical%groundwater_level
    class default
""",
"""      request%base_state%pressure_head = physical%pressure_head
      request%base_state%water_content = physical%water_content
      request%base_state%ponding_depth = physical%ponding_depth
      request%base_state%groundwater_level = physical%groundwater_level
      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
        call build_process_hydraulic_view(request%base_state, hydraulic_start, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
      else
        if (allocated(physical%soil_temperature)) return
      end if
    class default
""",'capture hydraulic start view')

s=replace_once(s,
"""    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      physical%active_nodes = solve_result%candidate_state%active_nodes
      physical%pressure_head = solve_result%candidate_state%pressure_head
      physical%water_content = solve_result%candidate_state%water_content
      physical%ponding_depth = solve_result%candidate_state%ponding_depth
      physical%groundwater_level = solve_result%candidate_state%groundwater_level
    class default
      return
    end select
""",
"""    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (self%soil_temperature_active) then
        call build_process_hydraulic_view(solve_result%candidate_state, hydraulic_end, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
        call trial_restricted_soil_temperature(self%soil_temperature_parameters, self%soil_temperature_numerical, &
             self%soil_temperature_forcing, hydraulic_start, hydraulic_end, physical%soil_temperature, t0, t1, &
             self%soil_temperature_workspace, soil_temperature_trial, soil_temperature_result, soil_temperature_diagnostics)
        self%last_observation%soil_temperature_executed = .true.
        self%last_observation%soil_temperature_status = soil_temperature_result%status
        self%last_observation%soil_temperature_energy_accounting_complete = soil_temperature_diagnostics%energy_accounting_complete
        self%last_observation%soil_temperature_energy_residual_j_cm2 = soil_temperature_result%energy_residual_j_cm2
        self%last_observation%soil_temperature_top_heat_flux_j_cm2_day = &
             soil_temperature_result%top_heat_flux_into_soil_j_cm2_day
        self%last_observation%soil_temperature_storage_change_j_cm2 = soil_temperature_result%sensible_storage_change_j_cm2
        self%last_observation%soil_temperature_boundary_energy_j_cm2 = soil_temperature_result%boundary_energy_into_soil_j_cm2
        if (soil_temperature_result%status /= SOIL_TEMP_OK .or. .not. soil_temperature_result%produced) return
        call commit_soil_temperature_state(physical%soil_temperature, soil_temperature_trial, soil_temperature_status)
        if (soil_temperature_status /= SOIL_TEMP_OK) then
          self%last_observation%soil_temperature_status = soil_temperature_status
          return
        end if
      else
        if (allocated(physical%soil_temperature)) return
      end if
      physical%active_nodes = solve_result%candidate_state%active_nodes
      physical%pressure_head = solve_result%candidate_state%pressure_head
      physical%water_content = solve_result%candidate_state%water_content
      physical%ponding_depth = solve_result%candidate_state%ponding_depth
      physical%groundwater_level = solve_result%candidate_state%groundwater_level
    class default
      return
    end select
""",'thermal trial after Richards')

s=replace_once(s,
"""      if (complete .and. self%snow_active) complete = allocated(physical%snow)
      if (complete .and. .not. self%snow_active) complete = .not. allocated(physical%snow)
""",
"""      if (complete .and. self%snow_active) complete = allocated(physical%snow)
      if (complete .and. .not. self%snow_active) complete = .not. allocated(physical%snow)
      if (complete .and. self%soil_temperature_active) then
        complete = allocated(physical%soil_temperature)
        if (complete) complete = physical%soil_temperature%ready() .and. &
             physical%soil_temperature%node_count() == physical%active_nodes
      end if
      if (complete .and. .not. self%soil_temperature_active) complete = .not. allocated(physical%soil_temperature)
""",'storage accounting thermal topology')

s=replace_once(s,
"""          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)
          if (same .and. allocated(full%snow)) then
""",
"""          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)
          if (same) same = allocated(full%soil_temperature) .eqv. allocated(half%soil_temperature)
          ! F-MR39 deliberately does not introduce a new combined water/thermal
          ! timestep tolerance. Thermal temporal refinement remains qualified by
          ! F-VQ58; the existing Richards temporal acceptance route is preserved.
          if (same .and. allocated(full%snow)) then
""",'thermal allocation temporal topology')

BACKEND.write_text(s)

r=RESTART.read_text()
r=replace_once(r,
"""        type is (fmr_b110_physical_state_t)
          matches = .true.
""",
"""        type is (fmr_b110_physical_state_t)
          matches = thermal_optional_state_matches(state, template)
""",'restart physical thermal shape')
r=replace_once(r,
"""        type is (fmr_b110_temporal_indicator_state_t)
          matches = .true.
""",
"""        type is (fmr_b110_temporal_indicator_state_t)
          matches = thermal_optional_state_matches(state, template)
""",'restart temporal thermal shape')
r=replace_once(r,
"""  end function fmr_restart_state_matches_template

end module mod_fmr_restart_state_contract
""",
"""  end function fmr_restart_state_matches_template

  logical function thermal_optional_state_matches(state, template) result(matches)
    class(fmr_b110_physical_state_t), intent(in) :: state
    type(fmr_template_t), intent(in) :: template

    matches = .true.
    if (.not. allocated(state%soil_temperature)) return
    matches = template%optional_state_layout_id > 0 .and. .not. allocated(state%snow) .and. &
         state%soil_temperature%ready() .and. state%soil_temperature%node_count() == state%active_nodes
  end function thermal_optional_state_matches

end module mod_fmr_restart_state_contract
""",'restart thermal helper')
RESTART.write_text(r)
print('FMR39_MATERIALIZATION=PASS')
print('FMR39_BACKEND_BLOB='+blob(BACKEND))
print('FMR39_RESTART_CONTRACT_BLOB='+blob(RESTART))
