module mod_b110_legacy_swbotb2_application_control
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: B110_SWBOTB2_OK = 0
  integer, parameter, public :: B110_SWBOTB2_INVALID_CONTROL = 1
  integer, parameter, public :: B110_SWBOTB2_TIME_NOT_COVERED = 2

  integer, parameter, public :: B110_SWBOTB2_SINE = 1
  integer, parameter, public :: B110_SWBOTB2_TABLE = 2
  real(real64), parameter, public :: B110_SWBOTB2_DRY_HEAD_CM = -1.0e7_real64

  type, public :: b110_legacy_swbotb2_application_control_t
    private
    logical :: initialized = .false.
    integer :: sw2 = 0
    real(real64) :: canonical_origin_time = 0.0_real64
    real(real64) :: legacy_t1900_origin = 0.0_real64
    real(real64) :: sinave = 0.0_real64
    real(real64) :: sinamp = 0.0_real64
    real(real64) :: sinmax = 0.0_real64
    real(real64), allocatable :: calendar_year_start_t1900(:)
    real(real64), allocatable :: table_t1900(:)
    real(real64), allocatable :: table_qbot(:)
  contains
    procedure, public :: initialize_sine => b110_swbotb2_initialize_sine
    procedure, public :: initialize_table => b110_swbotb2_initialize_table
    procedure, public :: ready => b110_swbotb2_ready
    procedure, public :: evaluate => b110_swbotb2_evaluate
  end type b110_legacy_swbotb2_application_control_t

contains

  subroutine b110_swbotb2_initialize_sine(self, canonical_origin_time, legacy_t1900_origin, &
                                           calendar_year_start_t1900, sinave, sinamp, sinmax, status)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin_time, legacy_t1900_origin
    real(real64), intent(in) :: calendar_year_start_t1900(:)
    real(real64), intent(in) :: sinave, sinamp, sinmax
    integer, intent(out) :: status

    call clear_control(self)
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin_time) .or. .not. ieee_is_finite(legacy_t1900_origin)) return
    if (.not. ieee_is_finite(sinave) .or. .not. ieee_is_finite(sinamp) .or. .not. ieee_is_finite(sinmax)) return
    if (sinave < -10.0_real64 .or. sinave > 10.0_real64) return
    if (sinamp < -10.0_real64 .or. sinamp > 10.0_real64) return
    if (sinmax < 0.0_real64 .or. sinmax > 366.0_real64) return
    if (size(calendar_year_start_t1900) < 2) return
    if (any(.not. ieee_is_finite(calendar_year_start_t1900))) return
    if (.not. strictly_increasing(calendar_year_start_t1900)) return

    self%sw2 = B110_SWBOTB2_SINE
    self%canonical_origin_time = canonical_origin_time
    self%legacy_t1900_origin = legacy_t1900_origin
    self%sinave = sinave
    self%sinamp = sinamp
    self%sinmax = sinmax
    allocate(self%calendar_year_start_t1900(size(calendar_year_start_t1900)))
    self%calendar_year_start_t1900 = calendar_year_start_t1900
    self%initialized = .true.
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_initialize_sine

  subroutine b110_swbotb2_initialize_table(self, canonical_origin_time, legacy_t1900_origin, &
                                            table_t1900, table_qbot, status)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin_time, legacy_t1900_origin
    real(real64), intent(in) :: table_t1900(:), table_qbot(:)
    integer, intent(out) :: status

    call clear_control(self)
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin_time) .or. .not. ieee_is_finite(legacy_t1900_origin)) return
    if (size(table_t1900) <= 0 .or. size(table_t1900) /= size(table_qbot)) return
    if (any(.not. ieee_is_finite(table_t1900)) .or. any(.not. ieee_is_finite(table_qbot))) return
    if (size(table_t1900) > 1) then
      if (.not. strictly_increasing(table_t1900)) return
    end if
    if (any(table_qbot < -100.0_real64) .or. any(table_qbot > 100.0_real64)) return

    self%sw2 = B110_SWBOTB2_TABLE
    self%canonical_origin_time = canonical_origin_time
    self%legacy_t1900_origin = legacy_t1900_origin
    allocate(self%table_t1900(size(table_t1900)), self%table_qbot(size(table_qbot)))
    self%table_t1900 = table_t1900
    self%table_qbot = table_qbot
    self%initialized = .true.
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_initialize_table

  logical function b110_swbotb2_ready(self) result(ok)
    class(b110_legacy_swbotb2_application_control_t), intent(in) :: self

    ok = self%initialized .and. ieee_is_finite(self%canonical_origin_time) .and. &
         ieee_is_finite(self%legacy_t1900_origin)
    if (.not. ok) return

    select case (self%sw2)
    case (B110_SWBOTB2_SINE)
      ok = allocated(self%calendar_year_start_t1900)
      if (.not. ok) return
      ok = size(self%calendar_year_start_t1900) >= 2 .and. &
           all(ieee_is_finite(self%calendar_year_start_t1900)) .and. &
           strictly_increasing(self%calendar_year_start_t1900) .and. &
           ieee_is_finite(self%sinave) .and. ieee_is_finite(self%sinamp) .and. ieee_is_finite(self%sinmax) .and. &
           self%sinave >= -10.0_real64 .and. self%sinave <= 10.0_real64 .and. &
           self%sinamp >= -10.0_real64 .and. self%sinamp <= 10.0_real64 .and. &
           self%sinmax >= 0.0_real64 .and. self%sinmax <= 366.0_real64
    case (B110_SWBOTB2_TABLE)
      ok = allocated(self%table_t1900) .and. allocated(self%table_qbot)
      if (.not. ok) return
      ok = size(self%table_t1900) > 0 .and. size(self%table_t1900) == size(self%table_qbot) .and. &
           all(ieee_is_finite(self%table_t1900)) .and. all(ieee_is_finite(self%table_qbot)) .and. &
           all(self%table_qbot >= -100.0_real64) .and. all(self%table_qbot <= 100.0_real64)
      if (ok .and. size(self%table_t1900) > 1) ok = strictly_increasing(self%table_t1900)
    case default
      ok = .false.
    end select
  end function b110_swbotb2_ready

  subroutine b110_swbotb2_evaluate(self, substep_t0, substep_t1, bottom_pressure_head_cm, &
                                    effective_bottom_mode, bottom_flux, status)
    class(b110_legacy_swbotb2_application_control_t), intent(in) :: self
    real(real64), intent(in) :: substep_t0, substep_t1, bottom_pressure_head_cm
    integer, intent(out) :: effective_bottom_mode
    real(real64), intent(out) :: bottom_flux
    integer, intent(out) :: status

    real(real64) :: legacy_start_t1900, legacy_end_t1900, legacy_t, twopi, freq
    integer :: iyear

    effective_bottom_mode = 0
    bottom_flux = 0.0_real64
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. self%ready()) return
    if (.not. ieee_is_finite(substep_t0) .or. .not. ieee_is_finite(substep_t1) .or. &
        substep_t1 <= substep_t0 .or. .not. ieee_is_finite(bottom_pressure_head_cm)) return

    ! Exact B1.11 BoundBottom guard. Internal -2 is derived from the current
    ! trial-start state and is deliberately not persisted as application state.
    if (bottom_pressure_head_cm < B110_SWBOTB2_DRY_HEAD_CM) then
      effective_bottom_mode = -2
      status = B110_SWBOTB2_OK
      return
    end if

    effective_bottom_mode = 2
    legacy_start_t1900 = self%legacy_t1900_origin + (substep_t0 - self%canonical_origin_time)
    legacy_end_t1900 = self%legacy_t1900_origin + (substep_t1 - self%canonical_origin_time)
    if (.not. ieee_is_finite(legacy_start_t1900) .or. .not. ieee_is_finite(legacy_end_t1900)) then
      effective_bottom_mode = 0
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end if

    select case (self%sw2)
    case (B110_SWBOTB2_SINE)
      iyear = containing_year(self%calendar_year_start_t1900, legacy_start_t1900)
      if (iyear <= 0) then
        effective_bottom_mode = 0
        status = B110_SWBOTB2_TIME_NOT_COVERED
        return
      end if
      legacy_t = legacy_start_t1900 - self%calendar_year_start_t1900(iyear)
      twopi = 8.0_real64 * atan(1.0_real64)
      freq = twopi / 365.0_real64
      bottom_flux = self%sinave + self%sinamp * cos(freq * (legacy_t - self%sinmax))
    case (B110_SWBOTB2_TABLE)
      bottom_flux = afgen_pairs(self%table_t1900, self%table_qbot, legacy_end_t1900)
    case default
      effective_bottom_mode = 0
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end select

    if (.not. ieee_is_finite(bottom_flux)) then
      effective_bottom_mode = 0
      bottom_flux = 0.0_real64
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end if
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_evaluate

  subroutine clear_control(self)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self

    self%initialized = .false.
    self%sw2 = 0
    self%canonical_origin_time = 0.0_real64
    self%legacy_t1900_origin = 0.0_real64
    self%sinave = 0.0_real64
    self%sinamp = 0.0_real64
    self%sinmax = 0.0_real64
    if (allocated(self%calendar_year_start_t1900)) deallocate(self%calendar_year_start_t1900)
    if (allocated(self%table_t1900)) deallocate(self%table_t1900)
    if (allocated(self%table_qbot)) deallocate(self%table_qbot)
  end subroutine clear_control

  pure logical function strictly_increasing(values) result(ok)
    real(real64), intent(in) :: values(:)
    integer :: i

    ok = .true.
    do i = 2, size(values)
      if (values(i) <= values(i-1)) then
        ok = .false.
        return
      end if
    end do
  end function strictly_increasing

  pure integer function containing_year(year_starts, value) result(index)
    real(real64), intent(in) :: year_starts(:), value
    integer :: i

    index = 0
    do i = 1, size(year_starts) - 1
      if (value >= year_starts(i) .and. value < year_starts(i+1)) then
        index = i
        return
      end if
    end do
  end function containing_year

  pure real(real64) function afgen_pairs(x_table, y_table, x) result(value)
    real(real64), intent(in) :: x_table(:), y_table(:), x
    real(real64) :: slope
    integer :: i

    if (x <= x_table(1) .or. size(x_table) == 1) then
      value = y_table(1)
      return
    end if
    do i = 2, size(x_table)
      if (x <= x_table(i)) then
        slope = (y_table(i) - y_table(i-1)) / (x_table(i) - x_table(i-1))
        value = y_table(i-1) + (x - x_table(i-1)) * slope
        return
      end if
    end do
    value = y_table(size(y_table))
  end function afgen_pairs

end module mod_b110_legacy_swbotb2_application_control
