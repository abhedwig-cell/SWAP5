module mod_drainage_dramet3_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: DRAMET3_OK = 0
  integer, parameter, public :: DRAMET3_INVALID_CONTROL = 1
  integer, parameter, public :: DRAMET3_INVALID_PARAMETERS = 2
  integer, parameter, public :: DRAMET3_INVALID_QUERY = 3

  integer, parameter, public :: DRAMET3_ALLOW_BOTH = 1
  integer, parameter, public :: DRAMET3_INFILTRATION_ONLY = 2
  integer, parameter, public :: DRAMET3_DRAINAGE_ONLY = 3
  integer, parameter, public :: DRAMET3_TUBE = 1
  integer, parameter, public :: DRAMET3_OPEN_CHANNEL = 2

  type, public :: dramet3_channel_control_t
    private
    logical :: initialized = .false.
    real(real64) :: canonical_origin_time = 0.0_real64
    real(real64) :: legacy_t1900_origin = 0.0_real64
    real(real64), allocatable :: table_t1900(:)
    real(real64), allocatable :: table_head_cm(:)
  contains
    procedure, public :: ready => dramet3_control_ready
    procedure, public :: evaluate => dramet3_control_evaluate
  end type dramet3_channel_control_t

  type, public :: dramet3_level_parameters_t
    real(real64) :: drain_bottom_cm = 0.0_real64
    real(real64) :: drainage_resistance_day = 0.0_real64
    real(real64) :: infiltration_resistance_day = 0.0_real64
    integer :: allocation_mode = DRAMET3_ALLOW_BOTH
    integer :: drain_type = DRAMET3_TUBE
    logical :: limit_channel_infiltration = .false.
  end type dramet3_level_parameters_t

  type, public :: dramet3_level_result_t
    integer :: status = DRAMET3_INVALID_PARAMETERS
    logical :: available = .false.
    real(real64) :: legacy_query_t1900 = 0.0_real64
    real(real64) :: resolved_channel_head_cm = 0.0_real64
    real(real64) :: head_difference_cm = 0.0_real64
    real(real64) :: signed_exchange_cm_per_day = 0.0_real64
    logical :: drainage_suppressed = .false.
    logical :: infiltration_suppressed = .false.
    logical :: infiltration_head_limited = .false.
  end type dramet3_level_result_t

  public :: initialize_dramet3_channel_control
  public :: evaluate_dramet3_level

contains

  subroutine initialize_dramet3_channel_control(control, canonical_origin_time, legacy_t1900_origin, &
       table_t1900, table_head_cm, status)
    type(dramet3_channel_control_t), intent(out) :: control
    real(real64), intent(in) :: canonical_origin_time, legacy_t1900_origin
    real(real64), intent(in) :: table_t1900(:), table_head_cm(:)
    integer, intent(out) :: status
    integer :: i

    control = dramet3_channel_control_t()
    status = DRAMET3_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin_time) .or. .not. ieee_is_finite(legacy_t1900_origin)) return
    if (size(table_t1900) < 1 .or. size(table_t1900) /= size(table_head_cm)) return
    if (any(.not. ieee_is_finite(table_t1900)) .or. any(.not. ieee_is_finite(table_head_cm))) return
    do i = 2, size(table_t1900)
      if (table_t1900(i) <= table_t1900(i-1)) return
    end do

    control%canonical_origin_time = canonical_origin_time
    control%legacy_t1900_origin = legacy_t1900_origin
    allocate(control%table_t1900(size(table_t1900)), control%table_head_cm(size(table_head_cm)))
    control%table_t1900 = table_t1900
    control%table_head_cm = table_head_cm
    control%initialized = .true.
    status = DRAMET3_OK
  end subroutine initialize_dramet3_channel_control

  logical function dramet3_control_ready(self) result(ok)
    class(dramet3_channel_control_t), intent(in) :: self
    integer :: i
    ok = self%initialized
    if (.not. ok) return
    if (.not. ieee_is_finite(self%canonical_origin_time) .or. .not. ieee_is_finite(self%legacy_t1900_origin)) then
      ok = .false.
      return
    end if
    if (.not. allocated(self%table_t1900) .or. .not. allocated(self%table_head_cm)) then
      ok = .false.
      return
    end if
    if (size(self%table_t1900) < 1 .or. size(self%table_t1900) /= size(self%table_head_cm)) then
      ok = .false.
      return
    end if
    if (any(.not. ieee_is_finite(self%table_t1900)) .or. any(.not. ieee_is_finite(self%table_head_cm))) then
      ok = .false.
      return
    end if
    do i = 2, size(self%table_t1900)
      if (self%table_t1900(i) <= self%table_t1900(i-1)) then
        ok = .false.
        return
      end if
    end do
  end function dramet3_control_ready

  subroutine dramet3_control_evaluate(self, substep_t1, legacy_query_t1900, channel_head_cm, status)
    class(dramet3_channel_control_t), intent(in) :: self
    real(real64), intent(in) :: substep_t1
    real(real64), intent(out) :: legacy_query_t1900, channel_head_cm
    integer, intent(out) :: status

    legacy_query_t1900 = 0.0_real64
    channel_head_cm = 0.0_real64
    status = DRAMET3_INVALID_CONTROL
    if (.not. self%ready()) return
    if (.not. ieee_is_finite(substep_t1)) then
      status = DRAMET3_INVALID_QUERY
      return
    end if
    legacy_query_t1900 = self%legacy_t1900_origin + (substep_t1 - self%canonical_origin_time)
    if (.not. ieee_is_finite(legacy_query_t1900)) then
      status = DRAMET3_INVALID_QUERY
      return
    end if
    channel_head_cm = afgen_pairs(self%table_t1900, self%table_head_cm, legacy_query_t1900)
    if (.not. ieee_is_finite(channel_head_cm)) then
      status = DRAMET3_INVALID_QUERY
      return
    end if
    status = DRAMET3_OK
  end subroutine dramet3_control_evaluate

  subroutine evaluate_dramet3_level(parameters, control, groundwater_level_cm, substep_t1, result)
    type(dramet3_level_parameters_t), intent(in) :: parameters
    type(dramet3_channel_control_t), intent(in) :: control
    real(real64), intent(in) :: groundwater_level_cm, substep_t1
    type(dramet3_level_result_t), intent(out) :: result
    real(real64) :: channel_head, difference
    integer :: status

    result = dramet3_level_result_t()
    if (.not. valid_parameters(parameters)) return
    if (.not. ieee_is_finite(groundwater_level_cm) .or. .not. ieee_is_finite(substep_t1)) then
      result%status = DRAMET3_INVALID_QUERY
      return
    end if

    call control%evaluate(substep_t1, result%legacy_query_t1900, channel_head, status)
    if (status /= DRAMET3_OK) then
      result%status = status
      return
    end if

    channel_head = max(channel_head, parameters%drain_bottom_cm)
    difference = groundwater_level_cm - channel_head

    result%resolved_channel_head_cm = channel_head
    if (difference > 0.0_real64) then
      if (parameters%allocation_mode == DRAMET3_INFILTRATION_ONLY) then
        result%drainage_suppressed = .true.
        result%signed_exchange_cm_per_day = 0.0_real64
      else
        result%signed_exchange_cm_per_day = difference / parameters%drainage_resistance_day
      end if
    else
      if (parameters%drain_type == DRAMET3_OPEN_CHANNEL .and. parameters%limit_channel_infiltration) then
        if (difference < parameters%drain_bottom_cm - channel_head) result%infiltration_head_limited = .true.
        difference = max(difference, parameters%drain_bottom_cm - channel_head)
      end if
      if (parameters%allocation_mode == DRAMET3_DRAINAGE_ONLY .or. &
          parameters%drain_bottom_cm >= channel_head) then
        result%infiltration_suppressed = .true.
        result%signed_exchange_cm_per_day = 0.0_real64
      else
        result%signed_exchange_cm_per_day = difference / parameters%infiltration_resistance_day
      end if
    end if

    result%head_difference_cm = difference
    result%available = .true.
    result%status = DRAMET3_OK
  end subroutine evaluate_dramet3_level

  logical function valid_parameters(parameters) result(ok)
    type(dramet3_level_parameters_t), intent(in) :: parameters
    ok = .false.
    if (.not. ieee_is_finite(parameters%drain_bottom_cm)) return
    if (.not. ieee_is_finite(parameters%drainage_resistance_day) .or. &
        parameters%drainage_resistance_day <= 0.0_real64) return
    if (.not. ieee_is_finite(parameters%infiltration_resistance_day) .or. &
        parameters%infiltration_resistance_day <= 0.0_real64) return
    if (parameters%allocation_mode < DRAMET3_ALLOW_BOTH .or. parameters%allocation_mode > DRAMET3_DRAINAGE_ONLY) return
    if (parameters%drain_type /= DRAMET3_TUBE .and. parameters%drain_type /= DRAMET3_OPEN_CHANNEL) return
    ok = .true.
  end function valid_parameters

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

end module mod_drainage_dramet3_response
