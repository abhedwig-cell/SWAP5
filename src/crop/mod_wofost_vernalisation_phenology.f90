module mod_wofost_vernalisation_phenology
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_VERN_OK = 0
  integer, parameter, public :: WOFOST_VERN_INVALID_PARAMETERS = 1
  integer, parameter, public :: WOFOST_VERN_INVALID_STATE = 2
  integer, parameter, public :: WOFOST_VERN_INVALID_FORCING = 3
  integer, parameter, public :: WOFOST_VERN_TABLE_ERROR = 4
  integer, parameter, public :: WOFOST_VERN_INVALID_RESULT = 5

  type, public :: wofost_vernalisation_parameters_t
    real(real64) :: critical_development_stage = 0.0_real64 ! VERNDVS
    real(real64) :: saturation_requirement = 0.0_real64     ! VERNSAT
    real(real64) :: base_requirement = 0.0_real64           ! VERNBASE
    type(wofost_rate_table_t) :: temperature_rate           ! VERNRTB
  contains
    procedure, public :: ready => wofost_vernalisation_parameters_ready
  end type wofost_vernalisation_parameters_t

  type, public :: wofost_vernalisation_state_t
    real(real64) :: accumulated_units = 0.0_real64 ! VERN
    logical :: vernalised = .false.                 ! FL_VERNALISED
  contains
    procedure, public :: validate => wofost_vernalisation_state_validate
  end type wofost_vernalisation_state_t

  type, public :: wofost_vernalisation_daily_result_t
    real(real64) :: vernalisation_rate = 0.0_real64
    real(real64) :: vernalisation_factor = 1.0_real64
    real(real64) :: development_rate = 0.0_real64
    logical :: forced_at_critical_dvs = .false.
    logical :: saturated_after_update = .false.
    logical :: warning_condition = .false.
    type(wofost_vernalisation_state_t) :: candidate_state
  end type wofost_vernalisation_daily_result_t

  public :: evaluate_wofost_idsl2_daily_candidate

contains

  logical function wofost_vernalisation_parameters_ready(self) result(ready)
    class(wofost_vernalisation_parameters_t), intent(in) :: self
    ready = .false.
    if (.not. ieee_is_finite(self%critical_development_stage) .or. &
        self%critical_development_stage < 0.0_real64 .or. self%critical_development_stage > 0.4_real64) return
    if (.not. ieee_is_finite(self%saturation_requirement) .or. self%saturation_requirement < 0.0_real64) return
    if (.not. ieee_is_finite(self%base_requirement) .or. self%base_requirement < 0.0_real64) return
    if (self%saturation_requirement <= self%base_requirement) return
    if (.not. self%temperature_rate%ready()) return
    ready = .true.
  end function wofost_vernalisation_parameters_ready

  integer function wofost_vernalisation_state_validate(self) result(status)
    class(wofost_vernalisation_state_t), intent(in) :: self
    status = WOFOST_VERN_INVALID_STATE
    if (.not. ieee_is_finite(self%accumulated_units) .or. self%accumulated_units < 0.0_real64) return
    status = WOFOST_VERN_OK
  end function wofost_vernalisation_state_validate

  subroutine evaluate_wofost_idsl2_daily_candidate(parameters, committed, development_stage, &
                                                    average_temperature_c, photoperiod_factor, &
                                                    temperature_sum_increment, vegetative_tsum_required, &
                                                    result, status)
    type(wofost_vernalisation_parameters_t), intent(in) :: parameters
    type(wofost_vernalisation_state_t), intent(in) :: committed
    real(real64), intent(in) :: development_stage
    real(real64), intent(in) :: average_temperature_c
    real(real64), intent(in) :: photoperiod_factor
    real(real64), intent(in) :: temperature_sum_increment
    real(real64), intent(in) :: vegetative_tsum_required
    type(wofost_vernalisation_daily_result_t), intent(out) :: result
    integer, intent(out) :: status

    integer :: table_status
    real(real64) :: rate, factor

    result = wofost_vernalisation_daily_result_t()
    result%candidate_state = committed
    status = WOFOST_VERN_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    status = committed%validate()
    if (status /= WOFOST_VERN_OK) return

    status = WOFOST_VERN_INVALID_FORCING
    if (.not. ieee_is_finite(development_stage) .or. development_stage < 0.0_real64) return
    if (.not. ieee_is_finite(average_temperature_c)) return
    if (.not. ieee_is_finite(photoperiod_factor) .or. photoperiod_factor < 0.0_real64 .or. &
        photoperiod_factor > 1.0_real64) return
    if (.not. ieee_is_finite(temperature_sum_increment) .or. temperature_sum_increment < 0.0_real64) return
    if (.not. ieee_is_finite(vegetative_tsum_required) .or. vegetative_tsum_required <= 0.0_real64) return

    rate = 0.0_real64
    factor = 1.0_real64

    ! Literal pinned B1.11 update_dvs_rate(), IDSL=2.
    if (development_stage < 1.0_real64) then
      if (.not. committed%vernalised) then
        if (development_stage < parameters%critical_development_stage) then
          call parameters%temperature_rate%evaluate(average_temperature_c, rate, table_status)
          if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(rate) .or. rate < 0.0_real64) then
            status = WOFOST_VERN_TABLE_ERROR
            return
          end if
          factor = max(0.0_real64, min(1.0_real64, &
               (committed%accumulated_units - parameters%base_requirement) / &
               (parameters%saturation_requirement - parameters%base_requirement)))
        else
          ! B1.11 forces vernalisation immediately at/after VERNDVS. VERNFAC
          ! remains its default 1.0 on this day.
          result%candidate_state%vernalised = .true.
          result%forced_at_critical_dvs = .true.
        end if
      end if

      result%development_rate = factor * photoperiod_factor * temperature_sum_increment / vegetative_tsum_required
    else
      ! Caller owns the generative TSUMAM branch; this component only owns
      ! the IDSL2-specific vegetative modifier/state.
      result%development_rate = 0.0_real64
    end if

    result%vernalisation_rate = rate
    result%vernalisation_factor = factor

    ! Pinned B1.11 outer WOFOST task update occurs after potential and actual
    ! crop updates and advances VERN exactly once per daily event.
    result%candidate_state%accumulated_units = committed%accumulated_units + rate
    if (.not. result%candidate_state%vernalised .and. &
        result%candidate_state%accumulated_units >= parameters%saturation_requirement) then
      result%candidate_state%vernalised = .true.
      result%saturated_after_update = .true.
    else if (result%candidate_state%vernalised .and. &
             result%candidate_state%accumulated_units < parameters%saturation_requirement) then
      ! Source emits a one-time warning in this condition. Warning suppression
      ! is diagnostics/UI state and is deliberately not physics continuation.
      result%warning_condition = .true.
    end if

    if (.not. ieee_is_finite(result%development_rate) .or. result%development_rate < 0.0_real64) then
      result = wofost_vernalisation_daily_result_t()
      status = WOFOST_VERN_INVALID_RESULT
      return
    end if
    status = result%candidate_state%validate()
  end subroutine evaluate_wofost_idsl2_daily_candidate

end module mod_wofost_vernalisation_phenology
