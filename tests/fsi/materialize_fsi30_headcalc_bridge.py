#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path('src/legacy/b1_10_port/headcalc.f90')
EXPECTED_BLOB = '55893f1f5ccba2052ad681743aa155b69f351246'
MARKER = 'provider_dynamic_top_active'

text = PATH.read_text()
if MARKER in text:
    print('FSI30_HEADCALC_BRIDGE_ALREADY_MATERIALIZED=YES')
    raise SystemExit(0)

actual = subprocess.check_output(['git', 'hash-object', str(PATH)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f'F-SI30 source lock failed: expected {EXPECTED_BLOB}, got {actual}')

replacements = []

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI30 {label}: expected exactly one anchor, found {count}')
    text = text.replace(old, new, 1)
    replacements.append(label)

replace_once(
"""   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding, &
        FSI_TOP_MODE_EXPLICIT_FLUX
   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
        soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
""",
"""   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding, &
        FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
        soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t, &
        soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, &
        SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
""",
'import-contract')

replace_once(
"""   type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
""",
"""   type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
   type(soil_water_top_boundary_result_t) :: provider_dynamic_top_result
   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
""",
'dynamic-result-local')

replace_once(
"""   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved
""",
"""   logical :: legacy_state_binding, state_ok, provider_top_active, provider_dynamic_top_active, provider_runoff_resolved
""",
'dynamic-active-local')

replace_once(
"""   provider_top_active = .false.
   provider_constitutive_active = .false.
   provider_source_sink_active = .false.
   provider_root_sink_active = .false.
   if (.not. legacy_state_binding .and. present(evaluation_context)) then
      provider_constitutive_active = associated(evaluation_context%constitutive)
      provider_source_sink_active = associated(evaluation_context%source_sink)
      provider_root_sink_active = associated(evaluation_context%root_sink)
      if (.not. provider_constitutive_active) error stop 'HeadCalc: explicit constitutive provider required'
      if (.not. provider_source_sink_active) error stop 'HeadCalc: explicit source/sink provider required'
      if (provider_root_sink_active .and. SwKimpl /= 0) &
           error stop 'HeadCalc: root-sink provider requires swkimpl=0 in F-SI11'
   end if
   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then
      provider_top_active = associated(evaluation_context%top_boundary) .and. &
                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX
   end if
   provider_runoff_resolved = .false.
""",
"""   provider_top_active = .false.
   provider_dynamic_top_active = .false.
   provider_dynamic_top_result = soil_water_top_boundary_result_t()
   provider_constitutive_active = .false.
   provider_source_sink_active = .false.
   provider_root_sink_active = .false.
   if (.not. legacy_state_binding .and. present(evaluation_context)) then
      provider_constitutive_active = associated(evaluation_context%constitutive)
      provider_source_sink_active = associated(evaluation_context%source_sink)
      provider_root_sink_active = associated(evaluation_context%root_sink)
      if (.not. provider_constitutive_active) error stop 'HeadCalc: explicit constitutive provider required'
      if (.not. provider_source_sink_active) error stop 'HeadCalc: explicit source/sink provider required'
      if (provider_root_sink_active .and. SwKimpl /= 0) &
           error stop 'HeadCalc: root-sink provider requires swkimpl=0 in F-SI11'
   end if
   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then
      provider_top_active = associated(evaluation_context%top_boundary) .and. &
                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX
      provider_dynamic_top_active = associated(evaluation_context%dynamic_top_boundary) .and. &
                                    boundary_conditions%top_mode == FSI_TOP_MODE_DYNAMIC_PROVIDER
      if (boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX .and. .not. provider_top_active) &
           error stop 'HeadCalc: explicit-flux top mode requires fixed top-boundary provider'
      if (boundary_conditions%top_mode == FSI_TOP_MODE_DYNAMIC_PROVIDER .and. .not. provider_dynamic_top_active) &
           error stop 'HeadCalc: dynamic top mode requires dynamic top-boundary provider'
   end if
   provider_runoff_resolved = .false.
""",
'provider-activation')

replace_once(
"""!     test for waterbalance of ponding layer
      if (state%ftoph) then
         state%qtop = -state%kmean(1)*((state%hsurf - state%h(1))/grid_disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. pond_balance_option_allows()) then
            deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      end if
""",
"""!     test for waterbalance of ponding layer
      if (provider_dynamic_top_active) then
         if (state%ftoph) state%qtop = -state%kmean(1)*((state%hsurf - state%h(1))/grid_disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. pond_balance_option_allows()) then
            deviat = state%pond - state%pondm1 - provider_dynamic_top_result%net_potential_surface_flux*dt + &
                     state%runots - state%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      else if (state%ftoph) then
         state%qtop = -state%kmean(1)*((state%hsurf - state%h(1))/grid_disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. pond_balance_option_allows()) then
            deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      end if
""",
'dynamic-mass-balance')

replace_once(
"""subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   real(8) :: provider_runoff_flux
   provider_runoff_resolved = .false.
   if (provider_top_active) then
      call evaluation_context%top_boundary%evaluate(state%h(1), state%theta(1), boundary_conditions, &
           state%qtop, state%hsurf, provider_runoff_flux)
      state%ftoph = .false.
      state%runots = provider_runoff_flux * dt
      state%flrunoff = abs(provider_runoff_flux) > 0.0d0
      provider_runoff_resolved = .true.
      return
   end if
""",
"""subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   real(8) :: provider_runoff_flux
   provider_runoff_resolved = .false.
   if (provider_dynamic_top_active) then
      call evaluation_context%dynamic_top_boundary%evaluate(state%h(1), state%theta(1), state%pond, &
           boundary_conditions, provider_dynamic_top_result)
      if (provider_dynamic_top_result%status /= SW_TOP_BOUNDARY_AVAILABLE) &
           error stop 'HeadCalc: dynamic top-boundary provider unavailable'
      if (.not. provider_dynamic_top_result%carries_surface_mass_terms) &
           error stop 'HeadCalc: dynamic top-boundary provider omitted surface mass terms'
      if (.not. provider_dynamic_top_result%runoff_resolved) &
           error stop 'HeadCalc: dynamic top-boundary provider left runoff unresolved'
      state%qtop = provider_dynamic_top_result%actual_top_flux
      state%hsurf = provider_dynamic_top_result%surface_head
      state%pond = provider_dynamic_top_result%candidate_ponding_depth
      state%runots = provider_dynamic_top_result%runoff_depth
      state%flrunoff = provider_dynamic_top_result%runoff_potential .or. &
                       abs(provider_dynamic_top_result%runoff_depth) > 0.0d0
      select case (provider_dynamic_top_result%regime)
      case (SW_TOP_BOUNDARY_REGIME_FLUX)
         state%ftoph = .false.
      case (SW_TOP_BOUNDARY_REGIME_HEAD)
         if (provider_dynamic_top_result%surface_face_conductivity <= 0.0d0) &
              error stop 'HeadCalc: dynamic head regime requires positive surface-face conductivity'
         state%ftoph = .true.
         state%kmean(1) = provider_dynamic_top_result%surface_face_conductivity
      case default
         error stop 'HeadCalc: dynamic top-boundary provider returned invalid regime'
      end select
      provider_runoff_resolved = .true.
      return
   end if
   if (provider_top_active) then
      call evaluation_context%top_boundary%evaluate(state%h(1), state%theta(1), boundary_conditions, &
           state%qtop, state%hsurf, provider_runoff_flux)
      state%ftoph = .false.
      state%runots = provider_runoff_flux * dt
      state%flrunoff = abs(provider_runoff_flux) > 0.0d0
      provider_runoff_resolved = .true.
      return
   end if
""",
'dynamic-boundtop-bridge')

PATH.write_text(text)
new_blob = subprocess.check_output(['git', 'hash-object', str(PATH)], text=True).strip()
print('FSI30_HEADCALC_BRIDGE_MATERIALIZED=YES')
print('FSI30_HEADCALC_INPUT_BLOB=' + EXPECTED_BLOB)
print('FSI30_HEADCALC_OUTPUT_BLOB=' + new_blob)
print('FSI30_REPLACEMENTS=' + ','.join(replacements))
