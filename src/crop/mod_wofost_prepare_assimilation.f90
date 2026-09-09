module mod_wofost_prepare_assimilation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, &
       wofost_rate_scalar_parameters_t, WOFOST_RATE_PARAMETER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_OK = 0
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_INVALID_STATE_VIEW = 1
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_INVALID_PARAMETERS = 2
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING = 3
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR = 4
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_INVALID_SOLAR_GEOMETRY = 5
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_ZERO_EFFICIENCY_DIRECT_BEAM = 6
  integer, parameter, public :: WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT = 7

  real(real64), parameter :: PI_REFERENCE = &
       3.141592653589793238462643383279502884197_real64
  real(real64), parameter :: XGAUSS(3) = &
       [0.1127017_real64, 0.5000000_real64, 0.8872983_real64]
  real(real64), parameter :: WGAUSS(3) = &
       [0.2777778_real64, 0.4444444_real64, 0.2777778_real64]

  type, public :: wofost_prepare_assimilation_forcing_t
    real(real64) :: daytime_mean_temperature = 0.0_real64 ! TAVD
    real(real64) :: global_radiation = 0.0_real64         ! RAD, J m-2 d-1
    real(real64) :: daylength_hours = 0.0_real64          ! DAYL
    real(real64) :: sine_solar_height_offset = 0.0_real64 ! SINLD
    real(real64) :: sine_solar_height_amplitude = 0.0_real64 ! COSLD
    real(real64) :: diffuse_irradiation_perpendicular = 0.0_real64 ! DIFPP
    real(real64) :: daily_effective_solar_height = 0.0_real64 ! DSINBE, s
    real(real64) :: co2_efficiency_factor = 1.0_real64    ! FCO2EFF
    real(real64) :: co2_amax_factor = 1.0_real64          ! FCO2AMAX
    real(real64) :: running_minimum_temperature = 0.0_real64 ! TMNR
  end type wofost_prepare_assimilation_forcing_t

  type, public :: wofost_prepare_assimilation_result_t
    real(real64) :: actual_pgass = 0.0_real64
  end type wofost_prepare_assimilation_result_t

  public :: prepare_wofost_actual_assimilation

contains

  subroutine prepare_wofost_actual_assimilation(state_view, parameters, forcing, result, status)
    type(wofost_one_day_rate_state_view_t), intent(in) :: state_view
    type(wofost_rate_parameter_bundle_t), intent(in) :: parameters
    type(wofost_prepare_assimilation_forcing_t), intent(in) :: forcing
    type(wofost_prepare_assimilation_result_t), intent(out) :: result
    integer, intent(out) :: status
    type(wofost_rate_scalar_parameters_t) :: scalars
    real(real64) :: effc, amax_dvs, temperature_factor, amax
    real(real64) :: minimum_temperature_factor, dtga
    integer :: parameter_status

    result = wofost_prepare_assimilation_result_t()
    status = WOFOST_PREPARE_ASSIMILATION_INVALID_STATE_VIEW
    if (state_view%validate() /= WOFOST_RATE_STATE_VIEW_OK) return

    status = WOFOST_PREPARE_ASSIMILATION_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    scalars = parameters%scalar_view()

    status = WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING
    if (.not. forcing_valid(forcing)) return

    call parameters%evaluate_maximum_assimilation(state_view%development_stage, &
         amax_dvs, parameter_status)
    if (parameter_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if
    if (.not. valid_inclusive(amax_dvs, 0.0_real64, 100.0_real64)) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if

    call parameters%evaluate_daytime_temperature_factor(forcing%daytime_mean_temperature, &
         temperature_factor, parameter_status)
    if (parameter_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if
    if (.not. valid_inclusive(temperature_factor, 0.0_real64, 1.0_real64)) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if

    call parameters%evaluate_minimum_temperature_factor(forcing%running_minimum_temperature, &
         minimum_temperature_factor, parameter_status)
    if (parameter_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if
    if (.not. valid_inclusive(minimum_temperature_factor, 0.0_real64, 1.0_real64)) then
      status = WOFOST_PREPARE_ASSIMILATION_TABLE_ERROR
      return
    end if

    ! Preserve the B1.10 source multiplication order.
    effc = forcing%co2_efficiency_factor * scalars%initial_light_use_efficiency
    amax = forcing%co2_amax_factor * amax_dvs * temperature_factor
    if (.not. ieee_is_finite(effc) .or. .not. ieee_is_finite(amax)) then
      status = WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT
      return
    end if

    ! B1.10 TOTASS is exactly zero when AMAX<=0 or LAI<=0. RAD=0 also
    ! gives an exact zero path, so do not demand unused solar denominators.
    if (amax <= 0.0_real64 .or. state_view%actual_leaf_area_index <= 0.0_real64 .or. &
        forcing%global_radiation == 0.0_real64) then
      result%actual_pgass = 0.0_real64
      status = WOFOST_PREPARE_ASSIMILATION_OK
      return
    end if

    call daily_total_gross_assimilation(forcing, amax, effc, &
         state_view%actual_leaf_area_index, scalars%diffuse_extinction_coefficient, dtga, status)
    if (status /= WOFOST_PREPARE_ASSIMILATION_OK) return

    dtga = dtga * minimum_temperature_factor
    result%actual_pgass = dtga * 30.0_real64 * &
         (0.4_real64 / scalars%co2_to_dry_matter_fraction) / 44.0_real64
    result%actual_pgass = result%actual_pgass * scalars%attainable_yield_multiplier
    if (.not. ieee_is_finite(result%actual_pgass)) then
      result = wofost_prepare_assimilation_result_t()
      status = WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT
      return
    end if

    status = WOFOST_PREPARE_ASSIMILATION_OK
  end subroutine prepare_wofost_actual_assimilation

  subroutine daily_total_gross_assimilation(forcing, amax, eff, lai, kdif, dtga, status)
    type(wofost_prepare_assimilation_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: amax, eff, lai, kdif
    real(real64), intent(out) :: dtga
    integer, intent(out) :: status
    integer :: i
    real(real64) :: hour, sinb, par, pardif, pardir, fgros

    dtga = 0.0_real64
    status = WOFOST_PREPARE_ASSIMILATION_INVALID_SOLAR_GEOMETRY
    if (forcing%daily_effective_solar_height <= 0.0_real64) return

    do i = 1, 3
      hour = 12.0_real64 + 0.5_real64 * forcing%daylength_hours * XGAUSS(i)
      sinb = max(0.0_real64, forcing%sine_solar_height_offset + &
           forcing%sine_solar_height_amplitude * &
           cos(2.0_real64 * PI_REFERENCE * (hour + 12.0_real64) / 24.0_real64))
      if (.not. ieee_is_finite(sinb)) return
      if (sinb <= 0.0_real64) return
      if (sinb > 1.0_real64 + 64.0_real64 * epsilon(1.0_real64)) return

      par = 0.5_real64 * forcing%global_radiation * sinb * &
           (1.0_real64 + 0.4_real64 * sinb) / forcing%daily_effective_solar_height
      pardif = min(par, sinb * forcing%diffuse_irradiation_perpendicular)
      pardir = par - pardif
      if (.not. ieee_is_finite(par) .or. .not. ieee_is_finite(pardif) .or. &
          .not. ieee_is_finite(pardir)) then
        status = WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT
        return
      end if

      call canopy_gross_assimilation(amax, eff, lai, sinb, pardir, pardif, kdif, fgros, status)
      if (status /= WOFOST_PREPARE_ASSIMILATION_OK) return
      dtga = dtga + fgros * WGAUSS(i)
    end do

    dtga = dtga * forcing%daylength_hours
    if (.not. ieee_is_finite(dtga)) then
      dtga = 0.0_real64
      status = WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT
      return
    end if
    status = WOFOST_PREPARE_ASSIMILATION_OK
  end subroutine daily_total_gross_assimilation

  subroutine canopy_gross_assimilation(amax, eff, lai, sinb, pardir, pardif, kdif, fgros, status)
    real(real64), intent(in) :: amax, eff, lai, sinb, pardir, pardif, kdif
    real(real64), intent(out) :: fgros
    integer, intent(out) :: status
    integer :: i
    real(real64) :: refh, refs, kdirbl, kdirt, laic, visdf, vist, visd, visshd
    real(real64) :: fgrsh, vispp, fgrsun, fslla, fgl, denominator
    real(real64), parameter :: scv = 0.2_real64
    real(real64), parameter :: sqrt_scv = (1.0_real64 - scv)**0.5_real64

    status = WOFOST_PREPARE_ASSIMILATION_INVALID_SOLAR_GEOMETRY
    if (sinb <= 0.0_real64) return

    refh = (1.0_real64 - sqrt_scv) / (1.0_real64 + sqrt_scv)
    refs = refh * 2.0_real64 / (1.0_real64 + 1.6_real64 * sinb)
    kdirbl = (0.5_real64 / sinb) * kdif / (0.8_real64 * sqrt_scv)
    kdirt = kdirbl * sqrt_scv

    fgros = 0.0_real64
    do i = 1, 3
      laic = lai * XGAUSS(i)
      visdf = (1.0_real64 - refs) * pardif * kdif * exp(-kdif * laic)
      vist = (1.0_real64 - refs) * pardir * kdirt * exp(-kdirt * laic)
      visd = (1.0_real64 - scv) * pardir * kdirbl * exp(-kdirbl * laic)

      visshd = visdf + vist - visd
      fgrsh = amax * (1.0_real64 - exp(-visshd * eff / max(2.0_real64, amax)))

      vispp = (1.0_real64 - scv) * pardir / sinb
      if (vispp <= 0.0_real64) then
        fgrsun = fgrsh
      else
        if (eff <= 0.0_real64) then
          fgros = 0.0_real64
          status = WOFOST_PREPARE_ASSIMILATION_ZERO_EFFICIENCY_DIRECT_BEAM
          return
        end if
        denominator = eff * vispp
        if (denominator <= 0.0_real64 .or. .not. ieee_is_finite(denominator)) then
          fgros = 0.0_real64
          status = WOFOST_PREPARE_ASSIMILATION_ZERO_EFFICIENCY_DIRECT_BEAM
          return
        end if
        fgrsun = amax * (1.0_real64 - (amax - fgrsh) * &
             (1.0_real64 - exp(-vispp * eff / max(2.0_real64, amax))) / denominator)
      end if

      fslla = exp(-kdirbl * laic)
      fgl = fslla * fgrsun + (1.0_real64 - fslla) * fgrsh
      fgros = fgros + fgl * WGAUSS(i)
    end do

    fgros = fgros * lai
    if (.not. ieee_is_finite(fgros)) then
      fgros = 0.0_real64
      status = WOFOST_PREPARE_ASSIMILATION_INVALID_RESULT
      return
    end if
    status = WOFOST_PREPARE_ASSIMILATION_OK
  end subroutine canopy_gross_assimilation

  logical function forcing_valid(forcing) result(valid)
    type(wofost_prepare_assimilation_forcing_t), intent(in) :: forcing
    real(real64) :: values(10)

    values = [forcing%daytime_mean_temperature, forcing%global_radiation, &
         forcing%daylength_hours, forcing%sine_solar_height_offset, &
         forcing%sine_solar_height_amplitude, forcing%diffuse_irradiation_perpendicular, &
         forcing%daily_effective_solar_height, forcing%co2_efficiency_factor, &
         forcing%co2_amax_factor, forcing%running_minimum_temperature]

    valid = .false.
    if (.not. all(ieee_is_finite(values))) return
    if (forcing%global_radiation < 0.0_real64 .or. forcing%global_radiation > 5.0e6_real64) return
    if (forcing%daylength_hours < 0.0_real64 .or. forcing%daylength_hours > 24.0_real64) return
    if (forcing%diffuse_irradiation_perpendicular < 0.0_real64) return
    if (forcing%co2_efficiency_factor < 0.0_real64 .or. forcing%co2_efficiency_factor > 2.0_real64) return
    if (forcing%co2_amax_factor < 0.0_real64 .or. forcing%co2_amax_factor > 2.0_real64) return
    valid = .true.
  end function forcing_valid

  pure logical function valid_inclusive(value, lower, upper) result(valid)
    real(real64), intent(in) :: value, lower, upper

    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= lower .and. value <= upper
  end function valid_inclusive

end module mod_wofost_prepare_assimilation
