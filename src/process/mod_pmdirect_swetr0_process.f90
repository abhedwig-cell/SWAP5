module mod_pmdirect_swetr0_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PMDIRECT_SWETR0_OK = 0
  integer, parameter, public :: PMDIRECT_SWETR0_INVALID_DAY = 1
  integer, parameter, public :: PMDIRECT_SWETR0_INVALID_WEATHER = 2
  integer, parameter, public :: PMDIRECT_SWETR0_INVALID_SITE = 3
  integer, parameter, public :: PMDIRECT_SWETR0_INVALID_CANOPY = 4
  integer, parameter, public :: PMDIRECT_SWETR0_INVALID_RESULT = 5

  real(real64), parameter :: PI = 3.141592653589793238462643383279502884197_real64
  real(real64), parameter :: RADIAL = PI / 180.0_real64
  real(real64), parameter :: SMALL = 1.0e-6_real64
  real(real64), parameter :: VLARGE = 1.0e12_real64
  real(real64), parameter :: CHGRASS_CM = 12.0_real64
  real(real64), parameter :: CHSOIL_CM = 0.1_real64
  real(real64), parameter :: ALBSOIL = 0.15_real64
  real(real64), parameter :: ALBPOND = 0.08_real64

  type, public :: pmdirect_swetr0_weather_t
    integer :: day_of_year = 0
    real(real64) :: radiation_j_m2_d = 0.0_real64
    real(real64) :: minimum_air_temperature_c = 0.0_real64
    real(real64) :: maximum_air_temperature_c = 0.0_real64
    real(real64) :: vapour_pressure_kpa = 0.0_real64
    real(real64) :: wind_speed_m_s = 0.0_real64
    real(real64) :: gross_rain_cm_d = 0.0_real64
  end type pmdirect_swetr0_weather_t

  type, public :: pmdirect_swetr0_site_t
    real(real64) :: latitude_degrees = 0.0_real64
    real(real64) :: altitude_m = 0.0_real64
    real(real64) :: wind_measurement_height_m = 0.0_real64
    real(real64) :: humidity_measurement_height_m = 0.0_real64
    real(real64) :: angstrom_a = 0.0_real64
    real(real64) :: angstrom_b = 0.0_real64
    real(real64) :: wind_function_factor = 1.0_real64
    real(real64) :: soil_surface_resistance_s_m = 0.0_real64
  end type pmdirect_swetr0_site_t

  type, public :: pmdirect_swetr0_canopy_t
    logical :: crop_emerged = .false.
    logical :: use_crop_height_for_aerodynamics = .false.
    real(real64) :: crop_height_cm = 0.0_real64
    real(real64) :: lai = 0.0_real64
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: cofab_cm = 0.0_real64
    real(real64) :: albedo = 0.0_real64
    real(real64) :: dry_canopy_resistance_s_m = 0.0_real64
    real(real64) :: wet_canopy_resistance_s_m = 0.0_real64
    real(real64) :: co2_transpiration_factor = 1.0_real64
  end type pmdirect_swetr0_canopy_t

  type, public :: pmdirect_swetr0_daily_result_t
    real(real64) :: potential_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_dry_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_wet_cm_per_day = 0.0_real64
    real(real64) :: interception_evaporation_capacity_cm_per_day = 0.0_real64
    real(real64) :: es0_mm_per_day = 0.0_real64
    real(real64) :: et0_mm_per_day = 0.0_real64
    real(real64) :: ew0_mm_per_day = 0.0_real64
    real(real64) :: ep0_mm_per_day = 0.0_real64
  end type pmdirect_swetr0_daily_result_t

  type, public :: pmdirect_swetr0_interval_result_t
    real(real64) :: net_rain_cm_per_day = 0.0_real64
    real(real64) :: wet_canopy_fraction = 0.0_real64
    real(real64) :: potential_transpiration_cm_per_day = 0.0_real64
    real(real64) :: interception_rate_cm_per_day = 0.0_real64
  end type pmdirect_swetr0_interval_result_t

  type, public :: pmdirect_swetr0_diagnostics_t
    integer :: status = PMDIRECT_SWETR0_OK
    logical :: daily_result_produced = .false.
    logical :: interval_result_produced = .false.
  end type pmdirect_swetr0_diagnostics_t

  public :: evaluate_pmdirect_swetr0_daily
  public :: apply_swinter1_daily_interval

contains

  pure subroutine evaluate_pmdirect_swetr0_daily(weather, site, canopy, result, diagnostics)
    type(pmdirect_swetr0_weather_t), intent(in) :: weather
    type(pmdirect_swetr0_site_t), intent(in) :: site
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
    type(pmdirect_swetr0_daily_result_t), intent(out) :: result
    type(pmdirect_swetr0_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: tav, tavk, tmnk, tmxk, palt, lambda, ea, ed, vpd, delta, gamma, rho, cp
    real(real64) :: zm, zh, chplant, ud, dgrass, zomgrass, fmeas, zact, dact, zomact, fact
    real(real64) :: rns, rnc, rnw, rnp, atmtr, relssd, rnl, gs, gc, gw
    real(real64) :: rac, raw, ras, rss, laieff, gammos, gammoc, gammow, gammop
    real(real64) :: con_tmp, etaers, etaerc, etaerw, etaerp, etrads, etradc, etradw, etradp
    real(real64) :: ptra_dry, ptra_wet, eintc

    result = pmdirect_swetr0_daily_result_t()
    diagnostics = pmdirect_swetr0_diagnostics_t()

    if (weather%day_of_year < 1 .or. weather%day_of_year > 366) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_DAY
      return
    end if
    if (.not. valid_weather(weather)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_WEATHER
      return
    end if
    if (.not. valid_site(site)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_SITE
      return
    end if
    if (.not. valid_canopy(canopy)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_CANOPY
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

    rss = site%soil_surface_resistance_s_m
    if (canopy%vegetation_cover_fraction > 1.0e-6_real64) then
      rac = rac / canopy%vegetation_cover_fraction
    else
      rac = 1.0e12_real64
    end if
    raw = rac

    if ((1.0_real64 - canopy%vegetation_cover_fraction) > 1.0e-6_real64) then
      ras = ras / (1.0_real64 - canopy%vegetation_cover_fraction)
    else
      ras = 1.0e12_real64
    end if

    laieff = canopy%lai / (0.3_real64 * canopy%lai + 1.2_real64)

    gammos = VLARGE
    if (ras > SMALL) gammos = gamma * (1.0_real64 + rss / ras)
    gammoc = VLARGE
    if ((rac * laieff) > SMALL) gammoc = gamma * (1.0_real64 + canopy%dry_canopy_resistance_s_m / (rac * laieff))
    gammow = VLARGE
    if ((raw * laieff) > SMALL) gammow = gamma * (1.0_real64 + canopy%wet_canopy_resistance_s_m / (raw * laieff))
    gammop = VLARGE
    if (ras > SMALL) gammop = gamma

    con_tmp = 86.4_real64 * rho * cp * vpd / lambda
    etaers = con_tmp / ((delta + gammos) * ras)
    etaerc = con_tmp / ((delta + gammoc) * rac)
    etaerw = con_tmp / ((delta + gammow) * raw)
    etaerp = con_tmp / ((delta + gammop) * ras)

    con_tmp = delta / lambda
    etrads = con_tmp * (rns - rnl - gs) * (1.0_real64 - canopy%vegetation_cover_fraction) / (delta + gammos)
    etradc = con_tmp * (rnc - rnl - gc) * canopy%vegetation_cover_fraction / (delta + gammoc)
    etradw = con_tmp * (rnw - rnl - gw) * canopy%vegetation_cover_fraction / (delta + gammow)
    etradp = con_tmp * (rnp - rnl - gs) * (1.0_real64 - canopy%vegetation_cover_fraction) / (delta + gammop)

    result%es0_mm_per_day = max(0.0_real64, etaers + etrads)
    result%et0_mm_per_day = max(0.0_real64, etaerc + etradc)
    result%ew0_mm_per_day = max(0.0_real64, etaerw + etradw)
    result%ep0_mm_per_day = max(0.0_real64, etaerp + etradp)

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

    if (.not. valid_daily_result(result)) then
      result = pmdirect_swetr0_daily_result_t()
      diagnostics%status = PMDIRECT_SWETR0_INVALID_RESULT
      return
    end if

    diagnostics%daily_result_produced = .true.
  end subroutine evaluate_pmdirect_swetr0_daily

  pure subroutine apply_swinter1_daily_interval(weather, canopy, daily_result, interval_result, diagnostics)
    type(pmdirect_swetr0_weather_t), intent(in) :: weather
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
    type(pmdirect_swetr0_daily_result_t), intent(in) :: daily_result
    type(pmdirect_swetr0_interval_result_t), intent(out) :: interval_result
    type(pmdirect_swetr0_diagnostics_t), intent(inout) :: diagnostics

    real(real64) :: aintc, rpd, wfrac

    interval_result = pmdirect_swetr0_interval_result_t()
    diagnostics%interval_result_produced = .false.
    if (diagnostics%status /= PMDIRECT_SWETR0_OK .or. .not. diagnostics%daily_result_produced) return
    if (.not. valid_weather(weather)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_WEATHER
      return
    end if
    if (.not. valid_canopy(canopy)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_CANOPY
      return
    end if
    if (.not. valid_daily_result(daily_result)) then
      diagnostics%status = PMDIRECT_SWETR0_INVALID_RESULT
      return
    end if

    aintc = 0.0_real64
    if (canopy%lai >= 1.0e-3_real64 .and. weather%gross_rain_cm_d >= 1.0e-5_real64) then
      rpd = 10.0_real64 * weather%gross_rain_cm_d
      if (rpd > 0.0_real64 .and. canopy%cofab_cm > 0.0_real64 .and. &
          canopy%vegetation_cover_fraction > 0.0_real64) then
        aintc = 0.1_real64 / (1.0_real64 / (canopy%cofab_cm * canopy%lai) + &
                             1.0_real64 / (rpd * canopy%vegetation_cover_fraction))
      end if
    end if

    interval_result%interception_rate_cm_per_day = aintc
    if (aintc < SMALL) then
      interval_result%net_rain_cm_per_day = weather%gross_rain_cm_d
    else if (weather%gross_rain_cm_d > SMALL) then
      interval_result%net_rain_cm_per_day = weather%gross_rain_cm_d - aintc
    else
      interval_result%net_rain_cm_per_day = 0.0_real64
    end if

    if (daily_result%interception_evaporation_capacity_cm_per_day < 0.001_real64) then
      wfrac = 0.0_real64
    else
      wfrac = max(min(aintc / daily_result%interception_evaporation_capacity_cm_per_day, 1.0_real64), 0.0_real64)
    end if
    interval_result%wet_canopy_fraction = wfrac
    interval_result%potential_transpiration_cm_per_day = &
      wfrac * daily_result%potential_transpiration_wet_cm_per_day + &
      (1.0_real64 - wfrac) * daily_result%potential_transpiration_dry_cm_per_day

    if (.not. valid_interval_result(interval_result)) then
      interval_result = pmdirect_swetr0_interval_result_t()
      diagnostics%status = PMDIRECT_SWETR0_INVALID_RESULT
      return
    end if
    diagnostics%interval_result_produced = .true.
  end subroutine apply_swinter1_daily_interval

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

  pure logical function valid_weather(weather) result(valid)
    type(pmdirect_swetr0_weather_t), intent(in) :: weather
    valid = ieee_is_finite(weather%radiation_j_m2_d) .and. &
            ieee_is_finite(weather%minimum_air_temperature_c) .and. &
            ieee_is_finite(weather%maximum_air_temperature_c) .and. &
            ieee_is_finite(weather%vapour_pressure_kpa) .and. &
            ieee_is_finite(weather%wind_speed_m_s) .and. &
            ieee_is_finite(weather%gross_rain_cm_d)
    if (.not. valid) return
    valid = weather%radiation_j_m2_d >= 0.0_real64 .and. &
            weather%maximum_air_temperature_c >= weather%minimum_air_temperature_c .and. &
            weather%vapour_pressure_kpa >= 0.0_real64 .and. &
            weather%wind_speed_m_s >= 0.0_real64 .and. weather%gross_rain_cm_d >= 0.0_real64
  end function valid_weather

  pure logical function valid_site(site) result(valid)
    type(pmdirect_swetr0_site_t), intent(in) :: site
    valid = ieee_is_finite(site%latitude_degrees) .and. ieee_is_finite(site%altitude_m) .and. &
            ieee_is_finite(site%wind_measurement_height_m) .and. &
            ieee_is_finite(site%humidity_measurement_height_m) .and. &
            ieee_is_finite(site%angstrom_a) .and. ieee_is_finite(site%angstrom_b) .and. &
            ieee_is_finite(site%wind_function_factor) .and. &
            ieee_is_finite(site%soil_surface_resistance_s_m)
    if (.not. valid) return
    valid = abs(site%latitude_degrees) <= 90.0_real64 .and. &
            site%wind_measurement_height_m > (2.0_real64 / 3.0_real64) * CHGRASS_CM / 100.0_real64 .and. &
            site%humidity_measurement_height_m > 0.0_real64 .and. site%angstrom_b > 0.0_real64 .and. &
            site%wind_function_factor > 0.0_real64 .and. site%soil_surface_resistance_s_m >= 0.0_real64
  end function valid_site

  pure logical function valid_canopy(canopy) result(valid)
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
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
  end function valid_canopy

  pure logical function valid_daily_result(result) result(valid)
    type(pmdirect_swetr0_daily_result_t), intent(in) :: result
    valid = ieee_is_finite(result%potential_soil_evaporation_cm_per_day) .and. &
            ieee_is_finite(result%potential_pond_evaporation_cm_per_day) .and. &
            ieee_is_finite(result%potential_transpiration_dry_cm_per_day) .and. &
            ieee_is_finite(result%potential_transpiration_wet_cm_per_day) .and. &
            ieee_is_finite(result%interception_evaporation_capacity_cm_per_day) .and. &
            ieee_is_finite(result%es0_mm_per_day) .and. ieee_is_finite(result%et0_mm_per_day) .and. &
            ieee_is_finite(result%ew0_mm_per_day) .and. ieee_is_finite(result%ep0_mm_per_day)
    if (.not. valid) return
    valid = result%potential_soil_evaporation_cm_per_day >= 0.0_real64 .and. &
            result%potential_pond_evaporation_cm_per_day >= 0.0_real64 .and. &
            result%potential_transpiration_dry_cm_per_day >= 0.0_real64 .and. &
            result%potential_transpiration_wet_cm_per_day >= 0.0_real64 .and. &
            result%interception_evaporation_capacity_cm_per_day >= 0.0_real64
  end function valid_daily_result

  pure logical function valid_interval_result(result) result(valid)
    type(pmdirect_swetr0_interval_result_t), intent(in) :: result
    valid = ieee_is_finite(result%net_rain_cm_per_day) .and. &
            ieee_is_finite(result%wet_canopy_fraction) .and. &
            ieee_is_finite(result%potential_transpiration_cm_per_day) .and. &
            ieee_is_finite(result%interception_rate_cm_per_day)
    if (.not. valid) return
    valid = result%net_rain_cm_per_day >= 0.0_real64 .and. &
            result%wet_canopy_fraction >= 0.0_real64 .and. result%wet_canopy_fraction <= 1.0_real64 .and. &
            result%potential_transpiration_cm_per_day >= 0.0_real64 .and. &
            result%interception_rate_cm_per_day >= 0.0_real64
  end function valid_interval_result

end module mod_pmdirect_swetr0_process
