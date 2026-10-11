module mod_fmr_legacy_cauchy_bottom_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FMR_CAUCHY3_OK = 0
  integer, parameter, public :: FMR_CAUCHY3_INVALID_CONTROL = 1
  integer, parameter, public :: FMR_CAUCHY3_INVALID_PROPOSAL = 2
  integer, parameter, public :: FMR_CAUCHY3_TIME_NOT_COVERED = 3
  integer, parameter, public :: FMR_CAUCHY3_HEAD_TABLE = 1
  integer, parameter, public :: FMR_CAUCHY3_HEAD_SINE = 2

  real(real64), parameter :: HEAD_MIN_CM = -10000.0_real64
  real(real64), parameter :: HEAD_MAX_CM = 1000.0_real64
  real(real64), parameter :: RESISTANCE_MAX_DAY = 100000.0_real64
  real(real64), parameter :: Q4_ABS_MAX_CM_PER_DAY = 100.0_real64

  type, public :: fmr_cauchy3_proposal_t
    logical :: available = .false.
    real(real64) :: t0 = 0.0_real64
    real(real64) :: original_t1 = 0.0_real64
    real(real64) :: legacy_head_sample_t1900 = 0.0_real64
    real(real64) :: sine_phase_day = 0.0_real64
    real(real64) :: aquifer_total_head_cm = 0.0_real64
  contains
    procedure :: covers => cauchy3_proposal_covers
  end type fmr_cauchy3_proposal_t

  type, public :: fmr_cauchy3_control_t
    private
    logical :: initialized = .false.
    integer :: head_source = 0
    real(real64) :: canonical_origin = 0.0_real64
    real(real64) :: legacy_origin = 0.0_real64
    real(real64) :: rimlay_days = 0.0_real64
    logical :: include_half_cell = .true.
    logical :: q4_supplied = .false.
    real(real64), allocatable :: date3_t1900(:)
    real(real64), allocatable :: haquif_cm(:)
    real(real64), allocatable :: calendar_year_start_t1900(:)
    real(real64) :: aqave_cm = 0.0_real64
    real(real64) :: aqamp_cm = 0.0_real64
    real(real64) :: aqtmax_day = 0.0_real64
    real(real64) :: aqper_day = 0.0_real64
    real(real64), allocatable :: date4_t1900(:)
    real(real64), allocatable :: qbot4_cm_per_day(:)
  contains
    procedure, public :: initialize_table => cauchy3_initialize_table
    procedure, public :: initialize_sine => cauchy3_initialize_sine
    procedure, public :: ready => cauchy3_ready
    procedure, public :: resolve_proposal => cauchy3_resolve_proposal
    procedure, public :: resolve_q4 => cauchy3_resolve_q4
    procedure, public :: external_resistance_days => cauchy3_external_resistance_days
    procedure, public :: half_cell_enabled => cauchy3_half_cell_enabled
    procedure, private :: initialize_common => cauchy3_initialize_common
  end type fmr_cauchy3_control_t

contains

  subroutine cauchy3_initialize_table(self, canonical_origin, legacy_origin, date3_t1900, haquif_cm, &
                                      rimlay_days, include_half_cell, status, date4_t1900, qbot4_cm_per_day)
    class(fmr_cauchy3_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin, legacy_origin
    real(real64), intent(in) :: date3_t1900(:), haquif_cm(:)
    real(real64), intent(in) :: rimlay_days
    logical, intent(in) :: include_half_cell
    integer, intent(out) :: status
    real(real64), intent(in), optional :: date4_t1900(:), qbot4_cm_per_day(:)
    integer :: common_status

    call clear_control(self)
    status = FMR_CAUCHY3_INVALID_CONTROL
    if (size(date3_t1900) <= 0 .or. size(date3_t1900) /= size(haquif_cm)) return
    if (any(.not. ieee_is_finite(date3_t1900)) .or. any(.not. ieee_is_finite(haquif_cm))) return
    if (size(date3_t1900) > 1) then
      if (.not. strictly_increasing(date3_t1900)) return
    end if
    if (any(haquif_cm < HEAD_MIN_CM) .or. any(haquif_cm > HEAD_MAX_CM)) return

    call self%initialize_common(canonical_origin, legacy_origin, rimlay_days, include_half_cell, &
                                common_status, date4_t1900, qbot4_cm_per_day)
    if (common_status /= FMR_CAUCHY3_OK) return

    allocate(self%date3_t1900(size(date3_t1900)), self%haquif_cm(size(haquif_cm)))
    self%date3_t1900 = date3_t1900
    self%haquif_cm = haquif_cm
    self%head_source = FMR_CAUCHY3_HEAD_TABLE
    self%initialized = .true.
    status = FMR_CAUCHY3_OK
  end subroutine cauchy3_initialize_table

  subroutine cauchy3_initialize_sine(self, canonical_origin, legacy_origin, calendar_year_start_t1900, &
                                     aqave_cm, aqamp_cm, aqtmax_day, aqper_day, rimlay_days, &
                                     include_half_cell, status, date4_t1900, qbot4_cm_per_day)
    class(fmr_cauchy3_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin, legacy_origin
    real(real64), intent(in) :: calendar_year_start_t1900(:)
    real(real64), intent(in) :: aqave_cm, aqamp_cm, aqtmax_day, aqper_day, rimlay_days
    logical, intent(in) :: include_half_cell
    integer, intent(out) :: status
    real(real64), intent(in), optional :: date4_t1900(:), qbot4_cm_per_day(:)
    integer :: common_status

    call clear_control(self)
    status = FMR_CAUCHY3_INVALID_CONTROL
    if (size(calendar_year_start_t1900) < 2) return
    if (any(.not. ieee_is_finite(calendar_year_start_t1900))) return
    if (.not. strictly_increasing(calendar_year_start_t1900)) return
    if (.not. ieee_is_finite(aqave_cm) .or. aqave_cm < HEAD_MIN_CM .or. aqave_cm > HEAD_MAX_CM) return
    if (.not. ieee_is_finite(aqamp_cm) .or. aqamp_cm < 0.0_real64 .or. aqamp_cm > 1000.0_real64) return
    if (.not. ieee_is_finite(aqtmax_day) .or. aqtmax_day < 0.0_real64 .or. aqtmax_day > 366.0_real64) return
    if (.not. ieee_is_finite(aqper_day) .or. aqper_day <= 0.0_real64 .or. aqper_day > 366.0_real64) return

    call self%initialize_common(canonical_origin, legacy_origin, rimlay_days, include_half_cell, &
                                common_status, date4_t1900, qbot4_cm_per_day)
    if (common_status /= FMR_CAUCHY3_OK) return

    allocate(self%calendar_year_start_t1900(size(calendar_year_start_t1900)))
    self%calendar_year_start_t1900 = calendar_year_start_t1900
    self%aqave_cm = aqave_cm
    self%aqamp_cm = aqamp_cm
    self%aqtmax_day = aqtmax_day
    self%aqper_day = aqper_day
    self%head_source = FMR_CAUCHY3_HEAD_SINE
    self%initialized = .true.
    status = FMR_CAUCHY3_OK
  end subroutine cauchy3_initialize_sine

  subroutine cauchy3_initialize_common(self, canonical_origin, legacy_origin, rimlay_days, include_half_cell, &
                                       status, date4_t1900, qbot4_cm_per_day)
    class(fmr_cauchy3_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin, legacy_origin, rimlay_days
    logical, intent(in) :: include_half_cell
    integer, intent(out) :: status
    real(real64), intent(in), optional :: date4_t1900(:), qbot4_cm_per_day(:)
    logical :: has_date4, has_q4

    status = FMR_CAUCHY3_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin) .or. .not. ieee_is_finite(legacy_origin)) return
    if (.not. ieee_is_finite(rimlay_days) .or. rimlay_days < 0.0_real64 .or. rimlay_days > RESISTANCE_MAX_DAY) return
    if (.not. include_half_cell .and. rimlay_days <= 0.0_real64) return

    has_date4 = present(date4_t1900)
    has_q4 = present(qbot4_cm_per_day)
    if (has_date4 .neqv. has_q4) return
    if (has_date4) then
      if (size(date4_t1900) <= 0 .or. size(date4_t1900) /= size(qbot4_cm_per_day)) return
      if (any(.not. ieee_is_finite(date4_t1900)) .or. any(.not. ieee_is_finite(qbot4_cm_per_day))) return
      if (size(date4_t1900) > 1) then
        if (.not. strictly_increasing(date4_t1900)) return
      end if
      if (any(qbot4_cm_per_day < -Q4_ABS_MAX_CM_PER_DAY) .or. &
          any(qbot4_cm_per_day > Q4_ABS_MAX_CM_PER_DAY)) return
      allocate(self%date4_t1900(size(date4_t1900)), self%qbot4_cm_per_day(size(qbot4_cm_per_day)))
      self%date4_t1900 = date4_t1900
      self%qbot4_cm_per_day = qbot4_cm_per_day
      self%q4_supplied = .true.
    end if

    self%canonical_origin = canonical_origin
    self%legacy_origin = legacy_origin
    self%rimlay_days = rimlay_days
    self%include_half_cell = include_half_cell
    status = FMR_CAUCHY3_OK
  end subroutine cauchy3_initialize_common

  logical function cauchy3_ready(self) result(ok)
    class(fmr_cauchy3_control_t), intent(in) :: self

    ok = self%initialized .and. ieee_is_finite(self%canonical_origin) .and. &
         ieee_is_finite(self%legacy_origin) .and. ieee_is_finite(self%rimlay_days) .and. &
         self%rimlay_days >= 0.0_real64 .and. self%rimlay_days <= RESISTANCE_MAX_DAY
    if (.not. ok) return
    if (.not. self%include_half_cell .and. self%rimlay_days <= 0.0_real64) then
      ok = .false.
      return
    end if

    select case (self%head_source)
    case (FMR_CAUCHY3_HEAD_TABLE)
      ok = allocated(self%date3_t1900) .and. allocated(self%haquif_cm)
      if (.not. ok) return
      ok = size(self%date3_t1900) > 0 .and. size(self%date3_t1900) == size(self%haquif_cm) .and. &
           all(ieee_is_finite(self%date3_t1900)) .and. all(ieee_is_finite(self%haquif_cm)) .and. &
           all(self%haquif_cm >= HEAD_MIN_CM) .and. all(self%haquif_cm <= HEAD_MAX_CM)
      if (ok .and. size(self%date3_t1900) > 1) ok = strictly_increasing(self%date3_t1900)
    case (FMR_CAUCHY3_HEAD_SINE)
      ok = allocated(self%calendar_year_start_t1900)
      if (.not. ok) return
      ok = size(self%calendar_year_start_t1900) >= 2 .and. &
           all(ieee_is_finite(self%calendar_year_start_t1900)) .and. &
           strictly_increasing(self%calendar_year_start_t1900) .and. &
           ieee_is_finite(self%aqave_cm) .and. self%aqave_cm >= HEAD_MIN_CM .and. self%aqave_cm <= HEAD_MAX_CM .and. &
           ieee_is_finite(self%aqamp_cm) .and. self%aqamp_cm >= 0.0_real64 .and. self%aqamp_cm <= 1000.0_real64 .and. &
           ieee_is_finite(self%aqtmax_day) .and. self%aqtmax_day >= 0.0_real64 .and. self%aqtmax_day <= 366.0_real64 .and. &
           ieee_is_finite(self%aqper_day) .and. self%aqper_day > 0.0_real64 .and. self%aqper_day <= 366.0_real64
    case default
      ok = .false.
    end select
    if (.not. ok) return

    if (self%q4_supplied) then
      ok = allocated(self%date4_t1900) .and. allocated(self%qbot4_cm_per_day)
      if (.not. ok) return
      ok = size(self%date4_t1900) > 0 .and. size(self%date4_t1900) == size(self%qbot4_cm_per_day) .and. &
           all(ieee_is_finite(self%date4_t1900)) .and. all(ieee_is_finite(self%qbot4_cm_per_day)) .and. &
           all(self%qbot4_cm_per_day >= -Q4_ABS_MAX_CM_PER_DAY) .and. &
           all(self%qbot4_cm_per_day <= Q4_ABS_MAX_CM_PER_DAY)
      if (ok .and. size(self%date4_t1900) > 1) ok = strictly_increasing(self%date4_t1900)
    else
      ok = .not. allocated(self%date4_t1900) .and. .not. allocated(self%qbot4_cm_per_day)
    end if
  end function cauchy3_ready

  subroutine cauchy3_resolve_proposal(self, t0, original_t1, proposal, status)
    class(fmr_cauchy3_control_t), intent(in) :: self
    real(real64), intent(in) :: t0, original_t1
    type(fmr_cauchy3_proposal_t), intent(out) :: proposal
    integer, intent(out) :: status
    real(real64) :: legacy_start, legacy_sample, head, phase_day, twopi
    integer :: iyear

    proposal = fmr_cauchy3_proposal_t()
    status = FMR_CAUCHY3_INVALID_CONTROL
    if (.not. self%ready()) return
    status = FMR_CAUCHY3_INVALID_PROPOSAL
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(original_t1) .or. original_t1 <= t0) return

    legacy_start = self%legacy_origin + (t0 - self%canonical_origin)
    if (.not. ieee_is_finite(legacy_start)) return
    legacy_sample = legacy_start
    phase_day = 0.0_real64

    select case (self%head_source)
    case (FMR_CAUCHY3_HEAD_TABLE)
      legacy_sample = self%legacy_origin + (original_t1 - self%canonical_origin)
      if (.not. ieee_is_finite(legacy_sample)) return
      head = afgen_pairs(self%date3_t1900, self%haquif_cm, legacy_sample)
    case (FMR_CAUCHY3_HEAD_SINE)
      iyear = containing_year(self%calendar_year_start_t1900, legacy_start)
      if (iyear <= 0) then
        status = FMR_CAUCHY3_TIME_NOT_COVERED
        return
      end if
      phase_day = legacy_start - self%calendar_year_start_t1900(iyear)
      twopi = 8.0_real64 * atan(1.0_real64)
      head = self%aqave_cm + self%aqamp_cm * cos((twopi / self%aqper_day) * (phase_day - self%aqtmax_day))
    case default
      return
    end select

    if (.not. ieee_is_finite(head) .or. head < HEAD_MIN_CM .or. head > HEAD_MAX_CM) return
    proposal%available = .true.
    proposal%t0 = t0
    proposal%original_t1 = original_t1
    proposal%legacy_head_sample_t1900 = legacy_sample
    proposal%sine_phase_day = phase_day
    proposal%aquifer_total_head_cm = head
    status = FMR_CAUCHY3_OK
  end subroutine cauchy3_resolve_proposal

  subroutine cauchy3_resolve_q4(self, trial_t0, trial_t1, q4_cm_per_day, legacy_sample_t1900, status)
    class(fmr_cauchy3_control_t), intent(in) :: self
    real(real64), intent(in) :: trial_t0, trial_t1
    real(real64), intent(out) :: q4_cm_per_day, legacy_sample_t1900
    integer, intent(out) :: status

    q4_cm_per_day = 0.0_real64
    legacy_sample_t1900 = 0.0_real64
    status = FMR_CAUCHY3_INVALID_CONTROL
    if (.not. self%ready()) return
    status = FMR_CAUCHY3_INVALID_PROPOSAL
    if (.not. ieee_is_finite(trial_t0) .or. .not. ieee_is_finite(trial_t1) .or. trial_t1 <= trial_t0) return

    legacy_sample_t1900 = self%legacy_origin + (trial_t1 - self%canonical_origin)
    if (.not. ieee_is_finite(legacy_sample_t1900)) return
    if (self%q4_supplied) q4_cm_per_day = afgen_pairs(self%date4_t1900, self%qbot4_cm_per_day, legacy_sample_t1900)
    if (.not. ieee_is_finite(q4_cm_per_day) .or. abs(q4_cm_per_day) > Q4_ABS_MAX_CM_PER_DAY) then
      q4_cm_per_day = 0.0_real64
      return
    end if
    status = FMR_CAUCHY3_OK
  end subroutine cauchy3_resolve_q4

  pure real(real64) function cauchy3_external_resistance_days(self) result(value)
    class(fmr_cauchy3_control_t), intent(in) :: self
    value = self%rimlay_days
  end function cauchy3_external_resistance_days

  pure logical function cauchy3_half_cell_enabled(self) result(enabled)
    class(fmr_cauchy3_control_t), intent(in) :: self
    enabled = self%include_half_cell
  end function cauchy3_half_cell_enabled

  logical function cauchy3_proposal_covers(self, t0, t1) result(covers)
    class(fmr_cauchy3_proposal_t), intent(in) :: self
    real(real64), intent(in) :: t0, t1

    covers = .false.
    if (.not. self%available) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    if (.not. ieee_is_finite(self%t0) .or. .not. ieee_is_finite(self%original_t1) .or. &
        .not. ieee_is_finite(self%legacy_head_sample_t1900) .or. .not. ieee_is_finite(self%sine_phase_day) .or. &
        .not. ieee_is_finite(self%aquifer_total_head_cm)) return
    covers = t0 >= self%t0 .and. t1 <= self%original_t1
  end function cauchy3_proposal_covers

  subroutine clear_control(self)
    class(fmr_cauchy3_control_t), intent(inout) :: self
    self%initialized = .false.
    self%head_source = 0
    self%canonical_origin = 0.0_real64
    self%legacy_origin = 0.0_real64
    self%rimlay_days = 0.0_real64
    self%include_half_cell = .true.
    self%q4_supplied = .false.
    self%aqave_cm = 0.0_real64
    self%aqamp_cm = 0.0_real64
    self%aqtmax_day = 0.0_real64
    self%aqper_day = 0.0_real64
    if (allocated(self%date3_t1900)) deallocate(self%date3_t1900)
    if (allocated(self%haquif_cm)) deallocate(self%haquif_cm)
    if (allocated(self%calendar_year_start_t1900)) deallocate(self%calendar_year_start_t1900)
    if (allocated(self%date4_t1900)) deallocate(self%date4_t1900)
    if (allocated(self%qbot4_cm_per_day)) deallocate(self%qbot4_cm_per_day)
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
        slope = (y_table(i)-y_table(i-1))/(x_table(i)-x_table(i-1))
        value = y_table(i-1)+(x-x_table(i-1))*slope
        return
      end if
    end do
    value = y_table(size(y_table))
  end function afgen_pairs

end module mod_fmr_legacy_cauchy_bottom_boundary_provider
