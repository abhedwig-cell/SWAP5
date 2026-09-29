module mod_vonhhbraden_interception
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: VONHHBRADEN_AVAILABLE = 0
  integer, parameter, public :: VONHHBRADEN_INVALID_INPUT = 1
  real(real64), parameter :: SMALL = 1.0e-5_real64

  type, public :: vonhhbraden_parameters_t
    real(real64) :: cofab_cm = 0.0_real64
  end type

  type, public :: vonhhbraden_source_window_t
    real(real64) :: gross_rain_cm_per_day = 0.0_real64
    real(real64) :: sprinkling_irrigation_cm_per_day = 0.0_real64
    logical :: sprinkling_is_intercepted = .true.
    real(real64) :: leaf_area_index = 0.0_real64
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    logical :: snow_present = .false.
  end type

  type, public :: vonhhbraden_result_t
    integer :: status = VONHHBRADEN_INVALID_INPUT
    real(real64) :: source_window_interception_cm_per_day = 0.0_real64
    real(real64) :: wet_canopy_fraction = 0.0_real64
  end type

  public :: evaluate_vonhhbraden_source_window
  public :: apportion_vonhhbraden_interception

contains

  pure subroutine evaluate_vonhhbraden_source_window(parameters, source, wet_canopy_capacity_cm_per_day, result)
    type(vonhhbraden_parameters_t), intent(in) :: parameters
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(in) :: wet_canopy_capacity_cm_per_day
    type(vonhhbraden_result_t), intent(out) :: result
    real(real64) :: rpd_mm_per_day

    result = vonhhbraden_result_t()
    if (.not. valid_source(parameters, source, wet_canopy_capacity_cm_per_day)) return

    if (source%leaf_area_index < 1.0e-3_real64 .or. &
        intercepted_rate(source) < SMALL .or. source%snow_present) then
      result%status = VONHHBRADEN_AVAILABLE
      return
    end if

    rpd_mm_per_day = 10.0_real64 * intercepted_rate(source)
    result%source_window_interception_cm_per_day = 0.1_real64 / &
      (1.0_real64 / (parameters%cofab_cm * source%leaf_area_index) + &
       1.0_real64 / (rpd_mm_per_day * source%vegetation_cover_fraction))
    if (wet_canopy_capacity_cm_per_day >= 1.0e-3_real64) then
      result%wet_canopy_fraction = max(min(result%source_window_interception_cm_per_day / &
        wet_canopy_capacity_cm_per_day, 1.0_real64), 0.0_real64)
    end if
    result%status = VONHHBRADEN_AVAILABLE
  end subroutine

  pure subroutine apportion_vonhhbraden_interception(source, aggregate_cm_per_day, interval_rain_cm_per_day, &
      interval_irrigation_cm_per_day, interception_cm_per_day, net_rain_cm_per_day, net_irrigation_cm_per_day, status)
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(in) :: aggregate_cm_per_day, interval_rain_cm_per_day, interval_irrigation_cm_per_day
    real(real64), intent(out) :: interception_cm_per_day, net_rain_cm_per_day, net_irrigation_cm_per_day
    integer, intent(out) :: status
    real(real64) :: source_rate, interval_rate

    interception_cm_per_day = 0.0_real64; net_rain_cm_per_day = 0.0_real64; net_irrigation_cm_per_day = 0.0_real64
    status = VONHHBRADEN_INVALID_INPUT
    if (.not. valid_nonnegative(aggregate_cm_per_day) .or. .not. valid_nonnegative(interval_rain_cm_per_day) .or. &
        .not. valid_nonnegative(interval_irrigation_cm_per_day)) return
    source_rate = intercepted_rate(source)
    interval_rate = interval_rain_cm_per_day
    if (source%sprinkling_is_intercepted) interval_rate = interval_rate + interval_irrigation_cm_per_day
    if (source_rate > 0.0_real64) interception_cm_per_day = interval_rate * aggregate_cm_per_day / source_rate
    if (interception_cm_per_day < SMALL) then
      net_rain_cm_per_day = interval_rain_cm_per_day; net_irrigation_cm_per_day = interval_irrigation_cm_per_day
    else if (source%sprinkling_is_intercepted .and. interval_rate > SMALL) then
      net_rain_cm_per_day = interval_rain_cm_per_day - interception_cm_per_day * interval_rain_cm_per_day / interval_rate
      net_irrigation_cm_per_day = interval_irrigation_cm_per_day - &
        interception_cm_per_day * interval_irrigation_cm_per_day / interval_rate
    else
      net_rain_cm_per_day = interval_rain_cm_per_day - interception_cm_per_day
      net_irrigation_cm_per_day = interval_irrigation_cm_per_day
    end if
    status = VONHHBRADEN_AVAILABLE
  end subroutine

  pure real(real64) function intercepted_rate(source)
    type(vonhhbraden_source_window_t), intent(in) :: source
    intercepted_rate = source%gross_rain_cm_per_day
    if (source%sprinkling_is_intercepted) intercepted_rate = intercepted_rate + source%sprinkling_irrigation_cm_per_day
  end function

  pure logical function valid_nonnegative(value)
    real(real64), intent(in) :: value
    valid_nonnegative = ieee_is_finite(value) .and. value >= 0.0_real64
  end function

  pure logical function valid_source(parameters, source, capacity)
    type(vonhhbraden_parameters_t), intent(in) :: parameters
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(in) :: capacity
    valid_source = valid_nonnegative(parameters%cofab_cm) .and. valid_nonnegative(source%gross_rain_cm_per_day) .and. &
      valid_nonnegative(source%sprinkling_irrigation_cm_per_day) .and. valid_nonnegative(source%leaf_area_index) .and. &
      ieee_is_finite(source%vegetation_cover_fraction) .and. source%vegetation_cover_fraction >= 0.0_real64 .and. &
      source%vegetation_cover_fraction <= 1.0_real64 .and. valid_nonnegative(capacity)
    if (source%leaf_area_index >= 1.0e-3_real64 .and. intercepted_rate(source) >= SMALL .and. .not. source%snow_present) &
      valid_source = valid_source .and. parameters%cofab_cm > 0.0_real64 .and. source%vegetation_cover_fraction > 0.0_real64
  end function
end module
