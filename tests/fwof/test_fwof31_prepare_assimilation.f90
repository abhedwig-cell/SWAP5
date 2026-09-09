program test_fwof31_prepare_assimilation
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  use mod_wofost_prepare_assimilation
  implicit none

  real(real64), parameter :: AMAX_RAW(6) = [0.0_real64, 30.0_real64, 1.0_real64, 36.0_real64, 2.0_real64, 24.0_real64]
  real(real64), parameter :: TMPF_RAW(6) = [-10.0_real64, 0.50_real64, 20.0_real64, 1.0_real64, 50.0_real64, 0.75_real64]
  real(real64), parameter :: TMNF_RAW(6) = [-10.0_real64, 0.20_real64, 10.0_real64, 0.80_real64, 30.0_real64, 1.0_real64]

  type(wofost_one_day_rate_state_view_t) :: state, state_before, zero_lai_state
  type(wofost_rate_parameter_bundle_t) :: bundle, zero_amax_bundle, bad_amax_bundle
  type(wofost_rate_scalar_parameters_t) :: scalars_before, scalars_after
  type(wofost_prepare_assimilation_forcing_t) :: forcing, bad_forcing
  type(wofost_prepare_assimilation_result_t) :: result
  real(real64) :: expected, before_amax, after_amax, nan_value
  integer :: status, parameter_status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call make_state(state)
  call make_bundle(bundle, AMAX_RAW)
  call make_forcing(forcing)

  call legacy_actual_pgass(state%development_stage, state%actual_leaf_area_index, forcing, &
       bundle%scalar_view(), AMAX_RAW, TMPF_RAW, TMNF_RAW, expected)
  call prepare_wofost_actual_assimilation(state, bundle, forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'valid actual PGASS status')
  call require(bitwise_equal(result%actual_pgass, expected), 'actual PGASS must be bitwise source transcript equivalent')
  print '(a)', 'FWOF31_B110_ACTUAL_PGASS_BITWISE_TRANSCRIPT_EQUIVALENCE=PASS'

  state_before = state
  scalars_before = bundle%scalar_view()
  call bundle%evaluate_maximum_assimilation(0.5_real64, before_amax, parameter_status)
  call require(parameter_status == WOFOST_RATE_PARAMETER_OK, 'pre-read AMAX')
  call prepare_wofost_actual_assimilation(state, bundle, forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'read-only call status')
  scalars_after = bundle%scalar_view()
  call bundle%evaluate_maximum_assimilation(0.5_real64, after_amax, parameter_status)
  call require(parameter_status == WOFOST_RATE_PARAMETER_OK, 'post-read AMAX')
  call require_state_bitwise_equal(state, state_before, 'state view read-only')
  call require_scalars_bitwise_equal(scalars_before, scalars_after, 'parameter scalars read-only')
  call require(bitwise_equal(before_amax, after_amax), 'parameter table read-only')
  print '(a)', 'FWOF31_STATE_AND_PARAMETERS_READ_ONLY=PASS'

  zero_lai_state = state
  zero_lai_state%actual_leaf_area_index = 0.0_real64
  bad_forcing = forcing
  bad_forcing%daily_effective_solar_height = 0.0_real64
  call prepare_wofost_actual_assimilation(zero_lai_state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'LAI zero short circuit')
  call require(bitwise_equal(result%actual_pgass, 0.0_real64), 'LAI zero exact result')

  bad_forcing = forcing
  bad_forcing%global_radiation = 0.0_real64
  bad_forcing%daily_effective_solar_height = 0.0_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'RAD zero short circuit')
  call require(bitwise_equal(result%actual_pgass, 0.0_real64), 'RAD zero exact result')

  call make_bundle(zero_amax_bundle, [0.0_real64, 0.0_real64, 1.0_real64, 0.0_real64, 2.0_real64, 0.0_real64])
  bad_forcing = forcing
  bad_forcing%daily_effective_solar_height = 0.0_real64
  call prepare_wofost_actual_assimilation(state, zero_amax_bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'AMAX zero short circuit')
  call require(bitwise_equal(result%actual_pgass, 0.0_real64), 'AMAX zero exact result')
  print '(a)', 'FWOF31_ZERO_ASSIMILATION_SHORT_CIRCUITS=PASS'

  bad_forcing = forcing
  bad_forcing%daily_effective_solar_height = 0.0_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_SOLAR_GEOMETRY, 'active DSINBE zero rejected')

  bad_forcing = forcing
  bad_forcing%sine_solar_height_offset = 0.0_real64
  bad_forcing%sine_solar_height_amplitude = 0.0_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_SOLAR_GEOMETRY, 'active SINB zero rejected')
  print '(a)', 'FWOF31_ACTIVE_SOLAR_DENOMINATORS_FAIL_CLOSED=PASS'

  bad_forcing = forcing
  bad_forcing%co2_efficiency_factor = 0.0_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_ZERO_EFFICIENCY_DIRECT_BEAM, &
       'zero effective EFF with direct beam rejected')

  bad_forcing%global_radiation = 0.0_real64
  bad_forcing%daily_effective_solar_height = 0.0_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_OK, 'zero EFF unused on zero-radiation route')
  call require(bitwise_equal(result%actual_pgass, 0.0_real64), 'zero EFF zero-radiation exact result')
  print '(a)', 'FWOF31_ZERO_EFFC_DIRECT_BEAM_FAILS_CLOSED=PASS'

  bad_forcing = forcing
  bad_forcing%co2_amax_factor = 2.1_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING, 'CO2 AMAX factor upper range')

  bad_forcing = forcing
  bad_forcing%global_radiation = 5000000.1_real64
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING, 'RAD upper range')

  bad_forcing = forcing
  bad_forcing%daytime_mean_temperature = nan_value
  call prepare_wofost_actual_assimilation(state, bundle, bad_forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING, 'nonfinite forcing')

  call make_bundle(bad_amax_bundle, [0.0_real64, 101.0_real64, 1.0_real64, 101.0_real64, 2.0_real64, 101.0_real64])
  call prepare_wofost_actual_assimilation(state, bad_amax_bundle, forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR, 'AMAX biological source range')
  print '(a)', 'FWOF31_SOURCE_BOUND_FORCING_AND_TABLE_RANGES=PASS'

  state_before = state
  state_before%development_stage = nan_value
  call prepare_wofost_actual_assimilation(state_before, bundle, forcing, result, status)
  call require(status == WOFOST_PREPARE_ASSIMILATION_INVALID_STATE_VIEW, 'nonfinite state view')
  print '(a)', 'FWOF31_NONFINITE_STATE_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS'

  print '(a)', 'FWOF31_PREPARE_ASSIMILATION_TEST PASS'

contains

  subroutine make_state(s)
    type(wofost_one_day_rate_state_view_t), intent(out) :: s
    s = wofost_one_day_rate_state_view_t()
    s%development_stage = 0.5_real64
    s%actual_root_biomass = 1000.0_real64
    s%actual_stem_biomass = 800.0_real64
    s%actual_storage_biomass = 100.0_real64
    s%living_leaf_biomass = 1200.0_real64
    s%actual_leaf_area_index = 3.0_real64
    s%exponential_leaf_area_index = 4.0_real64
  end subroutine make_state

  subroutine make_forcing(f)
    type(wofost_prepare_assimilation_forcing_t), intent(out) :: f
    f = wofost_prepare_assimilation_forcing_t()
    f%daytime_mean_temperature = 20.0_real64
    f%global_radiation = 2000000.0_real64
    f%daylength_hours = 12.0_real64
    f%sine_solar_height_offset = 0.4_real64
    f%sine_solar_height_amplitude = 0.5_real64
    f%diffuse_irradiation_perpendicular = 200.0_real64
    f%daily_effective_solar_height = 30000.0_real64
    f%co2_efficiency_factor = 1.10_real64
    f%co2_amax_factor = 1.05_real64
    f%running_minimum_temperature = 10.0_real64
  end subroutine make_forcing

  subroutine make_bundle(b, amax_raw)
    type(wofost_rate_parameter_bundle_t), intent(out) :: b
    real(real64), intent(in) :: amax_raw(6)
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: st

    s = wofost_rate_scalar_parameters_t()
    s%development_daylength_mode = 0
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 800.0_real64
    s%diffuse_extinction_coefficient = 0.6_real64
    s%initial_light_use_efficiency = 0.45_real64
    s%co2_to_dry_matter_fraction = 0.4_real64
    s%attainable_yield_multiplier = 0.9_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.65_real64
    s%conversion_efficiency_leaf = 0.72_real64
    s%conversion_efficiency_storage = 0.8_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.02_real64
    s%maintenance_respiration_stem = 0.015_real64
    s%maintenance_respiration_storage = 0.005_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.04_real64

    call compact_three_knot_table(amax_raw, t%maximum_assimilation)
    call compact_three_knot_table(TMPF_RAW, t%daytime_temperature_factor)
    call compact_three_knot_table(TMNF_RAW, t%minimum_temperature_factor)
    call constant_table(10.0_real64, t%temperature_sum_increment)
    call constant_table(1.0_real64, t%maintenance_respiration_factor)
    call constant_table(0.2_real64, t%root_partition_fraction)
    call constant_table(0.4_real64, t%leaf_partition_fraction)
    call constant_table(0.4_real64, t%stem_partition_fraction)
    call constant_table(0.2_real64, t%storage_partition_fraction)
    call constant_table(0.01_real64, t%relative_root_death_rate)
    call constant_table(0.01_real64, t%relative_stem_death_rate)
    call constant_table(0.02_real64, t%specific_leaf_area)

    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_OK, 'test parameter bundle construction')
  end subroutine make_bundle

  subroutine compact_three_knot_table(raw, table)
    real(real64), intent(in) :: raw(6)
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(3), y(3)
    integer :: st
    x = [raw(1), raw(3), raw(5)]
    y = [raw(2), raw(4), raw(6)]
    call construct_wofost_rate_table(x, y, table, st)
    call require(st == WOFOST_RATE_TABLE_OK, 'three-knot table construction')
  end subroutine compact_three_knot_table

  subroutine constant_table(value, table)
    real(real64), intent(in) :: value
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(1), y(1)
    integer :: st
    x = [0.0_real64]
    y = [value]
    call construct_wofost_rate_table(x, y, table, st)
    call require(st == WOFOST_RATE_TABLE_OK, 'constant table construction')
  end subroutine constant_table

  subroutine legacy_actual_pgass(dvs, lai, f, s, amaxtb, tmpftb, tmnftb, pgass)
    real(real64), intent(in) :: dvs, lai
    type(wofost_prepare_assimilation_forcing_t), intent(in) :: f
    type(wofost_rate_scalar_parameters_t), intent(in) :: s
    real(real64), intent(in) :: amaxtb(6), tmpftb(6), tmnftb(6)
    real(real64), intent(out) :: pgass
    real(real64) :: effc, amax, dtga

    effc = f%co2_efficiency_factor * s%initial_light_use_efficiency
    amax = f%co2_amax_factor * legacy_afgen(amaxtb, 6, dvs) * &
         legacy_afgen(tmpftb, 6, f%daytime_mean_temperature)
    call legacy_totass(f%daylength_hours, amax, effc, lai, f%diffuse_irradiation_perpendicular, &
         f%daily_effective_solar_height, f%sine_solar_height_offset, f%sine_solar_height_amplitude, &
         f%global_radiation, s%diffuse_extinction_coefficient, dtga)
    dtga = dtga * legacy_afgen(tmnftb, 6, f%running_minimum_temperature)
    pgass = dtga * 30.0_real64 * (0.4_real64 / s%co2_to_dry_matter_fraction) / 44.0_real64
    pgass = pgass * s%attainable_yield_multiplier
  end subroutine legacy_actual_pgass

  real(real64) function legacy_afgen(table, iltab, x) result(value)
    integer, intent(in) :: iltab
    real(real64), intent(in) :: table(iltab), x
    integer :: i
    real(real64) :: slope

    if (table(1) >= x) goto 40
    do i = 3, iltab-1, 2
      if (table(i) >= x) goto 30
      if (table(i) < table(i-2)) goto 20
    end do
    value = table(iltab)
    return
20  value = table(i-1)
    return
30  slope = (table(i+1)-table(i-1))/(table(i)-table(i-2))
    value = table(i-1) + (x-table(i-2))*slope
    return
40  value = table(2)
  end function legacy_afgen

  subroutine legacy_totass(dayl, amax, eff, lai, difpp, dsinbe, sinld, cosld, rad, kdif, dtga)
    real(real64), intent(in) :: dayl, amax, eff, lai, difpp, dsinbe, sinld, cosld, rad, kdif
    real(real64), intent(out) :: dtga
    integer :: i
    real(real64) :: hour, sinb, par, pardif, pardir, fgros
    real(real64), parameter :: pi = 3.141592653589793238462643383279502884197_real64
    real(real64), parameter :: xgauss(3) = [0.1127017_real64, 0.5000000_real64, 0.8872983_real64]
    real(real64), parameter :: wgauss(3) = [0.2777778_real64, 0.4444444_real64, 0.2777778_real64]

    dtga = 0.0_real64
    if (amax > 0.0_real64 .and. lai > 0.0_real64) then
      do i = 1, 3
        hour = 12.0_real64 + 0.5_real64 * dayl * xgauss(i)
        sinb = max(0.0_real64, sinld + cosld * dcos(2.0_real64 * pi * (hour + 12.0_real64) / 24.0_real64))
        par = 0.5_real64 * rad * sinb * (1.0_real64 + 0.4_real64 * sinb) / dsinbe
        pardif = min(par, sinb * difpp)
        pardir = par - pardif
        call legacy_assim(amax, eff, lai, sinb, pardir, pardif, kdif, fgros)
        dtga = dtga + fgros * wgauss(i)
      end do
      dtga = dtga * dayl
    end if
  end subroutine legacy_totass

  subroutine legacy_assim(amax, eff, lai, sinb, pardir, pardif, kdif, fgros)
    real(real64), intent(in) :: amax, eff, lai, sinb, pardir, pardif, kdif
    real(real64), intent(out) :: fgros
    integer :: i
    real(real64) :: refh, refs, kdirbl, kdirt, laic, visdf, vist, visd, visshd
    real(real64) :: fgrsh, vispp, fgrsun, fslla, fgl
    real(real64), parameter :: scv = 0.2_real64
    real(real64), parameter :: sqrt_scv = (1.0_real64 - scv)**0.5_real64
    real(real64), parameter :: xgauss(3) = [0.1127017_real64, 0.5000000_real64, 0.8872983_real64]
    real(real64), parameter :: wgauss(3) = [0.2777778_real64, 0.4444444_real64, 0.2777778_real64]

    refh = (1.0_real64 - sqrt_scv) / (1.0_real64 + sqrt_scv)
    refs = refh * 2.0_real64 / (1.0_real64 + 1.6_real64 * sinb)
    kdirbl = (0.5_real64 / sinb) * kdif / (0.8_real64 * sqrt_scv)
    kdirt = kdirbl * sqrt_scv
    fgros = 0.0_real64
    do i = 1, 3
      laic = lai * xgauss(i)
      visdf = (1.0_real64 - refs) * pardif * kdif * exp(-kdif * laic)
      vist = (1.0_real64 - refs) * pardir * kdirt * exp(-kdirt * laic)
      visd = (1.0_real64 - scv) * pardir * kdirbl * exp(-kdirbl * laic)
      visshd = visdf + vist - visd
      fgrsh = amax * (1.0_real64 - exp(-visshd * eff / max(2.0_real64,amax)))
      vispp = (1.0_real64 - scv) * pardir / sinb
      if (vispp <= 0.0_real64) then
        fgrsun = fgrsh
      else
        fgrsun = amax * (1.0_real64 - (amax - fgrsh) * &
             (1.0_real64 - exp(-vispp * eff / max(2.0_real64, amax))) / (eff * vispp))
      end if
      fslla = exp(-kdirbl * laic)
      fgl = fslla * fgrsun + (1.0_real64 - fslla) * fgrsh
      fgros = fgros + fgl * wgauss(i)
    end do
    fgros = fgros * lai
  end subroutine legacy_assim

  subroutine require_state_bitwise_equal(a, b, label)
    type(wofost_one_day_rate_state_view_t), intent(in) :: a, b
    character(*), intent(in) :: label
    call require(bitwise_equal(a%development_stage, b%development_stage), label)
    call require(bitwise_equal(a%actual_root_biomass, b%actual_root_biomass), label)
    call require(bitwise_equal(a%actual_stem_biomass, b%actual_stem_biomass), label)
    call require(bitwise_equal(a%actual_storage_biomass, b%actual_storage_biomass), label)
    call require(bitwise_equal(a%living_leaf_biomass, b%living_leaf_biomass), label)
    call require(bitwise_equal(a%actual_leaf_area_index, b%actual_leaf_area_index), label)
    call require(bitwise_equal(a%exponential_leaf_area_index, b%exponential_leaf_area_index), label)
  end subroutine require_state_bitwise_equal

  subroutine require_scalars_bitwise_equal(a, b, label)
    type(wofost_rate_scalar_parameters_t), intent(in) :: a, b
    character(*), intent(in) :: label
    call require(a%development_daylength_mode == b%development_daylength_mode, label)
    call require(bitwise_equal(a%daylength_upper_hours, b%daylength_upper_hours), label)
    call require(bitwise_equal(a%daylength_lower_hours, b%daylength_lower_hours), label)
    call require(bitwise_equal(a%vegetative_temperature_sum_required, b%vegetative_temperature_sum_required), label)
    call require(bitwise_equal(a%generative_temperature_sum_required, b%generative_temperature_sum_required), label)
    call require(bitwise_equal(a%diffuse_extinction_coefficient, b%diffuse_extinction_coefficient), label)
    call require(bitwise_equal(a%initial_light_use_efficiency, b%initial_light_use_efficiency), label)
    call require(bitwise_equal(a%co2_to_dry_matter_fraction, b%co2_to_dry_matter_fraction), label)
    call require(bitwise_equal(a%attainable_yield_multiplier, b%attainable_yield_multiplier), label)
    call require(bitwise_equal(a%conversion_efficiency_root, b%conversion_efficiency_root), label)
    call require(bitwise_equal(a%conversion_efficiency_stem, b%conversion_efficiency_stem), label)
    call require(bitwise_equal(a%conversion_efficiency_leaf, b%conversion_efficiency_leaf), label)
    call require(bitwise_equal(a%conversion_efficiency_storage, b%conversion_efficiency_storage), label)
    call require(bitwise_equal(a%respiration_temperature_q10, b%respiration_temperature_q10), label)
    call require(bitwise_equal(a%maintenance_respiration_root, b%maintenance_respiration_root), label)
    call require(bitwise_equal(a%maintenance_respiration_leaf, b%maintenance_respiration_leaf), label)
    call require(bitwise_equal(a%maintenance_respiration_stem, b%maintenance_respiration_stem), label)
    call require(bitwise_equal(a%maintenance_respiration_storage, b%maintenance_respiration_storage), label)
    call require(bitwise_equal(a%maximum_leaf_relative_death_rate, b%maximum_leaf_relative_death_rate), label)
    call require(bitwise_equal(a%leaf_age_base_temperature, b%leaf_age_base_temperature), label)
    call require(bitwise_equal(a%maximum_relative_lai_growth_rate, b%maximum_relative_lai_growth_rate), label)
  end subroutine require_scalars_bitwise_equal

  logical function bitwise_equal(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function bitwise_equal

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof31_prepare_assimilation
