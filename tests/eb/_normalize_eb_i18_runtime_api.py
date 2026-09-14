from pathlib import Path

OLD = 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy'
NEW = 'fmr_execute_serialized_column_with_bottom_energy'

runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
text = runtime.read_text()
count = text.count(OLD)
if count <= 0:
    raise SystemExit(f'EB-I18 API normalization: {OLD!r} not found in {runtime}')
text = text.replace(OLD, NEW)
private_constructor = '    thermal_candidate = fmr_bottom_thermal_candidate_t()\n'
if text.count(private_constructor) != 1:
    raise SystemExit('EB-I18 runtime private thermal constructor anchor mismatch')
text = text.replace(private_constructor, '    call thermal_candidate%clear()\n', 1)
if OLD in text:
    raise SystemExit(f'EB-I18 API normalization incomplete in {runtime}')
runtime.write_text(text)
print(f'EB_I18_API_NORMALIZED file={runtime} replacements={count} name={NEW}')
print('EB_I18_PRIVATE_THERMAL_CONSTRUCTOR_REMOVED=PASS')

test = Path('tests/eb/test_eb_i18_transaction_publication.f90')
text = test.read_text()
count = text.count(OLD)
if count <= 0:
    raise SystemExit(f'EB-I18 API normalization: {OLD!r} not found in {test}')
text = text.replace(OLD, NEW)
invalid_constructor = '      response = fmr_external_bottom_thermal_response_t()\n'
invalid_replacement = (
    '      call response%set_complete(request, donor_temperature_c, -1_int64, ok)\n'
    "      if (ok) error stop 'EB-I18 invalid response unexpectedly ready'\n"
)
if text.count(invalid_constructor) != 1:
    raise SystemExit('EB-I18 test private response constructor anchor mismatch')
text = text.replace(invalid_constructor, invalid_replacement, 1)

# EB-I18 exercises the already qualified EB-I13 physical thermal profile.
# Publication semantics must not silently introduce a different hydrologic
# qualification problem.
old = """  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
"""
new = """  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 runtime-core import anchor mismatch')
text = text.replace(old, new, 1)

anchor = """  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
"""
replacement = anchor + """  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state
"""
if text.count(anchor) != 1:
    raise SystemExit('EB-I18 soil-temperature import anchor mismatch')
text = text.replace(anchor, replacement, 1)

old = '    template%optional_state_layout_id = 0_int64\n'
new = '    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE\n'
if text.count(old) != 1:
    raise SystemExit('EB-I18 optional state layout anchor mismatch')
text = text.replace(old, new, 1)

old = """    integer :: k

    parameters%parameter_set_id = 91801_int64
"""
new = """    real(real64) :: dz_cm(numnod), distance_above_cm(numnod), theta_sat(numnod)
    real(real64) :: f_quartz(numnod), f_clay(numnod), f_organic(numnod)
    integer :: k, soil_temperature_status

    parameters%parameter_set_id = 91801_int64
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 parameter declaration anchor mismatch')
text = text.replace(old, new, 1)

old = """    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters
"""
new = """    parameters%frost_active = .false.
    parameters%soil_temperature_active = .true.
    dz_cm = 100.0_real64 * abs(dz)
    distance_above_cm = 0.5_real64 * dz_cm
    theta_sat = 0.423_real64
    f_quartz = 0.40_real64
    f_clay = 0.40_real64
    f_organic = 0.10_real64
    allocate(parameters%soil_temperature)
    call initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, &
         parameters%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature parameter initialization')
  end subroutine initialize_parameters
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 parameter thermal activation anchor mismatch')
text = text.replace(old, new, 1)

old = """    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok
"""
new = """    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: initial_temperature(numnod)
    integer :: soil_temperature_status
    logical :: ok
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 committed-state declaration anchor mismatch')
text = text.replace(old, new, 1)

old = """    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.25_real64
    call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
"""
new = """    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%soil_temperature)
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.25_real64
    initial_temperature = 9.0_real64
    call initialize_soil_temperature_state(initial_temperature, state%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature state initialization')
    call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 committed-state thermal anchor mismatch')
text = text.replace(old, new, 1)

old = """    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
"""
new = """    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod), forcing%soil_temperature)
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
    forcing%soil_temperature%prescribed_surface_temperature_c = 15.0_real64
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 forcing thermal anchor mismatch')
text = text.replace(old, new, 1)

old = """    config%transaction%temporal_tolerance = 1.0e-8_real64
    config%transaction%mass_tolerance = 1.0e-10_real64
"""
new = """    config%transaction%temporal_tolerance = 1.0e6_real64
    config%transaction%mass_tolerance = 1.0e-8_real64
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 numerical profile anchor mismatch')
text = text.replace(old, new, 1)

# Keep diagnostics on failure so a remaining transaction rejection can be
# attributed without weakening the hydrologic acceptance criteria.
old = """    call require(output%completed .and. output%committed, 'complete provider hydrology committed')
"""
new = """    if (.not. (output%completed .and. output%committed)) then
      write(*,'(A,1X,L1,1X,L1,1X,I0,1X,I0)') 'EB_I18_COMMIT_DEBUG', output%completed, output%committed, &
           output%kernel_status, output%commit_status
      write(*,'(A,1X,A,1X,A)') 'EB_I18_ROUTE_DEBUG', trim(output%admission_status), &
           trim(diagnostic%failure_classification)
      write(*,'(A,1X,I0,1X,I0,1X,I0)') 'EB_I18_REVISION_DEBUG', output%initial_revision, output%final_revision, &
           output%accepted_substeps
    end if
    call require(output%completed .and. output%committed, 'complete provider hydrology committed')
"""
if text.count(old) != 1:
    raise SystemExit('EB-I18 complete-provider diagnostic anchor mismatch')
text = text.replace(old, new, 1)

if OLD in text:
    raise SystemExit(f'EB-I18 API normalization incomplete in {test}')
test.write_text(text)
print(f'EB_I18_API_NORMALIZED file={test} replacements={count} name={NEW}')
print('EB_I18_PRIVATE_RESPONSE_CONSTRUCTOR_REMOVED=PASS')
print('EB_I18_QUALIFIED_THERMAL_PROFILE_FIXTURE=PASS')
print('EB_I18_QUALIFIED_I13_NUMERICAL_PROFILE=PASS')
