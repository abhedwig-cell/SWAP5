from pathlib import Path

OLD = 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy'
NEW = 'fmr_execute_serialized_column_with_bottom_energy'


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'EB-I18R fixture anchor {label!r} matched {count} times')
    return text.replace(old, new, 1)

runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
text = runtime.read_text()
if OLD not in text:
    raise SystemExit('EB-I18R runtime staged entrypoint missing')
text = text.replace(OLD, NEW)
text = once(text, '    thermal_candidate = fmr_bottom_thermal_candidate_t()\n',
            '    call thermal_candidate%clear()\n', 'private thermal constructor')
if OLD in text:
    raise SystemExit('EB-I18R runtime API normalization incomplete')
runtime.write_text(text)

test = Path('tests/eb/test_eb_i18_transaction_publication.f90')
text = test.read_text()
if OLD not in text:
    raise SystemExit('EB-I18R test staged entrypoint missing')
text = text.replace(OLD, NEW)

text = once(text,
"""      response = fmr_external_bottom_thermal_response_t()
""",
"""      call response%set_complete(request, donor_temperature_c, -1_int64, ok)
      if (ok) error stop 'EB-I18R invalid response unexpectedly ready'
""", 'private response constructor')

text = once(text,
"""  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
""",
"""  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
""", 'runtime core imports')

text = once(text,
"""  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
""",
"""  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
""", 'backend imports')

text = once(text,
"""  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
""",
"""  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
""", 'production top provider import')
text = text.replace('type(fmr04_fixed_flux_top_provider_t)', 'type(fixed_flux_top_boundary_provider_t)')

anchor = """  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
"""
text = once(text, anchor, anchor + """  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state
""", 'soil temperature imports')

text = once(text, '  real(real64), parameter :: t1 = 9100.135_real64\n',
            '  real(real64), parameter :: t1 = 9100.1251_real64\n', 'bounded positive-qbot duration')
text = once(text, '  real(real64), parameter :: initial_head = -123.0_real64\n',
            '  real(real64), parameter :: initial_head = -75.0_real64\n', 'hydrostatic reference head')

text = once(text, '    template%optional_state_layout_id = 0_int64\n',
            '    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE\n',
            'optional state layout')
text = once(text, '    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE\n',
            '    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n',
            'temporal history layout')

text = once(text,
"""    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e-8_real64
    config%transaction%mass_tolerance = 1.0e-10_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 4
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
""",
"""    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = 2.5e-11_real64
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
""", 'qualified temporal policy')

text = once(text,
"""    integer :: k

    parameters%parameter_set_id = 91801_int64
""",
"""    real(real64) :: dz_cm(numnod), distance_above_cm(numnod), theta_sat(numnod)
    real(real64) :: f_quartz(numnod), f_clay(numnod), f_organic(numnod)
    integer :: k, soil_temperature_status

    parameters%parameter_set_id = 91801_int64
""", 'parameter declarations')
text = once(text, '    parameters%bottom_mode = 7\n', '    parameters%bottom_mode = 2\n', 'prescribed qbot mode')
text = once(text, '    parameters%root_extraction_active = .true.\n',
            '    parameters%root_extraction_active = .false.\n', 'root extraction off')
text = once(text,
"""    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters
""",
"""    parameters%frost_active = .false.
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
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
""", 'thermal parameter activation')

text = once(text,
"""    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok
""",
"""    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: initial_temperature(numnod), predecessor_right_derivative(numnod)
    integer :: soil_temperature_status, i
    logical :: ok
""", 'committed state declarations')

text = once(text,
"""    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.25_real64
    call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
""",
"""    heads(1) = initial_head
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%soil_temperature)
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    initial_temperature = 9.0_real64
    call initialize_soil_temperature_state(initial_temperature, state%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature state initialization')
    predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, initial_time, ok, &
         predecessor_right_derivative)
""", 'hydrostatic temporal committed state')

text = once(text, '    q = max(1.0e-8_real64, min(1.0e-4_real64, 0.01_real64*k0))\n',
            '    q = 1.0e-10_real64\n', 'bounded prescribed qbot')
text = once(text,
"""    ! Positive bottom flux is inflow to SWAP; EB-I13 therefore records a
    ! negative outward-positive bottom transfer. Keep the top closed so the
    ! physical solver must account the small inflow as storage change.
    forcing%top_flux = 0.0_real64
""",
"""    ! Positive bottom flux is inflow to SWAP. Use the already-qualified
    ! F-MR44R bounded throughflow fixture so temporal acceptance, mass closure
    ! and thermal publication are tested on the same committed candidate.
    forcing%top_flux = q
""", 'throughflow forcing')
text = once(text,
"""    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
""",
"""    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod), forcing%soil_temperature)
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
    forcing%soil_temperature%prescribed_surface_temperature_c = 15.0_real64
""", 'thermal forcing')

text = once(text,
"""    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    call reset_provider(PROVIDER_COMPLETE, column_id)
""",
"""    parameters%bottom_mode = 6
    call reset_provider(PROVIDER_COMPLETE, column_id)
""", 'explicit rejected route')

if OLD in text or 'fmr04_fixed_flux_top_provider_t' in text or 'FMR_NUMERICAL_CONTINUATION_NONE' in text:
    raise SystemExit('EB-I18R stale fixture semantics remain')

test.write_text(text)
print('EB_I18R_MODE2_TEMPORAL_HISTORY_FIXTURE=PASS')
print('EB_I18R_HARD_MASS_GATE=1.0E-12')
print('EB_I18R_QBOT=1.0E-10')
print('EB_I18R_DT=1.0E-4')
