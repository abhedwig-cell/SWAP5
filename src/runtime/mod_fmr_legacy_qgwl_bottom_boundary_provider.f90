module mod_fmr_legacy_qgwl_bottom_boundary_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: FMR_QGWL_OK = 0
  integer, parameter, public :: FMR_QGWL_INVALID_SELECTOR = 1
  integer, parameter, public :: FMR_QGWL_INVALID_STATE = 2
  integer, parameter, public :: FMR_QGWL_INVALID_CONFIG = 3
  integer, parameter, public :: FMR_QGWL_INVALID_TABLE = 4
  integer, parameter, public :: FMR_QGWL_NONFINITE_RESULT = 5

  integer, parameter, public :: FMR_QGWL_EXPONENTIAL = 1
  integer, parameter, public :: FMR_QGWL_TABLE = 2

  type, public :: fmr_qgwl_bottom_boundary_config_t
    integer :: swqhbot = 0
    real(real64) :: cofqha = 0.0_real64
    real(real64) :: cofqhb = 0.0_real64
    real(real64) :: cofqhc = 0.0_real64
    real(real64), allocatable :: htab(:)
    real(real64), allocatable :: qtab(:)
  end type fmr_qgwl_bottom_boundary_config_t

  type, public :: fmr_qgwl_bottom_boundary_result_t
    logical :: available = .false.
    real(real64) :: qbot_cm_per_day = 0.0_real64
    integer :: source_swqhbot = 0
  end type fmr_qgwl_bottom_boundary_result_t

  public :: fmr_evaluate_legacy_qgwl_bottom_boundary

contains

  pure subroutine fmr_evaluate_legacy_qgwl_bottom_boundary(config, groundwater_level_cm, result, status)
    type(fmr_qgwl_bottom_boundary_config_t), intent(in) :: config
    real(real64), intent(in) :: groundwater_level_cm
    type(fmr_qgwl_bottom_boundary_result_t), intent(out) :: result
    integer, intent(out) :: status

    real(real64) :: qbot

    result = fmr_qgwl_bottom_boundary_result_t()
    result%source_swqhbot = config%swqhbot
    status = FMR_QGWL_INVALID_SELECTOR

    if (.not. ieee_is_finite(groundwater_level_cm)) then
      status = FMR_QGWL_INVALID_STATE
      return
    end if

    select case (config%swqhbot)
    case (FMR_QGWL_EXPONENTIAL)
      if (.not. exponential_config_valid(config)) then
        status = FMR_QGWL_INVALID_CONFIG
        return
      end if
      qbot = config%cofqha * exp(config%cofqhb * abs(groundwater_level_cm)) + config%cofqhc
    case (FMR_QGWL_TABLE)
      if (.not. table_config_valid(config)) then
        status = FMR_QGWL_INVALID_TABLE
        return
      end if
      qbot = interpolate_clamped(config%htab, config%qtab, groundwater_level_cm)
    case default
      return
    end select

    if (.not. ieee_is_finite(qbot)) then
      status = FMR_QGWL_NONFINITE_RESULT
      return
    end if

    result%available = .true.
    result%qbot_cm_per_day = qbot
    status = FMR_QGWL_OK
  end subroutine fmr_evaluate_legacy_qgwl_bottom_boundary

  pure logical function exponential_config_valid(config) result(valid)
    type(fmr_qgwl_bottom_boundary_config_t), intent(in) :: config
    valid = ieee_is_finite(config%cofqha) .and. ieee_is_finite(config%cofqhb) .and. ieee_is_finite(config%cofqhc)
    if (.not. valid) return
    valid = config%cofqha >= -100.0_real64 .and. config%cofqha <= 100.0_real64 .and. &
            config%cofqhb >= -1.0_real64 .and. config%cofqhb <= 1.0_real64 .and. &
            config%cofqhc >= -10.0_real64 .and. config%cofqhc <= 10.0_real64
  end function exponential_config_valid

  pure logical function table_config_valid(config) result(valid)
    type(fmr_qgwl_bottom_boundary_config_t), intent(in) :: config
    integer :: i, n
    logical :: ascending, descending

    valid = .false.
    if (.not. allocated(config%htab) .or. .not. allocated(config%qtab)) return
    n = size(config%htab)
    if (n <= 0 .or. size(config%qtab) /= n) return
    if (any(.not. ieee_is_finite(config%htab)) .or. any(.not. ieee_is_finite(config%qtab))) return
    if (any(config%htab < -1.0e4_real64) .or. any(config%htab > 0.0_real64)) return
    if (any(config%qtab < -100.0_real64) .or. any(config%qtab > 100.0_real64)) return
    if (n == 1) then
      valid = .true.
      return
    end if

    ascending = .true.
    descending = .true.
    do i = 2, n
      ascending = ascending .and. config%htab(i) > config%htab(i-1)
      descending = descending .and. config%htab(i) < config%htab(i-1)
    end do
    valid = ascending .or. descending
  end function table_config_valid

  pure real(real64) function interpolate_clamped(x, y, value) result(interpolated)
    real(real64), intent(in) :: x(:), y(:), value
    integer :: i, n

    n = size(x)
    if (n == 1) then
      interpolated = y(1)
      return
    end if

    if (x(n) > x(1)) then
      if (value <= x(1)) then
        interpolated = y(1)
        return
      else if (value >= x(n)) then
        interpolated = y(n)
        return
      end if
      do i = 1, n-1
        if (value <= x(i+1)) exit
      end do
    else
      if (value >= x(1)) then
        interpolated = y(1)
        return
      else if (value <= x(n)) then
        interpolated = y(n)
        return
      end if
      do i = 1, n-1
        if (value >= x(i+1)) exit
      end do
    end if
    interpolated = y(i) + (y(i+1)-y(i)) * (value-x(i)) / (x(i+1)-x(i))
  end function interpolate_clamped

end module mod_fmr_legacy_qgwl_bottom_boundary_provider
