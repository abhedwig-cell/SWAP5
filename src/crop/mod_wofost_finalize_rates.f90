module mod_wofost_finalize_rates
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, &
       wofost_rate_scalar_parameters_t, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_result_t
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t, &
       wofost_one_day_rate_packet_t, b110_relative_transpiration
  implicit none
  private

  integer, parameter, public :: WOFOST_FINALIZE_RATES_OK = 0
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_STATE_VIEW = 1
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_PARAMETERS = 2
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_PREPARED = 3
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_AGGREGATES = 4
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_FORCING = 5
  integer, parameter, public :: WOFOST_FINALIZE_RATES_TABLE_ERROR = 6
  integer, parameter, public :: WOFOST_FINALIZE_RATES_PARTITION_ERROR = 7
  integer, parameter, public :: WOFOST_FINALIZE_RATES_CVO_STORAGE_CONFLICT = 8
  integer, parameter, public :: WOFOST_FINALIZE_RATES_CARBON_BALANCE_ERROR = 9
  integer, parameter, public :: WOFOST_FINALIZE_RATES_INVALID_RESULT = 10
  integer, parameter, public :: WOFOST_FINALIZE_RATES_RESTRICTED_DTSUM = 11

  real(real64), parameter :: PARTITION_TOLERANCE = 1.0e-4_real64
  real(real64), parameter :: CARBON_TOLERANCE = 1.0e-4_real64
  real(real64), parameter :: LAIEXP_CARRYOVER_THRESHOLD = 6.0_real64

  type, public :: wofost_finalize_rate_forcing_t
    real(real64) :: average_temperature = 0.0_real64
    real(real64) :: photoperiodic_daylength_hours = 0.0_real64
  end type wofost_finalize_rate_forcing_t

  public :: finalize_wofost_one_day_rates

contains

  subroutine finalize_wofost_one_day_rates(state_view, parameters, prepared, aggregates, forcing, rates, status)
    type(wofost_one_day_rate_state_view_t), intent(in) :: state_view
    type(wofost_rate_parameter_bundle_t), intent(in) :: parameters
    type(wofost_prepare_assimilation_result_t), intent(in) :: prepared
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates
    type(wofost_finalize_rate_forcing_t), intent(in) :: forcing
    type(wofost_one_day_rate_packet_t), intent(out) :: rates
    integer, intent(out) :: status

    type(wofost_rate_scalar_parameters_t) :: scalars
    real(real64) :: reltr, dtsum, dvred, dvr
    real(real64) :: rfse, fr, fl, fs, fo, rdrr, rdrst, slat
    real(real64) :: gass, rmres, teff, mres, asrc
    real(real64) :: partition_check, help, cvf_denominator, cvf, dmi, carbon_check
    real(real64) :: admi, grrt, grlv, grst, grso
    real(real64) :: dslv1, dslv2, laicr, dslv, drst, drrt
    real(real64) :: gwst, gwrt, gwso, fysdel
    real(real64) :: dteff, glaiex, glasol, gla
    integer :: parameter_status

    rates = wofost_one_day_rate_packet_t()
    status = WOFOST_FINALIZE_RATES_INVALID_STATE_VIEW
    if (state_view%validate() /= WOFOST_RATE_STATE_VIEW_OK) return

    status = WOFOST_FINALIZE_RATES_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    scalars = parameters%scalar_view()

    status = WOFOST_FINALIZE_RATES_INVALID_PREPARED
    if (.not. ieee_is_finite(prepared%actual_pgass)) return
    if (prepared%actual_pgass < 0.0_real64) return

    status = WOFOST_FINALIZE_RATES_INVALID_AGGREGATES
    if (.not. valid_aggregates(aggregates)) return

    status = WOFOST_FINALIZE_RATES_INVALID_FORCING
    if (.not. ieee_is_finite(forcing%average_temperature)) return
    if (scalars%development_daylength_mode == 1) then
      if (.not. valid_inclusive(forcing%photoperiodic_daylength_hours, 0.0_real64, 24.0_real64)) return
    end if

    call parameters%evaluate_temperature_sum_increment(forcing%average_temperature, dtsum, parameter_status)
    if (parameter_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    if (.not. ieee_is_finite(dtsum) .or. dtsum < 0.0_real64 .or. dtsum > 100.0_real64) then
      status = WOFOST_FINALIZE_RATES_RESTRICTED_DTSUM
      return
    end if

    call parameters%evaluate_maintenance_respiration_factor(state_view%development_stage, rfse, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, rfse)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_root_partition_fraction(state_view%development_stage, fr, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, fr)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_leaf_partition_fraction(state_view%development_stage, fl, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, fl)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_stem_partition_fraction(state_view%development_stage, fs, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, fs)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_storage_partition_fraction(state_view%development_stage, fo, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, fo)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_relative_root_death_rate(state_view%development_stage, rdrr, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, rdrr)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_relative_stem_death_rate(state_view%development_stage, rdrst, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, rdrst)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if
    call parameters%evaluate_specific_leaf_area(state_view%development_stage, slat, parameter_status)
    if (.not. valid_table_unit_result(parameter_status, slat)) then
      status = WOFOST_FINALIZE_RATES_TABLE_ERROR
      return
    end if

    reltr = b110_relative_transpiration(aggregates)

    dvred = 1.0_real64
    if (scalars%development_daylength_mode == 1) then
      dvred = max(0.0_real64, min(1.0_real64, &
           (forcing%photoperiodic_daylength_hours - scalars%daylength_lower_hours) / &
           (scalars%daylength_upper_hours - scalars%daylength_lower_hours)))
    end if
    if (state_view%development_stage < 1.0_real64) then
      dvr = dvred * dtsum / scalars%vegetative_temperature_sum_required
    else
      dvr = dtsum / scalars%generative_temperature_sum_required
    end if

    ! Preserve B1.10 update_wofost arithmetic order for the restricted route.
    gass = prepared%actual_pgass * reltr
    rmres = (scalars%maintenance_respiration_root * state_view%actual_root_biomass + &
         scalars%maintenance_respiration_leaf * state_view%living_leaf_biomass + &
         scalars%maintenance_respiration_stem * state_view%actual_stem_biomass + &
         scalars%maintenance_respiration_storage * state_view%actual_storage_biomass) * rfse
    teff = scalars%respiration_temperature_q10 ** &
         ((forcing%average_temperature - 25.0_real64) / 10.0_real64)
    if (.not. ieee_is_finite(gass) .or. .not. ieee_is_finite(rmres) .or. .not. ieee_is_finite(teff)) then
      status = WOFOST_FINALIZE_RATES_INVALID_RESULT
      return
    end if
    mres = min(gass, rmres * teff)
    asrc = gass - mres

    ! Preserve the source CHCKPRT summation order: FS + FL + FO.
    partition_check = fr + (fs + fl + fo) * (1.0_real64 - fr) - 1.0_real64
    if (.not. ieee_is_finite(partition_check) .or. abs(partition_check) > PARTITION_TOLERANCE) then
      status = WOFOST_FINALIZE_RATES_PARTITION_ERROR
      return
    end if

    help = 0.0_real64
    if (scalars%conversion_efficiency_storage > 0.0_real64) then
      help = fo / scalars%conversion_efficiency_storage
    else if (fo > 0.0_real64) then
      status = WOFOST_FINALIZE_RATES_CVO_STORAGE_CONFLICT
      return
    end if

    cvf_denominator = (fl / scalars%conversion_efficiency_leaf + &
         fs / scalars%conversion_efficiency_stem + help) * (1.0_real64 - fr) + &
         fr / scalars%conversion_efficiency_root
    if (.not. ieee_is_finite(cvf_denominator) .or. cvf_denominator <= 0.0_real64) then
      status = WOFOST_FINALIZE_RATES_INVALID_RESULT
      return
    end if
    cvf = 1.0_real64 / cvf_denominator
    dmi = cvf * asrc
    if (.not. ieee_is_finite(cvf) .or. .not. ieee_is_finite(dmi)) then
      status = WOFOST_FINALIZE_RATES_INVALID_RESULT
      return
    end if

    ! Preserve the source CHCKCBL summation order: FL + FS + FO.
    carbon_check = (gass - mres - &
         (fr + (fl + fs + fo) * (1.0_real64 - fr)) * dmi / cvf) / &
         max(0.0001_real64, gass)
    if (.not. ieee_is_finite(carbon_check) .or. abs(carbon_check) > CARBON_TOLERANCE) then
      status = WOFOST_FINALIZE_RATES_CARBON_BALANCE_ERROR
      return
    end if

    admi = (1.0_real64 - fr) * dmi
    grrt = fr * dmi
    grlv = fl * admi
    grst = fs * admi
    grso = fo * admi

    dslv1 = state_view%living_leaf_biomass * (1.0_real64 - reltr) * &
         scalars%maximum_leaf_relative_death_rate
    laicr = 3.2_real64 / scalars%diffuse_extinction_coefficient
    dslv2 = state_view%living_leaf_biomass * max(0.0_real64, min(0.03_real64, &
         0.03_real64 * (state_view%actual_leaf_area_index - laicr) / laicr))
    dslv = max(dslv1, dslv2)

    drst = state_view%actual_stem_biomass * rdrst
    drrt = state_view%actual_root_biomass * rdrr
    gwst = grst - drst
    gwrt = grrt - drrt
    gwso = grso

    fysdel = max(0.0_real64, &
         (forcing%average_temperature - scalars%leaf_age_base_temperature) / &
         (35.0_real64 - scalars%leaf_age_base_temperature))

    glaiex = 0.0_real64
    if (state_view%exponential_leaf_area_index < LAIEXP_CARRYOVER_THRESHOLD) then
      dteff = max(0.0_real64, forcing%average_temperature - scalars%leaf_age_base_temperature)
      glaiex = reltr * state_view%exponential_leaf_area_index * &
           scalars%maximum_relative_lai_growth_rate * dteff
      glasol = grlv * slat
      gla = min(glaiex, glasol)
      if (grlv > 0.0_real64) slat = gla / grlv
      rates%lai_exponential_rate_recomputed = .true.
    else
      rates%lai_exponential_rate_recomputed = .false.
    end if

    rates%temperature_sum_increment = dtsum
    rates%development_rate = dvr
    rates%root_net_growth_rate = gwrt
    rates%stem_net_growth_rate = gwst
    rates%storage_net_growth_rate = gwso
    rates%leaf_growth_rate = grlv
    rates%leaf_stress_death_rate = dslv
    rates%leaf_age_increment = fysdel
    rates%youngest_specific_leaf_area = slat
    rates%lai_exponential_growth_rate = glaiex
    rates%relative_transpiration_used = reltr

    if (.not. valid_rate_packet(rates)) then
      rates = wofost_one_day_rate_packet_t()
      status = WOFOST_FINALIZE_RATES_INVALID_RESULT
      return
    end if

    status = WOFOST_FINALIZE_RATES_OK
  end subroutine finalize_wofost_one_day_rates

  logical function valid_aggregates(aggregates) result(valid)
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates

    valid = ieee_is_finite(aggregates%actual_root_uptake) .and. &
         ieee_is_finite(aggregates%potential_transpiration)
    if (.not. valid) return
    valid = aggregates%actual_root_uptake >= 0.0_real64 .and. &
         aggregates%potential_transpiration >= 0.0_real64
  end function valid_aggregates

  logical function valid_table_unit_result(parameter_status, value) result(valid)
    integer, intent(in) :: parameter_status
    real(real64), intent(in) :: value

    valid = .false.
    if (parameter_status /= WOFOST_RATE_PARAMETER_OK) return
    valid = valid_inclusive(value, 0.0_real64, 1.0_real64)
  end function valid_table_unit_result

  pure logical function valid_inclusive(value, lower, upper) result(valid)
    real(real64), intent(in) :: value, lower, upper

    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= lower .and. value <= upper
  end function valid_inclusive

  logical function valid_rate_packet(rates) result(valid)
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    real(real64) :: values(11)

    values = [rates%temperature_sum_increment, rates%development_rate, &
         rates%root_net_growth_rate, rates%stem_net_growth_rate, rates%storage_net_growth_rate, &
         rates%leaf_growth_rate, rates%leaf_stress_death_rate, rates%leaf_age_increment, &
         rates%youngest_specific_leaf_area, rates%lai_exponential_growth_rate, &
         rates%relative_transpiration_used]
    valid = all(ieee_is_finite(values))
    if (.not. valid) return
    valid = rates%temperature_sum_increment >= 0.0_real64 .and. &
         rates%development_rate >= 0.0_real64 .and. &
         rates%leaf_growth_rate >= 0.0_real64 .and. &
         rates%leaf_stress_death_rate >= 0.0_real64 .and. &
         rates%leaf_age_increment >= 0.0_real64 .and. &
         rates%youngest_specific_leaf_area >= 0.0_real64 .and. &
         rates%lai_exponential_growth_rate >= 0.0_real64 .and. &
         rates%relative_transpiration_used >= 0.0_real64 .and. &
         rates%relative_transpiration_used <= 1.0_real64
  end function valid_rate_packet

end module mod_wofost_finalize_rates
