program test_fwof32_finalize_rates
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_result_t
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t, &
       wofost_one_day_rate_packet_t
  use mod_wofost_finalize_rates
  implicit none

  real(real64), parameter :: DTSM_RAW(6) = [-10.0_real64, 0.0_real64, 20.0_real64, 10.0_real64, 40.0_real64, 20.0_real64]
  real(real64), parameter :: RFSE_RAW(6) = [0.0_real64, 1.0_real64, 1.0_real64, 0.8_real64, 2.0_real64, 0.6_real64]

  type(wofost_one_day_rate_state_view_t) :: state, state_before, carry_state
  type(wofost_rate_parameter_bundle_t) :: bundle, idsl0_bundle, cvo_zero_bundle, &
       cvo_zero_fo_zero_bundle, bad_partition_bundle, negative_dtsum_bundle, bad_rfse_bundle
  type(wofost_rate_scalar_parameters_t) :: scalars_before, scalars_after
  type(wofost_prepare_assimilation_result_t) :: prepared, prepared_before, bad_prepared
  type(wofost_accepted_window_aggregates_t) :: aggregates, aggregates_before, tiny_potential, bad_aggregates
  type(wofost_finalize_rate_forcing_t) :: forcing, idsl0_forcing, bad_forcing
  type(wofost_one_day_rate_packet_t) :: rates, expected
  real(real64) :: nan_value, before_table, after_table
  integer :: status, parameter_status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call make_state(state)
  call make_bundle(bundle, 1, 0.8_real64, 0.2_real64, 0.4_real64, 0.4_real64, 0.2_real64, 10.0_real64, 1.0_real64)
  prepared%actual_pgass = 250.0_real64
  aggregates%actual_root_uptake = 3.0_real64
  aggregates%potential_transpiration = 5.0_real64
  forcing%average_temperature = 20.0_real64
  forcing%photoperiodic_daylength_hours = 12.0_real64

  call legacy_finalize_transcript(state, bundle%scalar_view(), prepared, aggregates, forcing, expected)
  call finalize_wofost_one_day_rates(state, bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'valid finalize-rate status')
  call require_packet_bitwise_equal(rates, expected, 'full rate packet source transcript')
  print '(a)', 'FWOF32_B110_FULL_RATE_PACKET_BITWISE_TRANSCRIPT_EQUIVALENCE=PASS'

  state_before = state
  prepared_before = prepared
  aggregates_before = aggregates
  scalars_before = bundle%scalar_view()
  call bundle%evaluate_maintenance_respiration_factor(0.5_real64, before_table, parameter_status)
  call require(parameter_status == WOFOST_RATE_PARAMETER_OK, 'pre-read RFSE')
  call finalize_wofost_one_day_rates(state, bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'read-only call status')
  scalars_after = bundle%scalar_view()
  call bundle%evaluate_maintenance_respiration_factor(0.5_real64, after_table, parameter_status)
  call require(parameter_status == WOFOST_RATE_PARAMETER_OK, 'post-read RFSE')
  call require_state_bitwise_equal(state, state_before, 'state read-only')
  call require(bitwise_equal(prepared%actual_pgass, prepared_before%actual_pgass), 'prepared result read-only')
  call require(bitwise_equal(aggregates%actual_root_uptake, aggregates_before%actual_root_uptake), 'IQROT read-only')
  call require(bitwise_equal(aggregates%potential_transpiration, aggregates_before%potential_transpiration), 'IPTRA read-only')
  call require_scalars_bitwise_equal(scalars_before, scalars_after, 'parameter scalar read-only')
  call require(bitwise_equal(before_table, after_table), 'parameter table read-only')
  print '(a)', 'FWOF32_STATE_PARAMETERS_PREPARED_AND_AGGREGATES_READ_ONLY=PASS'

  tiny_potential%actual_root_uptake = 0.0_real64
  tiny_potential%potential_transpiration = 0.5e-10_real64
  call finalize_wofost_one_day_rates(state, bundle, prepared, tiny_potential, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'tiny IPTRA route')
  call require(bitwise_equal(rates%relative_transpiration_used, 1.0_real64), 'B1.10 tiny IPTRA reltr')
  print '(a)', 'FWOF32_B110_RELTR_NEGLIGIBLE_IPTRA_SEMANTICS=PASS'

  call make_bundle(idsl0_bundle, 0, 0.8_real64, 0.2_real64, 0.4_real64, 0.4_real64, 0.2_real64, 10.0_real64, 1.0_real64)
  idsl0_forcing = forcing
  idsl0_forcing%photoperiodic_daylength_hours = nan_value
  call finalize_wofost_one_day_rates(state, idsl0_bundle, prepared, aggregates, idsl0_forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'IDSL0 ignores DAYLP')
  call require(bitwise_equal(rates%development_rate, 10.0_real64 / 1000.0_real64), 'IDSL0 temperature-only DVR')
  print '(a)', 'FWOF32_IDSL0_HAS_NO_DAYLP_DEPENDENCY=PASS'

  carry_state = state
  carry_state%exponential_leaf_area_index = 6.0_real64
  call finalize_wofost_one_day_rates(carry_state, bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'LAIEXP carryover boundary')
  call require(.not. rates%lai_exponential_rate_recomputed, 'LAIEXP carryover must not be recomputed')
  call require(bitwise_equal(rates%lai_exponential_growth_rate, 0.0_real64), 'ignored carryover packet slot canonical zero')
  print '(a)', 'FWOF32_GLAIEXP_RECOMPUTE_VS_CARRYOVER_CONTRACT=PASS'

  call make_bundle(cvo_zero_bundle, 1, 0.0_real64, 0.2_real64, 0.4_real64, 0.4_real64, 0.2_real64, 10.0_real64, 1.0_real64)
  call finalize_wofost_one_day_rates(state, cvo_zero_bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_CVO_STORAGE_CONFLICT, 'CVO zero with FO positive rejected')

  call make_bundle(cvo_zero_fo_zero_bundle, 1, 0.0_real64, 0.2_real64, 0.5_real64, 0.5_real64, 0.0_real64, 10.0_real64, 1.0_real64)
  call finalize_wofost_one_day_rates(state, cvo_zero_fo_zero_bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_OK, 'CVO zero with FO zero admitted')
  call require(bitwise_equal(rates%storage_net_growth_rate, 0.0_real64), 'FO zero storage growth exact zero')
  print '(a)', 'FWOF32_CVO_ZERO_STORAGE_ALLOCATION_STRENGTHENING=PASS'

  call make_bundle(bad_partition_bundle, 1, 0.8_real64, 0.2_real64, 0.3_real64, 0.3_real64, 0.1_real64, 10.0_real64, 1.0_real64)
  call finalize_wofost_one_day_rates(state, bad_partition_bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_PARTITION_ERROR, 'invalid partition closure rejected')
  print '(a)', 'FWOF32_B110_PARTITION_CHECK_FAILS_CLOSED=PASS'

  call make_bundle(negative_dtsum_bundle, 1, 0.8_real64, 0.2_real64, 0.4_real64, 0.4_real64, 0.2_real64, -1.0_real64, 1.0_real64)
  call finalize_wofost_one_day_rates(state, negative_dtsum_bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_RESTRICTED_DTSUM, 'negative DTSUM rejected by restricted packet contract')
  print '(a)', 'FWOF32_NEGATIVE_DTSUM_RESTRICTED_PROFILE_FAILS_CLOSED=PASS'

  call make_bundle(bad_rfse_bundle, 1, 0.8_real64, 0.2_real64, 0.4_real64, 0.4_real64, 0.2_real64, 10.0_real64, 1.1_real64)
  call finalize_wofost_one_day_rates(state, bad_rfse_bundle, prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_TABLE_ERROR, 'RFSE outside B1.10 y range')

  bad_prepared = prepared
  bad_prepared%actual_pgass = -1.0_real64
  call finalize_wofost_one_day_rates(state, bundle, bad_prepared, aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_INVALID_PREPARED, 'negative prepared PGASS')

  bad_aggregates = aggregates
  bad_aggregates%actual_root_uptake = nan_value
  call finalize_wofost_one_day_rates(state, bundle, prepared, bad_aggregates, forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_INVALID_AGGREGATES, 'nonfinite accepted aggregate')

  bad_forcing = forcing
  bad_forcing%photoperiodic_daylength_hours = 24.1_real64
  call finalize_wofost_one_day_rates(state, bundle, prepared, aggregates, bad_forcing, rates, status)
  call require(status == WOFOST_FINALIZE_RATES_INVALID_FORCING, 'IDSL1 DAYLP upper range')
  print '(a)', 'FWOF32_INPUT_AND_TABLE_DOMAIN_VALIDATION=PASS'

  print '(a)', 'FWOF32_FINALIZE_RATES_TEST PASS'

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

  subroutine make_bundle(b, idsl, cvo, fr_value, fl_value, fs_value, fo_value, dtsum_value, rfse_value)
    type(wofost_rate_parameter_bundle_t), intent(out) :: b
    integer, intent(in) :: idsl
    real(real64), intent(in) :: cvo, fr_value, fl_value, fs_value, fo_value, dtsum_value, rfse_value
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: st

    s = wofost_rate_scalar_parameters_t()
    s%development_daylength_mode = idsl
    s%daylength_upper_hours = 16.0_real64
    s%daylength_lower_hours = 8.0_real64
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 800.0_real64
    s%diffuse_extinction_coefficient = 0.6_real64
    s%initial_light_use_efficiency = 0.45_real64
    s%co2_to_dry_matter_fraction = 0.4_real64
    s%attainable_yield_multiplier = 0.9_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.65_real64
    s%conversion_efficiency_leaf = 0.72_real64
    s%conversion_efficiency_storage = cvo
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.02_real64
    s%maintenance_respiration_stem = 0.015_real64
    s%maintenance_respiration_storage = 0.005_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.04_real64

    if (dtsum_value == 10.0_real64) then
      call compact_three_knot_table(DTSM_RAW, t%temperature_sum_increment)
    else
      call constant_table(dtsum_value, t%temperature_sum_increment)
    end if
    call constant_table(30.0_real64, t%maximum_assimilation)
    call constant_table(1.0_real64, t%daytime_temperature_factor)
    call constant_table(1.0_real64, t%minimum_temperature_factor)
    if (rfse_value == 1.0_real64) then
      call compact_three_knot_table(RFSE_RAW, t%maintenance_respiration_factor)
    else
      call constant_table(rfse_value, t%maintenance_respiration_factor)
    end if
    call constant_table(fr_value, t%root_partition_fraction)
    call constant_table(fl_value, t%leaf_partition_fraction)
    call constant_table(fs_value, t%stem_partition_fraction)
    call constant_table(fo_value, t%storage_partition_fraction)
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

  subroutine legacy_finalize_transcript(s, p, a, agg, f, packet)
    type(wofost_one_day_rate_state_view_t), intent(in) :: s
    type(wofost_rate_scalar_parameters_t), intent(in) :: p
    type(wofost_prepare_assimilation_result_t), intent(in) :: a
    type(wofost_accepted_window_aggregates_t), intent(in) :: agg
    type(wofost_finalize_rate_forcing_t), intent(in) :: f
    type(wofost_one_day_rate_packet_t), intent(out) :: packet
    real(real64) :: reltr, dtsum, dvred, dvr, rfse, fr, fl, fs, fo, rdrr, rdrst, slat
    real(real64) :: gass, rmres, teff, mres, asrc, help, cvf, dmi
    real(real64) :: admi, grrt, grlv, grst, grso, dslv1, dslv2, laicr, dslv
    real(real64) :: drst, drrt, fysdel, dteff, glaiex, glasol, gla

    reltr = 1.0_real64
    if (abs(agg%potential_transpiration) >= 1.0e-10_real64) then
      reltr = max(0.0_real64, min(1.0_real64, agg%actual_root_uptake / agg%potential_transpiration))
    end if
    dtsum = legacy_afgen(DTSM_RAW, 6, f%average_temperature)
    dvred = 1.0_real64
    if (p%development_daylength_mode >= 1) then
      dvred = max(0.0_real64, min(1.0_real64, &
           (f%photoperiodic_daylength_hours - p%daylength_lower_hours) / &
           (p%daylength_upper_hours - p%daylength_lower_hours)))
    end if
    if (s%development_stage < 1.0_real64) then
      dvr = dvred * dtsum / p%vegetative_temperature_sum_required
    else
      dvr = dtsum / p%generative_temperature_sum_required
    end if

    gass = a%actual_pgass * reltr
    rfse = legacy_afgen(RFSE_RAW, 6, s%development_stage)
    rmres = (p%maintenance_respiration_root * s%actual_root_biomass + &
         p%maintenance_respiration_leaf * s%living_leaf_biomass + &
         p%maintenance_respiration_stem * s%actual_stem_biomass + &
         p%maintenance_respiration_storage * s%actual_storage_biomass) * rfse
    teff = p%respiration_temperature_q10 ** ((f%average_temperature - 25.0_real64) / 10.0_real64)
    mres = min(gass, rmres * teff)
    asrc = gass - mres

    fr = 0.2_real64
    fl = 0.4_real64
    fs = 0.4_real64
    fo = 0.2_real64
    help = 0.0_real64
    if (p%conversion_efficiency_storage > 0.0_real64) help = fo / p%conversion_efficiency_storage
    cvf = 1.0_real64 / ((fl / p%conversion_efficiency_leaf + fs / p%conversion_efficiency_stem + help) * &
         (1.0_real64 - fr) + fr / p%conversion_efficiency_root)
    dmi = cvf * asrc

    admi = (1.0_real64 - fr) * dmi
    grrt = fr * dmi
    grlv = fl * admi
    grst = fs * admi
    grso = fo * admi

    dslv1 = s%living_leaf_biomass * (1.0_real64 - reltr) * p%maximum_leaf_relative_death_rate
    laicr = 3.2_real64 / p%diffuse_extinction_coefficient
    dslv2 = s%living_leaf_biomass * max(0.0_real64, min(0.03_real64, &
         0.03_real64 * (s%actual_leaf_area_index - laicr) / laicr))
    dslv = max(dslv1, dslv2)

    rdrst = 0.01_real64
    rdrr = 0.01_real64
    drst = s%actual_stem_biomass * rdrst
    drrt = s%actual_root_biomass * rdrr
    fysdel = max(0.0_real64, (f%average_temperature - p%leaf_age_base_temperature) / &
         (35.0_real64 - p%leaf_age_base_temperature))
    slat = 0.02_real64
    glaiex = 0.0_real64
    packet%lai_exponential_rate_recomputed = .false.
    if (s%exponential_leaf_area_index < 6.0_real64) then
      dteff = max(0.0_real64, f%average_temperature - p%leaf_age_base_temperature)
      glaiex = reltr * s%exponential_leaf_area_index * p%maximum_relative_lai_growth_rate * dteff
      glasol = grlv * slat
      gla = min(glaiex, glasol)
      if (grlv > 0.0_real64) slat = gla / grlv
      packet%lai_exponential_rate_recomputed = .true.
    end if

    packet%temperature_sum_increment = dtsum
    packet%development_rate = dvr
    packet%root_net_growth_rate = grrt - drrt
    packet%stem_net_growth_rate = grst - drst
    packet%storage_net_growth_rate = grso
    packet%leaf_growth_rate = grlv
    packet%leaf_stress_death_rate = dslv
    packet%leaf_age_increment = fysdel
    packet%youngest_specific_leaf_area = slat
    packet%lai_exponential_growth_rate = glaiex
    packet%relative_transpiration_used = reltr
  end subroutine legacy_finalize_transcript

  real(real64) function legacy_afgen(table, iltab, x) result(value)
    integer, intent(in) :: iltab
    real(real64), intent(in) :: table(iltab), x
    integer :: i
    real(real64) :: slope

    if (table(1) >= x) goto 40
    do i = 3, iltab-1, 2
      if (table(i) >= x) then
        slope = (table(i+1) - table(i-1)) / (table(i) - table(i-2))
        value = table(i-1) + (x - table(i-2)) * slope
        return
      end if
    end do
    i = iltab + 1
40  value = table(i-1)
  end function legacy_afgen

  logical function bitwise_equal(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function bitwise_equal

  subroutine require_packet_bitwise_equal(left, right, label)
    type(wofost_one_day_rate_packet_t), intent(in) :: left, right
    character(len=*), intent(in) :: label
    call require(bitwise_equal(left%temperature_sum_increment, right%temperature_sum_increment), trim(label)//' dtsum')
    call require(bitwise_equal(left%development_rate, right%development_rate), trim(label)//' dvr')
    call require(bitwise_equal(left%root_net_growth_rate, right%root_net_growth_rate), trim(label)//' gwrt')
    call require(bitwise_equal(left%stem_net_growth_rate, right%stem_net_growth_rate), trim(label)//' gwst')
    call require(bitwise_equal(left%storage_net_growth_rate, right%storage_net_growth_rate), trim(label)//' gwso')
    call require(bitwise_equal(left%leaf_growth_rate, right%leaf_growth_rate), trim(label)//' grlv')
    call require(bitwise_equal(left%leaf_stress_death_rate, right%leaf_stress_death_rate), trim(label)//' dslv')
    call require(bitwise_equal(left%leaf_age_increment, right%leaf_age_increment), trim(label)//' fysdel')
    call require(bitwise_equal(left%youngest_specific_leaf_area, right%youngest_specific_leaf_area), trim(label)//' slat')
    call require(bitwise_equal(left%lai_exponential_growth_rate, right%lai_exponential_growth_rate), trim(label)//' glaiex')
    call require(left%lai_exponential_rate_recomputed .eqv. right%lai_exponential_rate_recomputed, trim(label)//' glaiex flag')
    call require(bitwise_equal(left%relative_transpiration_used, right%relative_transpiration_used), trim(label)//' reltr')
  end subroutine require_packet_bitwise_equal

  subroutine require_state_bitwise_equal(left, right, label)
    type(wofost_one_day_rate_state_view_t), intent(in) :: left, right
    character(len=*), intent(in) :: label
    call require(bitwise_equal(left%development_stage, right%development_stage), trim(label)//' dvs')
    call require(bitwise_equal(left%actual_root_biomass, right%actual_root_biomass), trim(label)//' wrt')
    call require(bitwise_equal(left%actual_stem_biomass, right%actual_stem_biomass), trim(label)//' wst')
    call require(bitwise_equal(left%actual_storage_biomass, right%actual_storage_biomass), trim(label)//' wso')
    call require(bitwise_equal(left%living_leaf_biomass, right%living_leaf_biomass), trim(label)//' wlv')
    call require(bitwise_equal(left%actual_leaf_area_index, right%actual_leaf_area_index), trim(label)//' lai')
    call require(bitwise_equal(left%exponential_leaf_area_index, right%exponential_leaf_area_index), trim(label)//' laiexp')
  end subroutine require_state_bitwise_equal

  subroutine require_scalars_bitwise_equal(left, right, label)
    type(wofost_rate_scalar_parameters_t), intent(in) :: left, right
    character(len=*), intent(in) :: label
    call require(left%development_daylength_mode == right%development_daylength_mode, trim(label)//' idsl')
    call require(bitwise_equal(left%daylength_upper_hours, right%daylength_upper_hours), trim(label)//' dlo')
    call require(bitwise_equal(left%daylength_lower_hours, right%daylength_lower_hours), trim(label)//' dlc')
    call require(bitwise_equal(left%vegetative_temperature_sum_required, right%vegetative_temperature_sum_required), trim(label)//' tsumea')
    call require(bitwise_equal(left%generative_temperature_sum_required, right%generative_temperature_sum_required), trim(label)//' tsumam')
    call require(bitwise_equal(left%diffuse_extinction_coefficient, right%diffuse_extinction_coefficient), trim(label)//' kdif')
    call require(bitwise_equal(left%conversion_efficiency_root, right%conversion_efficiency_root), trim(label)//' cvr')
    call require(bitwise_equal(left%conversion_efficiency_stem, right%conversion_efficiency_stem), trim(label)//' cvs')
    call require(bitwise_equal(left%conversion_efficiency_leaf, right%conversion_efficiency_leaf), trim(label)//' cvl')
    call require(bitwise_equal(left%conversion_efficiency_storage, right%conversion_efficiency_storage), trim(label)//' cvo')
    call require(bitwise_equal(left%respiration_temperature_q10, right%respiration_temperature_q10), trim(label)//' q10')
    call require(bitwise_equal(left%maximum_leaf_relative_death_rate, right%maximum_leaf_relative_death_rate), trim(label)//' perdl')
    call require(bitwise_equal(left%leaf_age_base_temperature, right%leaf_age_base_temperature), trim(label)//' tbase')
    call require(bitwise_equal(left%maximum_relative_lai_growth_rate, right%maximum_relative_lai_growth_rate), trim(label)//' rgrlai')
  end subroutine require_scalars_bitwise_equal

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof32_finalize_rates
