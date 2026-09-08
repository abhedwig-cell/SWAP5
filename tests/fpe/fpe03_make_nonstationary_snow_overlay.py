#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: fpe03_make_nonstationary_snow_overlay.py OLD_FPE03 FMR06_FIXTURE OUT')
old_path = Path(sys.argv[1])
fmr06_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
text = old_path.read_text()
fmr06 = fmr06_path.read_text()

# Fail closed unless the immutable scientific source still contains the exact
# active-SNOW case that this diagnostic overlay is derived from.
required_fmr06 = [
    "real(real64), parameter :: t0 = 1600.375_real64",
    "real(real64), parameter :: t1 = 1601.375_real64",
    "p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=active",
    "p%snow%suppress_sublimation=0; p%snow%melt_coefficient=0.15_real64",
    "state%snow%process=snow_state_t(3.0_real64,0.1_real64)",
    "f%snow%snowfall_input=0.4_real64; f%snow%rain_on_snow_input=0.1_real64",
    "f%snow%soil_surface_temperature=0.0_real64; f%snow%mean_air_temperature=2.0_real64",
    "f%snow%potential_soil_evaporation=0.2_real64; f%snow%reduced_soil_evaporation=0.15_real64",
    "f%snow%ponding_evaporation=0.25_real64",
    "f%top_flux = -conductivity0 + fluxes%melt/(t1-t0)",
]
for token in required_fmr06:
    if token not in fmr06:
        raise SystemExit(f'FMR06 source anchor missing: {token}')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    text = text.replace(old, new, 1)

replace_once(
    'program test_fpe03_reference_stress\n  use, intrinsic :: iso_fortran_env, only: int64, real64\n',
    'program test_fpe03_nonstationary_snow_overlay\n  use, intrinsic :: iso_fortran_env, only: int64, real64\n',
    'program name',
)
replace_once(
    '  use mod_transaction_reference, only: TX_MASS_MISSING_NONE\n',
    '  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE\n',
    'transaction import',
)
replace_once(
    '  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n'
    '       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider\n'
    '  implicit none\n',
    '  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n'
    '       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider\n'
    '  use mod_snow_process, only: snow_state_t, snow_flux_result_t, snow_diagnostics_t, &\n'
    '       evaluate_snow_reference_call, SNOW_OK\n'
    '  implicit none\n',
    'snow process import',
)
replace_once(
    '  integer, parameter :: ncases = 24\n'
    '  real(real64), parameter :: t0 = 1000.125_real64\n'
    '  real(real64), parameter :: t1 = 1000.625_real64\n',
    '  integer, parameter :: ncases = 4\n'
    '  real(real64), parameter :: t0 = 1600.375_real64\n'
    '  real(real64), parameter :: t1 = 1601.375_real64\n',
    'case count and exact daily interval',
)

start = text.index('  subroutine initialize_cases(c)\n')
end = text.index('  end subroutine initialize_cases\n', start) + len('  end subroutine initialize_cases\n')
text = text[:start] + """  subroutine initialize_cases(c)
    type(stress_case_t), intent(out) :: c(ncases)

    ! Case 1 reproduces the exact FMR06/FVQ17 active-SNOW hydraulic baseline.
    call set_uniform(c(1), 'admitted_snow_baseline', -75.0_real64, -1.0_real64, -1.0_real64)

    ! Cases 2-4 are diagnostic extrapolations only. They are deliberately the
    ! smallest stress directions from the historical F-PE03 refined matrix.
    c(2)%name = 'snow_tiny_gradient_down'
    c(2)%heads = [-74.99_real64,-75.00_real64,-75.01_real64,-75.02_real64]
    call set_uniform(c(3), 'snow_top_flux_plus_0p01pct', -75.0_real64, -1.0001_real64, -1.0_real64)
    call set_uniform(c(4), 'snow_top_flux_minus_0p01pct', -75.0_real64, -0.9999_real64, -1.0_real64)
  end subroutine initialize_cases
""" + text[end:]

replace_once(
    '    type(canonical_numerical_config_t) :: config\n'
    '    real(real64) :: k_top, k_bottom\n',
    '    type(canonical_numerical_config_t) :: config\n'
    '    type(snow_state_t) :: expected_snow\n'
    '    real(real64) :: k_top, k_bottom\n',
    'run-case expected snow declaration',
)
replace_once(
    '    call configure_parameters(parameters(1), initial_state, spec%heads, k_top, k_bottom)\n'
    '    call configure_forcing(forcings(1), spec, k_top, k_bottom)\n',
    '    call configure_parameters(parameters(1), initial_state, spec%heads, k_top, k_bottom)\n'
    '    call configure_forcing(forcings(1), parameters(1), initial_state, spec, k_top, k_bottom, expected_snow)\n',
    'run-case forcing call',
)
replace_once(
    '    columns(1)%column_id = 503000_int64 + int(case_id, int64)\n',
    '    columns(1)%column_id = 606000_int64 + int(case_id, int64)\n',
    'column id',
)
replace_once(
    "      call require(states(1)%current_revision() == 1_int64, 'accepted stress case committed once')\n",
    "      call require(states(1)%current_revision() == 1_int64, 'accepted stress case committed once')\n"
    "      call require(state_matches_snow(states(1), expected_snow), 'accepted snow event committed exactly once')\n",
    'accepted snow-state check',
)

old_template = """    template%template_id = 503_int64
    template%physics_topology_id = 50501_int64
    template%vertical_layout_id = 50502_int64
    template%state_layout_id = 50503_int64
    template%solver_interface_id = 50504_int64
    template%optional_state_layout_id = 0_int64
"""
new_template = """    template%template_id = 606_int64
    template%physics_topology_id = 60601_int64
    template%vertical_layout_id = 60602_int64
    template%state_layout_id = 60603_int64
    template%solver_interface_id = 60604_int64
    template%optional_state_layout_id = 60605_int64
"""
replace_once(old_template, new_template, 'FMR06 template identity')
replace_once('    parameters%parameter_set_id = 50301_int64\n', '    parameters%parameter_set_id = 60601_int64\n', 'parameter id')
replace_once(
    '    parameters%snow_active = .false.\n',
    '    parameters%snow_active = .true.\n'
    '    allocate(parameters%snow)\n'
    '    parameters%snow%suppress_sublimation = 0\n'
    '    parameters%snow%melt_coefficient = 0.15_real64\n',
    'activate exact FMR06 snow parameters',
)
replace_once(
    '    state%active_nodes = numnod\n'
    '    allocate(state%pressure_head(numnod), state%water_content(numnod))\n'
    '    state%pressure_head = heads\n'
    '    state%water_content = water\n'
    '    state%ponding_depth = 0.0_real64\n'
    '    state%groundwater_level = -2.0_real64\n',
    '    state%active_nodes = numnod\n'
    '    allocate(state%pressure_head(numnod), state%water_content(numnod), state%snow)\n'
    '    state%pressure_head = heads\n'
    '    state%water_content = water\n'
    '    state%ponding_depth = 0.0_real64\n'
    '    state%groundwater_level = -2.0_real64\n'
    '    state%snow%process = snow_state_t(3.0_real64, 0.1_real64)\n'
    '    state%snow%event_applied = .false.\n'
    '    state%snow%event_t0 = 0.0_real64\n',
    'exact active snow initial state',
)

start = text.index('  subroutine configure_forcing(forcing, spec, k_top, k_bottom)\n')
end = text.index('  end subroutine configure_forcing\n', start) + len('  end subroutine configure_forcing\n')
text = text[:start] + """  subroutine configure_forcing(forcing, parameters, state, spec, k_top, k_bottom, expected_snow)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(stress_case_t), intent(in) :: spec
    real(real64), intent(in) :: k_top, k_bottom
    type(snow_state_t), intent(out) :: expected_snow
    type(snow_flux_result_t) :: snow_fluxes
    type(snow_diagnostics_t) :: snow_diagnostics
    integer :: i

    forcing%top_head = spec%heads(1)
    forcing%bottom_flux = spec%bottom_scale * k_bottom
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod), forcing%snow)
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do

    ! Exact FMR06/FVQ17 active case i=1 SNOW forcing.
    forcing%snow%snowfall_input = 0.4_real64
    forcing%snow%rain_on_snow_input = 0.1_real64
    forcing%snow%soil_surface_temperature = 0.0_real64
    forcing%snow%mean_air_temperature = 2.0_real64
    forcing%snow%potential_soil_evaporation = 0.2_real64
    forcing%snow%reduced_soil_evaporation = 0.15_real64
    forcing%snow%ponding_evaporation = 0.25_real64

    call evaluate_snow_reference_call(parameters%snow, state%snow%process, forcing%snow, t0, t1, &
         expected_snow, snow_fluxes, snow_diagnostics)
    call require(snow_diagnostics%status == SNOW_OK .and. snow_diagnostics%mass%available, &
         'direct nonstationary snow event')

    ! Preserve the FMR06 internal-transfer construction. The baseline therefore
    ! presents -k_top to Richards after melt-rate subtraction. Perturbed cases
    ! alter only that hydraulic target by the historical F-PE03 scale.
    forcing%top_flux = spec%top_scale * k_top + snow_fluxes%melt/(t1-t0)
  end subroutine configure_forcing
""" + text[end:]

# Bind the baseline to the already-qualified F-PE05 cost vector. Perturbed
# outcomes remain characterization and are intentionally not hard-coded.
baseline_anchor = "  write(*,'(A,I0)') 'FPE03_ACCEPTED_CASES=', accepted_count\n"
baseline_checks = """  call require(metrics(1)%accepted_substeps == 1, 'admitted snow baseline accepted substeps')
  call require(metrics(1)%nonlinear_iterations == 3, 'admitted snow baseline nonlinear cost')
  call require(metrics(1)%internal_retries == 0, 'admitted snow baseline retry cost')
  call require(metrics(1)%headcalc_calls == 3, 'admitted snow baseline HeadCalc cost')
  call require(metrics(1)%jacobian_builds == 3, 'admitted snow baseline Jacobian cost')
  call require(metrics(1)%linear_solves == 3, 'admitted snow baseline linear-solve cost')
  call require(metrics(1)%backtracking_attempts == 3, 'admitted snow baseline backtracking cost')
  call require(metrics(1)%alternative_solver_calls == 0, 'admitted snow baseline alternative-solver cost')
  write(*,'(A)') 'FPE03_NONSTATIONARY_BASELINE_FPE05_COST_IDENTITY=PASS'

""" + baseline_anchor
replace_once(baseline_anchor, baseline_checks, 'baseline cost identity')

final_anchor = "  write(*,'(A)') 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS'\n"
final_new = final_anchor + """  write(*,'(A)') 'FPE03_NONSTATIONARY_SNOW_BASELINE=FMR06_FVQ17_ACTIVE_CASE_1'
  write(*,'(A)') 'FPE03_NONSTATIONARY_SNOW_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION'
  write(*,'(A)') 'FPE03_NONSTATIONARY_SNOW_OVERLAY PASS'
"""
replace_once(final_anchor, final_new, 'overlay final markers')

helper_anchor = '  subroutine require(condition, message)\n'
helper = """  logical function state_matches_snow(state, expected) result(matches)
    type(kernel_committed_state_t), intent(in) :: state
    type(snow_state_t), intent(in) :: expected
    class(transaction_state_t), allocatable :: snapshot
    logical :: got

    matches = .false.
    call state%snapshot(snapshot, got)
    if (.not. got) return
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      if (.not. allocated(physical%snow)) return
      matches = same_bits(physical%snow%process%snow_water_storage, expected%snow_water_storage) .and. &
           same_bits(physical%snow%process%liquid_water_storage, expected%liquid_water_storage) .and. &
           physical%snow%event_applied .and. same_bits(physical%snow%event_t0, t0)
    end select
  end function state_matches_snow

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

""" + helper_anchor
replace_once(helper_anchor, helper, 'snow-state helper')
replace_once(
    'end program test_fpe03_reference_stress\n',
    'end program test_fpe03_nonstationary_snow_overlay\n',
    'end program name',
)

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(text)
print(f'FPE03_NONSTATIONARY_OVERLAY_GENERATED={out_path}')
print('FPE03_HISTORICAL_STRESS_STRUCTURE_REUSED=PASS')
print('FPE03_FMR06_ACTIVE_SNOW_SOURCE_ANCHORS=PASS')
print('FPE03_NONSTATIONARY_PERTURBATION_COUNT=3')
print('FPE03_NONSTATIONARY_PERTURBATIONS_SCIENTIFIC_ADMISSION=NO')
