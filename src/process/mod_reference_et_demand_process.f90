module mod_reference_et_demand_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: REF_ET_DEMAND_OK = 0
  integer, parameter, public :: REF_ET_DEMAND_INVALID_REFERENCE_ET = 1
  integer, parameter, public :: REF_ET_DEMAND_INVALID_COVER = 2
  integer, parameter, public :: REF_ET_DEMAND_INVALID_POND_FACTOR = 3
  integer, parameter, public :: REF_ET_DEMAND_INVALID_CROP_FACTOR = 4
  integer, parameter, public :: REF_ET_DEMAND_INVALID_CO2_FACTOR = 5
  integer, parameter, public :: REF_ET_DEMAND_INVALID_RESULT = 6

  type, public :: reference_et_demand_parameters_t
    real(real64) :: pond_evaporation_factor = 1.0_real64
  end type reference_et_demand_parameters_t

  type, public :: reference_et_demand_forcing_t
    real(real64) :: reference_et_mm_per_day = 0.0_real64
  end type reference_et_demand_forcing_t

  type, public :: reference_et_demand_canopy_view_t
    logical :: crop_emerged = .false.
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: crop_factor = 0.0_real64
    real(real64) :: co2_transpiration_factor = 1.0_real64
  end type reference_et_demand_canopy_view_t

  type, public :: reference_et_demand_result_t
    real(real64) :: potential_transpiration_cm_per_day = 0.0_real64
    real(real64) :: potential_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
  end type reference_et_demand_result_t

  type, public :: reference_et_demand_diagnostics_t
    integer :: status = REF_ET_DEMAND_OK
    logical :: forcing_consumed = .false.
    logical :: canopy_cover_consumed = .false.
    logical :: crop_specific_factors_consumed = .false.
    logical :: result_produced = .false.
  end type reference_et_demand_diagnostics_t

  public :: evaluate_restricted_reference_et_demand, evaluate_reference_et_rutter_demand

  integer, parameter :: PM_IDENTITY_KIND=selected_int_kind(18)
  real(real64), parameter :: PI = 3.141592653589793238462643383279502884197_real64
  real(real64), parameter :: RADIAL = PI / 180.0_real64
  real(real64), parameter :: SMALL = 1.0e-6_real64
  real(real64), parameter :: VLARGE = 1.0e12_real64
  real(real64), parameter :: CHGRASS_CM = 12.0_real64
  real(real64), parameter :: CHSOIL_CM = 0.1_real64
  real(real64), parameter :: ALBSOIL = 0.15_real64
  real(real64), parameter :: ALBPOND = 0.08_real64

  type, public :: traditional_pm_weather_t
    integer :: day_of_year = 0
    real(real64) :: radiation_j_m2_d = 0.0_real64
    real(real64) :: minimum_air_temperature_c = 0.0_real64
    real(real64) :: maximum_air_temperature_c = 0.0_real64
    real(real64) :: vapour_pressure_kpa = 0.0_real64
    real(real64) :: wind_speed_m_s = 0.0_real64
    real(real64) :: gross_rain_cm_d = 0.0_real64
  end type traditional_pm_weather_t

  type, public :: traditional_pm_site_t
    real(real64) :: latitude_degrees = 0.0_real64
    real(real64) :: altitude_m = 0.0_real64
    real(real64) :: wind_measurement_height_m = 0.0_real64
    real(real64) :: humidity_measurement_height_m = 0.0_real64
    real(real64) :: angstrom_a = 0.0_real64
    real(real64) :: angstrom_b = 0.0_real64
    real(real64) :: wind_function_factor = 1.0_real64
    real(real64) :: soil_surface_resistance_s_m = 0.0_real64
  end type traditional_pm_site_t

  type, public :: traditional_pm_canopy_t
    logical :: crop_emerged = .false.
    real(real64) :: lai = 0.0_real64
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: cofab_cm = 0.0_real64
    real(real64) :: albedo = 0.0_real64
    real(real64) :: dry_canopy_resistance_s_m = 0.0_real64
    real(real64) :: wet_canopy_resistance_s_m = 0.0_real64
    real(real64) :: co2_transpiration_factor = 1.0_real64
    logical :: use_crop_height_for_aerodynamics = .false.
    real(real64) :: crop_height_cm = 0.0_real64
  end type traditional_pm_canopy_t

  type, public :: traditional_pm_daily_result_t
    real(real64) :: potential_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_dry_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_wet_cm_per_day = 0.0_real64
    real(real64) :: interception_evaporation_capacity_cm_per_day = 0.0_real64
    real(real64) :: es0_mm_per_day = 0.0_real64
    real(real64) :: et0_mm_per_day = 0.0_real64
    real(real64) :: ew0_mm_per_day = 0.0_real64
    real(real64) :: ep0_mm_per_day = 0.0_real64
  end type traditional_pm_daily_result_t

  type, public :: daily_atmospheric_demand_parameters_t
    integer :: mode=1
    logical :: soil_factor_enabled=.false.
    real(real64) :: soil_factor=1.0_real64, crop_factor=1.0_real64, pond_factor=1.0_real64
    type(traditional_pm_site_t) :: site
    type(traditional_pm_canopy_t) :: canopy
  contains
    procedure :: ready => daily_demand_parameters_ready
    procedure :: same_input => daily_demand_parameters_same
  end type
  public :: evaluate_daily_atmospheric_demand, evaluate_traditional_pm_daily

contains

  subroutine evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    type(reference_et_demand_parameters_t), intent(in) :: parameters
    type(reference_et_demand_forcing_t), intent(in) :: forcing
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(reference_et_demand_result_t), intent(out) :: result
    type(reference_et_demand_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: uncovered_reference_et_mm_per_day
    real(real64) :: transpiration_reference_et_mm_per_day

    result = reference_et_demand_result_t()
    diagnostics = reference_et_demand_diagnostics_t()

    diagnostics%forcing_consumed = .true.
    diagnostics%canopy_cover_consumed = .true.

    if (.not. ieee_is_finite(forcing%reference_et_mm_per_day)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_REFERENCE_ET
      return
    end if
    if (forcing%reference_et_mm_per_day < 0.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_REFERENCE_ET
      return
    end if

    if (.not. ieee_is_finite(canopy%vegetation_cover_fraction)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_COVER
      return
    end if
    if (canopy%vegetation_cover_fraction < 0.0_real64 .or. canopy%vegetation_cover_fraction > 1.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_COVER
      return
    end if

    if (.not. ieee_is_finite(parameters%pond_evaporation_factor)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_POND_FACTOR
      return
    end if
    if (parameters%pond_evaporation_factor < 0.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_POND_FACTOR
      return
    end if

    ! Crop-specific inputs are intentionally not consumed for a non-emerged
    ! crop. Surface demands still consume the current vegetation-cover view,
    ! matching B1.10 ETpot.
    if (canopy%crop_emerged) then
      diagnostics%crop_specific_factors_consumed = .true.

      if (.not. ieee_is_finite(canopy%crop_factor)) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CROP_FACTOR
        return
      end if
      if (canopy%crop_factor < 0.0_real64) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CROP_FACTOR
        return
      end if

      if (.not. ieee_is_finite(canopy%co2_transpiration_factor)) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CO2_FACTOR
        return
      end if
      if (canopy%co2_transpiration_factor < 0.0_real64) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CO2_FACTOR
        return
      end if
    end if

    ! B1.10 MOD_meteo ETpot, restricted route:
    ! SWETR=1, SWMETDETAIL=0, SWCFBS=0, SWINTER=0.
    ! etr, es0, ep0 and et0 are in mm/day; public demands are cm/day.
    uncovered_reference_et_mm_per_day = forcing%reference_et_mm_per_day * &
                                         (1.0_real64 - canopy%vegetation_cover_fraction)
    result%potential_soil_evaporation_cm_per_day = max(uncovered_reference_et_mm_per_day * 0.1_real64, 0.0_real64)
    result%potential_pond_evaporation_cm_per_day = max(uncovered_reference_et_mm_per_day * &
                                                       parameters%pond_evaporation_factor * 0.1_real64, 0.0_real64)

    if (canopy%crop_emerged) then
      transpiration_reference_et_mm_per_day = forcing%reference_et_mm_per_day * &
                                               canopy%vegetation_cover_fraction * canopy%crop_factor
      result%potential_transpiration_cm_per_day = max(transpiration_reference_et_mm_per_day * 0.1_real64, &
                                                      0.0_real64) * canopy%co2_transpiration_factor
    end if

    if (.not. result_is_valid(result)) then
      result = reference_et_demand_result_t()
      diagnostics%status = REF_ET_DEMAND_INVALID_RESULT
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine evaluate_restricted_reference_et_demand

  ! Original MOD_meteo:ETpot wet-canopy partition for the daily ETref route.
  ! Reuse the validated dry/surface owner; EW0 precedes the CO2 correction.
  subroutine evaluate_reference_et_rutter_demand(parameters,forcing,canopy,result,diagnostics)
    type(reference_et_demand_parameters_t),intent(in)::parameters
    type(reference_et_demand_forcing_t),intent(in)::forcing
    type(reference_et_demand_canopy_view_t),intent(in)::canopy
    type(traditional_pm_daily_result_t),intent(out)::result
    type(reference_et_demand_diagnostics_t),intent(out)::diagnostics
    type(reference_et_demand_result_t)::dry
    real(real64)::wet_evaporation
    result=traditional_pm_daily_result_t()
    call evaluate_restricted_reference_et_demand(parameters,forcing,canopy,dry,diagnostics)
    if(.not.diagnostics%result_produced)return
    result%potential_soil_evaporation_cm_per_day=dry%potential_soil_evaporation_cm_per_day
    result%potential_pond_evaporation_cm_per_day=dry%potential_pond_evaporation_cm_per_day
    result%potential_transpiration_dry_cm_per_day=dry%potential_transpiration_cm_per_day
    if(canopy%crop_emerged)then
      result%et0_mm_per_day=forcing%reference_et_mm_per_day*canopy%vegetation_cover_fraction*canopy%crop_factor
      result%ew0_mm_per_day=result%et0_mm_per_day
    end if
    result%es0_mm_per_day=forcing%reference_et_mm_per_day*(1.0_real64-canopy%vegetation_cover_fraction)
    result%ep0_mm_per_day=result%es0_mm_per_day*parameters%pond_evaporation_factor
    wet_evaporation=result%ew0_mm_per_day*0.1_real64
    if(wet_evaporation>0.0_real64)then
      result%potential_transpiration_wet_cm_per_day= &
        (dry%potential_transpiration_cm_per_day/(dry%potential_transpiration_cm_per_day+wet_evaporation))* &
          dry%potential_transpiration_cm_per_day
      result%interception_evaporation_capacity_cm_per_day= &
        (wet_evaporation/(dry%potential_transpiration_cm_per_day+wet_evaporation))*result%ew0_mm_per_day*0.1_real64
    end if
    if(.not.all(ieee_is_finite([result%potential_transpiration_wet_cm_per_day, &
       result%interception_evaporation_capacity_cm_per_day])))then
      result=traditional_pm_daily_result_t()
      diagnostics%status=REF_ET_DEMAND_INVALID_RESULT;diagnostics%result_produced=.false.
    end if
  end subroutine evaluate_reference_et_rutter_demand

  pure logical function result_is_valid(result) result(valid)
    type(reference_et_demand_result_t), intent(in) :: result

    valid = ieee_is_finite(result%potential_transpiration_cm_per_day) .and. &
            ieee_is_finite(result%potential_soil_evaporation_cm_per_day) .and. &
            ieee_is_finite(result%potential_pond_evaporation_cm_per_day)
    if (.not. valid) return

    valid = result%potential_transpiration_cm_per_day >= 0.0_real64 .and. &
            result%potential_soil_evaporation_cm_per_day >= 0.0_real64 .and. &
            result%potential_pond_evaporation_cm_per_day >= 0.0_real64
  end function result_is_valid

  pure subroutine evaluate_traditional_pm_daily(weather, parameters, result, diagnostics)
    type(traditional_pm_weather_t), intent(in) :: weather
    type(daily_atmospheric_demand_parameters_t), intent(in) :: parameters
    type(traditional_pm_site_t) :: site
    type(traditional_pm_canopy_t) :: canopy
    type(traditional_pm_daily_result_t), intent(out) :: result
    type(reference_et_demand_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: tav, tavk, tmnk, tmxk, palt, lambda, ea, ed, vpd, delta, gamma, rho, cp
    real(real64) :: zm, zh, chplant, ud, dgrass, zomgrass, fmeas, zact, dact, zomact, fact
    real(real64) :: rns, rnc, rnw, rnp, atmtr, relssd, rnl, gs, gc, gw
    real(real64) :: rac, raw, ras, rss, gammos, gammoc, gammow
    real(real64) :: con_tmp, etaers, etaerc, etaerw, etrads, etradc, etradw
    real(real64) :: ptra_dry, ptra_wet, eintc

    site=parameters%site;canopy=parameters%canopy
    result = traditional_pm_daily_result_t()
    diagnostics = reference_et_demand_diagnostics_t()

    if(.not.parameters%ready().or.parameters%mode/=0) then
      diagnostics%status=3
      return
    end if
    if (weather%day_of_year < 1 .or. weather%day_of_year > 366) then
      diagnostics%status = 1
      return
    end if
    if (.not. pm_valid_weather(weather)) then
      diagnostics%status = 2
      return
    end if
    if (.not. pm_valid_site(site)) then
      diagnostics%status = 3
      return
    end if
    if (.not. pm_valid_canopy(canopy)) then
      diagnostics%status = 4
      return
    end if

    tav = 0.5_real64 * (weather%minimum_air_temperature_c + weather%maximum_air_temperature_c)
    tavk = tav + 273.15_real64
    tmnk = weather%minimum_air_temperature_c + 273.15_real64
    tmxk = weather%maximum_air_temperature_c + 273.15_real64

    zm = 100.0_real64 * site%wind_measurement_height_m
    zh = 100.0_real64 * site%humidity_measurement_height_m
    chplant = CHGRASS_CM
    if (canopy%crop_emerged .and. canopy%use_crop_height_for_aerodynamics) then
      chplant = max(canopy%crop_height_cm, CHSOIL_CM)
    end if

    palt = 101.3_real64 * ((tavk - 0.0065_real64 * site%altitude_m) / tavk)**5.26_real64
    lambda = 2.501_real64 - 0.002361_real64 * tav
    ea = 0.30539_real64 * ( &
         exp(17.27_real64 * weather%minimum_air_temperature_c / &
             (weather%minimum_air_temperature_c + 237.3_real64)) + &
         exp(17.27_real64 * weather%maximum_air_temperature_c / &
             (weather%maximum_air_temperature_c + 237.3_real64)))
    ed = min(weather%vapour_pressure_kpa, ea)
    vpd = ea - ed
    delta = 4098.0_real64 * ea / (tav + 237.3_real64)**2
    gamma = (1.013e-3_real64 * palt) / (0.622_real64 * lambda)
    rho = 3.486_real64 * palt / (tavk / (1.0_real64 - 0.378_real64 * ed / palt))
    cp = 622.0_real64 * gamma * lambda / palt

    ud = max(weather%wind_speed_m_s * site%wind_function_factor, 0.0001_real64)
    dgrass = (2.0_real64 / 3.0_real64) * CHGRASS_CM
    zomgrass = 0.123_real64 * CHGRASS_CM
    fmeas = log((1.0e4_real64 - dgrass) / zomgrass) / log((zm - dgrass) / zomgrass)
    zact = max(chplant, 200.0_real64)
    dact = (2.0_real64 / 3.0_real64) * chplant
    zomact = 0.123_real64 * chplant
    fact = log((zact - dact) / zomact) / log((1.0e4_real64 - dact) / zomact)
    ud = ud * fact * fmeas

    rns = (1.0_real64 - ALBSOIL) * weather%radiation_j_m2_d / 1.0e6_real64
    rnc = (1.0_real64 - canopy%albedo) * weather%radiation_j_m2_d / 1.0e6_real64
    rnw = rnc
    rnp = (1.0_real64 - ALBPOND) * weather%radiation_j_m2_d / 1.0e6_real64

    atmtr = daily_atmospheric_transmission(weather%day_of_year, site%latitude_degrees, &
                                            weather%radiation_j_m2_d)
    relssd = max(min((atmtr - site%angstrom_a) / site%angstrom_b, 1.0_real64), 0.0_real64)
    rnl = 2.45015e-9_real64 * (tmxk**4 + tmnk**4) * &
          (0.34_real64 - 0.14_real64 * sqrt(ed)) * (0.1_real64 + 0.9_real64 * relssd)

    gs = 0.0_real64
    gc = 0.0_real64
    gw = 0.0_real64

    rac = aerodynamic_resistance(chplant, ud, zact, zh)
    raw = rac
    ras = aerodynamic_resistance(CHSOIL_CM, ud, zact, zh)

    ! Literal B1.11 SWDIVIDE=0: no cover-scaled resistances/effective LAI.
    rss=0.0_real64
    gammos=gamma*(1.0_real64+rss/ras)
    gammoc=gamma*(1.0_real64+canopy%dry_canopy_resistance_s_m/rac)
    gammow=gamma*(1.0_real64+canopy%wet_canopy_resistance_s_m/raw)
    con_tmp=(86.4_real64*rho*cp*vpd)/lambda
    etaers=con_tmp/((delta+gammos)*ras)
    etaerc=con_tmp/((delta+gammoc)*rac)
    etaerw=con_tmp/((delta+gammow)*raw)
    con_tmp=delta/ lambda
    etrads=con_tmp*(rns-rnl-gs)/(delta+gammos)
    etradc=con_tmp*(rnc-rnl-gc)/(delta+gammoc)
    etradw=con_tmp*(rnw-rnl-gw)/(delta+gammow)
    if(.not.canopy%use_crop_height_for_aerodynamics.and.parameters%soil_factor_enabled) then
      result%es0_mm_per_day=max(0.0_real64,(etaerc+etradc)*(1.0_real64-canopy%vegetation_cover_fraction))
    else
      result%es0_mm_per_day=max(0.0_real64,(etaers+etrads)*(1.0_real64-canopy%vegetation_cover_fraction))
    end if
    result%et0_mm_per_day=max(0.0_real64,(etaerc+etradc)*canopy%vegetation_cover_fraction)
    result%ew0_mm_per_day=max(0.0_real64,(etaerw+etradw)*canopy%vegetation_cover_fraction)
    result%ep0_mm_per_day=max(0.0_real64,(etaerw+etradw)*(1.0_real64-canopy%vegetation_cover_fraction))
    if(parameters%soil_factor_enabled) result%es0_mm_per_day=result%es0_mm_per_day*parameters%soil_factor
    if(canopy%crop_emerged) then
      if(.not.canopy%use_crop_height_for_aerodynamics) then
        result%et0_mm_per_day=result%et0_mm_per_day*parameters%crop_factor
        result%ew0_mm_per_day=result%ew0_mm_per_day*parameters%crop_factor
        result%ep0_mm_per_day=result%ep0_mm_per_day*parameters%pond_factor
      end if
    else
      result%et0_mm_per_day=0.0_real64;result%ew0_mm_per_day=0.0_real64
    end if

    result%potential_pond_evaporation_cm_per_day = max(0.0_real64, 0.1_real64 * result%ep0_mm_per_day)
    result%potential_soil_evaporation_cm_per_day = max(0.0_real64, 0.1_real64 * result%es0_mm_per_day)
    ptra_dry = max(0.1_real64 * result%et0_mm_per_day, 0.0_real64)
    if (canopy%crop_emerged) ptra_dry = canopy%co2_transpiration_factor * ptra_dry
    result%potential_transpiration_dry_cm_per_day = ptra_dry

    if (result%ew0_mm_per_day > 0.0_real64) then
      ptra_wet = (ptra_dry / (ptra_dry + 0.1_real64 * result%ew0_mm_per_day)) * ptra_dry
      eintc = (0.1_real64 * result%ew0_mm_per_day / &
               (ptra_dry + 0.1_real64 * result%ew0_mm_per_day)) * &
              0.1_real64 * result%ew0_mm_per_day
    else
      ptra_wet = 0.0_real64
      eintc = 0.0_real64
    end if
    result%potential_transpiration_wet_cm_per_day = ptra_wet
    result%interception_evaporation_capacity_cm_per_day = eintc

    if (.not. pm_valid_result(result)) then
      result = traditional_pm_daily_result_t()
      diagnostics%status = 5
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine evaluate_traditional_pm_daily
  pure real(real64) function aerodynamic_resistance(ch, ud, zm, zh) result(raero)
    real(real64), intent(in) :: ch, ud, zm, zh
    real(real64) :: d, zom, zoh
    real(real64), parameter :: CKARMAN = 0.41_real64
    real(real64), parameter :: CHECK_E = exp(1.0_real64)

    d = (2.0_real64 / 3.0_real64) * ch
    zom = 0.123_real64 * ch
    zoh = 0.1_real64 * zom
    raero = log((zm - d) / zom) * log(max(CHECK_E, (zh - d) / zoh)) / (CKARMAN**2 * ud)
  end function aerodynamic_resistance

  pure real(real64) function daily_atmospheric_transmission(day_of_year, latitude_degrees, radiation_j_m2_d) result(atmtr)
    integer, intent(in) :: day_of_year
    real(real64), intent(in) :: latitude_degrees, radiation_j_m2_d
    real(real64) :: dec, sc, sinld, cosld, aob, dayl, dsinb, angot

    dec = -asin(sin(23.45_real64 * RADIAL) * cos(2.0_real64 * PI * real(day_of_year + 10, real64) / 365.0_real64))
    sc = 1370.0_real64 * (1.0_real64 + 0.033_real64 * cos(2.0_real64 * PI * real(day_of_year, real64) / 365.0_real64))
    sinld = sin(RADIAL * latitude_degrees) * sin(dec)
    cosld = cos(RADIAL * latitude_degrees) * cos(dec)
    aob = sinld / cosld

    if (abs(aob) <= 1.0_real64) then
      dayl = 12.0_real64 * (1.0_real64 + 2.0_real64 * asin(aob) / PI)
      dsinb = 3600.0_real64 * (dayl * sinld + 24.0_real64 * cosld * sqrt(1.0_real64 - aob**2) / PI)
    else
      if (aob > 1.0_real64) dayl = 24.0_real64
      if (aob < -1.0_real64) dayl = 0.0_real64
      dsinb = 3600.0_real64 * dayl * sinld
    end if
    angot = sc * dsinb
    if (dayl > 0.0_real64) then
      atmtr = radiation_j_m2_d / angot
    else
      atmtr = 0.0_real64
    end if
  end function daily_atmospheric_transmission

  pure logical function pm_valid_weather(weather) result(valid)
    type(traditional_pm_weather_t), intent(in) :: weather
    valid = ieee_is_finite(weather%radiation_j_m2_d) .and. &
            ieee_is_finite(weather%minimum_air_temperature_c) .and. &
            ieee_is_finite(weather%maximum_air_temperature_c) .and. &
            ieee_is_finite(weather%vapour_pressure_kpa) .and. &
            ieee_is_finite(weather%wind_speed_m_s) .and. &
            ieee_is_finite(weather%gross_rain_cm_d)
    if (.not. valid) return
    valid=weather%minimum_air_temperature_c>=-80.0_real64.and.weather%maximum_air_temperature_c<=65.0_real64.and. &
      weather%radiation_j_m2_d<=1.0e8_real64.and.weather%vapour_pressure_kpa<=20.0_real64.and. &
      weather%wind_speed_m_s<=100.0_real64.and.weather%gross_rain_cm_d<=1000.0_real64
    if(.not.valid) return
    valid = weather%radiation_j_m2_d >= 0.0_real64 .and. &
            weather%maximum_air_temperature_c >= weather%minimum_air_temperature_c .and. &
            weather%vapour_pressure_kpa >= 0.0_real64 .and. &
            weather%wind_speed_m_s >= 0.0_real64 .and. weather%gross_rain_cm_d >= 0.0_real64
  end function pm_valid_weather

  pure logical function pm_valid_site(site) result(valid)
    type(traditional_pm_site_t), intent(in) :: site
    valid = ieee_is_finite(site%latitude_degrees) .and. ieee_is_finite(site%altitude_m) .and. &
            ieee_is_finite(site%wind_measurement_height_m) .and. &
            ieee_is_finite(site%humidity_measurement_height_m) .and. &
            ieee_is_finite(site%angstrom_a) .and. ieee_is_finite(site%angstrom_b) .and. &
            ieee_is_finite(site%wind_function_factor) .and. &
            ieee_is_finite(site%soil_surface_resistance_s_m)
    if (.not. valid) return
    valid = abs(site%latitude_degrees) <= 66.5_real64 .and. &
            site%wind_measurement_height_m > (2.0_real64 / 3.0_real64) * CHGRASS_CM / 100.0_real64 .and. &
            site%humidity_measurement_height_m > 0.0_real64 .and. site%angstrom_b > 0.0_real64 .and. &
            site%wind_function_factor > 0.0_real64 .and. site%soil_surface_resistance_s_m >= 0.0_real64
  end function pm_valid_site

  pure logical function pm_valid_canopy(canopy) result(valid)
    type(traditional_pm_canopy_t), intent(in) :: canopy
    valid = ieee_is_finite(canopy%crop_height_cm) .and. ieee_is_finite(canopy%lai) .and. &
            ieee_is_finite(canopy%vegetation_cover_fraction) .and. &
            ieee_is_finite(canopy%cofab_cm) .and. ieee_is_finite(canopy%albedo) .and. &
            ieee_is_finite(canopy%dry_canopy_resistance_s_m) .and. &
            ieee_is_finite(canopy%wet_canopy_resistance_s_m) .and. &
            ieee_is_finite(canopy%co2_transpiration_factor)
    if (.not. valid) return
    valid = canopy%crop_height_cm >= 0.0_real64 .and. canopy%lai >= 0.0_real64 .and. &
            canopy%vegetation_cover_fraction >= 0.0_real64 .and. &
            canopy%vegetation_cover_fraction <= 1.0_real64 .and. canopy%cofab_cm >= 0.0_real64 .and. &
            canopy%albedo >= 0.0_real64 .and. canopy%albedo <= 1.0_real64 .and. &
            canopy%dry_canopy_resistance_s_m >= 0.0_real64 .and. &
            canopy%wet_canopy_resistance_s_m >= 0.0_real64 .and. canopy%co2_transpiration_factor >= 0.0_real64
  end function pm_valid_canopy


  pure logical function daily_demand_parameters_ready(self) result(ok)
    class(daily_atmospheric_demand_parameters_t),intent(in)::self
    ok=.false.
    if(self%mode/=0.and.self%mode/=1) return
    if(.not.all(ieee_is_finite(daily_demand_parameter_values(self)))) return
    if(.not.all(ieee_is_finite([self%soil_factor,self%crop_factor,self%pond_factor]))) return
    if(min(self%soil_factor,self%crop_factor,self%pond_factor)<0.0_real64.or. &
       max(self%soil_factor,self%crop_factor,self%pond_factor)>10.0_real64) return
    if(self%mode==0) then
      if(.not.pm_valid_site(self%site).or..not.pm_valid_canopy(self%canopy)) return
      if(self%site%altitude_m < -400.0_real64.or.self%site%altitude_m>3000.0_real64) return
      if(min(self%site%wind_measurement_height_m,self%site%humidity_measurement_height_m)<0.1_real64.or. &
         max(self%site%wind_measurement_height_m,self%site%humidity_measurement_height_m)>99.0_real64) return
      if(self%site%angstrom_a<0.0_real64.or.self%site%angstrom_a>1.0_real64.or.self%site%angstrom_b>1.0_real64) return
      if(self%site%wind_function_factor>10.0_real64) return
      if(self%canopy%crop_height_cm>1000.0_real64.or.self%canopy%lai>100.0_real64) return
      if(max(self%canopy%dry_canopy_resistance_s_m,self%canopy%wet_canopy_resistance_s_m)>1.0e6_real64) return
      if(self%canopy%co2_transpiration_factor>10.0_real64) return
      if(self%canopy%crop_emerged.and.self%canopy%use_crop_height_for_aerodynamics) then
        if(100.0_real64*self%site%humidity_measurement_height_m<= &
          (2.0_real64/3.0_real64+0.0123_real64)*max(self%canopy%crop_height_cm,CHSOIL_CM)) return
      end if
    end if
    ok=.true.
  end function
  pure function daily_demand_parameter_values(p) result(v)
    class(daily_atmospheric_demand_parameters_t),intent(in)::p
    real(real64)::v(20)
    v=[p%soil_factor,p%crop_factor,p%pond_factor, &
      p%site%latitude_degrees,p%site%altitude_m,p%site%wind_measurement_height_m,p%site%humidity_measurement_height_m, &
      p%site%angstrom_a,p%site%angstrom_b,p%site%wind_function_factor,p%site%soil_surface_resistance_s_m, &
      p%canopy%crop_height_cm,p%canopy%lai,p%canopy%vegetation_cover_fraction,p%canopy%cofab_cm,p%canopy%albedo, &
      p%canopy%dry_canopy_resistance_s_m,p%canopy%wet_canopy_resistance_s_m,p%canopy%co2_transpiration_factor,real(p%mode,real64)]
  end function
  pure logical function daily_demand_parameters_same(self,other) result(ok)
    class(daily_atmospheric_demand_parameters_t),intent(in)::self
    type(daily_atmospheric_demand_parameters_t),intent(in)::other
    type(daily_atmospheric_demand_parameters_t)::p
    p=self
    ok=self%ready().and.other%ready()
    if(.not.ok) return
    ok=all(transfer(daily_demand_parameter_values(p),[int(0,kind=PM_IDENTITY_KIND)])== &
      transfer(daily_demand_parameter_values(other),[int(0,kind=PM_IDENTITY_KIND)])).and. &
      (self%soil_factor_enabled.eqv.other%soil_factor_enabled).and. &
      (self%canopy%crop_emerged.eqv.other%canopy%crop_emerged).and. &
      (self%canopy%use_crop_height_for_aerodynamics.eqv.other%canopy%use_crop_height_for_aerodynamics)
  end function
  subroutine evaluate_daily_atmospheric_demand(parameters,weather,reference_mm,canopy,result,status)
    type(daily_atmospheric_demand_parameters_t),intent(in)::parameters
    type(traditional_pm_weather_t),intent(in)::weather
    real(real64),intent(in)::reference_mm
    type(reference_et_demand_canopy_view_t),intent(in)::canopy
    type(reference_et_demand_result_t),intent(out)::result
    integer,intent(out)::status
    type(reference_et_demand_parameters_t)::rp
    type(reference_et_demand_forcing_t)::rf
    type(reference_et_demand_diagnostics_t)::d
    type(traditional_pm_daily_result_t)::pm
    result=reference_et_demand_result_t();status=REF_ET_DEMAND_INVALID_RESULT
    if(.not.parameters%ready()) return
    if(parameters%mode==1) then
      if(.not.ieee_is_finite(reference_mm)) return
      if(reference_mm<0.0_real64.or.reference_mm>1000.0_real64) return
      if(.not.all(ieee_is_finite([canopy%crop_factor,canopy%co2_transpiration_factor]))) return
      if(canopy%crop_emerged) then
        if(min(canopy%crop_factor,canopy%co2_transpiration_factor)<0.0_real64.or. &
          max(canopy%crop_factor,canopy%co2_transpiration_factor)>10.0_real64) return
      end if
      rp%pond_evaporation_factor=parameters%pond_factor;rf%reference_et_mm_per_day=reference_mm
      call evaluate_restricted_reference_et_demand(rp,rf,canopy,result,d)
      if(d%status/=REF_ET_DEMAND_OK.or..not.d%result_produced) return
      if(parameters%soil_factor_enabled) result%potential_soil_evaporation_cm_per_day= &
        result%potential_soil_evaporation_cm_per_day*parameters%soil_factor
    else
      call evaluate_traditional_pm_daily(weather,parameters,pm,d)
      if(d%status/=0.or..not.d%result_produced) return
      result%potential_soil_evaporation_cm_per_day=pm%potential_soil_evaporation_cm_per_day
      result%potential_pond_evaporation_cm_per_day=pm%potential_pond_evaporation_cm_per_day
      result%potential_transpiration_cm_per_day=pm%potential_transpiration_dry_cm_per_day
    end if
    if(.not.result_is_valid(result)) then
      result=reference_et_demand_result_t();return
    end if
    status=REF_ET_DEMAND_OK
  end subroutine
  pure logical function pm_valid_result(r) result(ok)
    type(traditional_pm_daily_result_t),intent(in)::r
    ok=all(ieee_is_finite([r%es0_mm_per_day,r%et0_mm_per_day,r%ew0_mm_per_day,r%ep0_mm_per_day, &
      r%potential_soil_evaporation_cm_per_day,r%potential_pond_evaporation_cm_per_day, &
      r%potential_transpiration_dry_cm_per_day,r%potential_transpiration_wet_cm_per_day, &
      r%interception_evaporation_capacity_cm_per_day]))
  end function

end module mod_reference_et_demand_process
