module mod_wofost_classic_phenology_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: WOFOST_CLASSIC_PHENOLOGY_OK = 0
  integer, parameter, public :: WOFOST_CLASSIC_PHENOLOGY_INVALID = 1

  integer, parameter, public :: WOFOST_CLASSIC_IDSL_THERMAL = 0
  integer, parameter, public :: WOFOST_CLASSIC_IDSL_PHOTOPERIOD = 1

  public :: evaluate_wofost_classic_idsl01_rate

contains

  subroutine evaluate_wofost_classic_idsl01_rate(idsl, development_stage, temperature_sum_increment, &
                                                   vegetative_tsum_required, generative_tsum_required, &
                                                   photoperiodic_daylength_hours, daylength_lower_hours, &
                                                   daylength_upper_hours, development_rate, status)
    integer, intent(in) :: idsl
    real(real64), intent(in) :: development_stage, temperature_sum_increment
    real(real64), intent(in) :: vegetative_tsum_required, generative_tsum_required
    real(real64), intent(in) :: photoperiodic_daylength_hours
    real(real64), intent(in) :: daylength_lower_hours, daylength_upper_hours
    real(real64), intent(out) :: development_rate
    integer, intent(out) :: status

    real(real64) :: dvred

    development_rate = 0.0_real64
    status = WOFOST_CLASSIC_PHENOLOGY_INVALID

    if (idsl /= WOFOST_CLASSIC_IDSL_THERMAL .and. idsl /= WOFOST_CLASSIC_IDSL_PHOTOPERIOD) return
    if (.not. ieee_is_finite(development_stage) .or. development_stage < 0.0_real64) return
    if (.not. ieee_is_finite(temperature_sum_increment) .or. temperature_sum_increment < 0.0_real64) return
    if (.not. ieee_is_finite(vegetative_tsum_required) .or. vegetative_tsum_required <= 0.0_real64) return
    if (.not. ieee_is_finite(generative_tsum_required) .or. generative_tsum_required <= 0.0_real64) return

    if (idsl == WOFOST_CLASSIC_IDSL_PHOTOPERIOD) then
      if (.not. ieee_is_finite(photoperiodic_daylength_hours) .or. &
          photoperiodic_daylength_hours < 0.0_real64 .or. photoperiodic_daylength_hours > 24.0_real64) return
      if (.not. ieee_is_finite(daylength_lower_hours) .or. .not. ieee_is_finite(daylength_upper_hours)) return
      if (daylength_lower_hours < 0.0_real64 .or. daylength_upper_hours > 24.0_real64 .or. &
          daylength_upper_hours <= daylength_lower_hours) return
    end if

    ! Pinned B1.11 SWAP/wofost.f90 update_dvs_rate(), SWWOFOST=1, IDSL=0/1.
    if (development_stage < 1.0_real64) then
      dvred = 1.0_real64
      if (idsl == WOFOST_CLASSIC_IDSL_PHOTOPERIOD) then
        dvred = max(0.0_real64, min(1.0_real64, &
             (photoperiodic_daylength_hours-daylength_lower_hours) / &
             (daylength_upper_hours-daylength_lower_hours)))
      end if
      development_rate = dvred * temperature_sum_increment / vegetative_tsum_required
    else
      development_rate = temperature_sum_increment / generative_tsum_required
    end if

    if (.not. ieee_is_finite(development_rate) .or. development_rate < 0.0_real64) then
      development_rate = 0.0_real64
      return
    end if
    status = WOFOST_CLASSIC_PHENOLOGY_OK
  end subroutine evaluate_wofost_classic_idsl01_rate

end module mod_wofost_classic_phenology_rate
