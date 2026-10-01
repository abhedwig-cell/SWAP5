module mod_fmr_macropore_reduction_continuation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: MACROPORE_REDUCTION_MIN_LEVEL = 0
  integer, parameter, public :: MACROPORE_REDUCTION_MAX_LEVEL = 3
  integer, parameter, public :: MACROPORE_REDUCTION_RECOVERY_STEPS = 10

  real(real64), parameter :: REDUCTION_FACTORS(0:3) = [ &
       1.0_real64, 0.1_real64, 0.01_real64, 0.001_real64 ]

  type, public :: macropore_reduction_continuation_t
    integer :: reduction_level = 0
    integer :: accepted_step_count = 0
    real(real64) :: recovery_dt = 0.0_real64
    logical :: initialized = .false.
  contains
    procedure, public :: ready => macropore_reduction_ready
    procedure, public :: factor => macropore_reduction_factor
    procedure, public :: same_values => macropore_reduction_same_values
  end type macropore_reduction_continuation_t

  public :: initialize_macropore_reduction_continuation
  public :: propose_macropore_reduction_escalation
  public :: propose_macropore_reduction_acceptance

contains

  subroutine initialize_macropore_reduction_continuation(state, initial_dt, ok)
    type(macropore_reduction_continuation_t), intent(out) :: state
    real(real64), intent(in) :: initial_dt
    logical, intent(out) :: ok

    state = macropore_reduction_continuation_t()
    ok = .false.
    if (.not. ieee_is_finite(initial_dt) .or. initial_dt <= 0.0_real64) return

    state%reduction_level = 0
    state%accepted_step_count = 0
    state%recovery_dt = initial_dt
    state%initialized = .true.
    ok = .true.
  end subroutine initialize_macropore_reduction_continuation

  logical function macropore_reduction_ready(self) result(ready)
    class(macropore_reduction_continuation_t), intent(in) :: self
    ready = self%initialized .and. &
         self%reduction_level >= MACROPORE_REDUCTION_MIN_LEVEL .and. &
         self%reduction_level <= MACROPORE_REDUCTION_MAX_LEVEL .and. &
         self%accepted_step_count >= 0 .and. &
         self%accepted_step_count < MACROPORE_REDUCTION_RECOVERY_STEPS .and. &
         ieee_is_finite(self%recovery_dt) .and. self%recovery_dt > 0.0_real64
  end function macropore_reduction_ready

  real(real64) function macropore_reduction_factor(self) result(factor)
    class(macropore_reduction_continuation_t), intent(in) :: self
    if (.not. self%ready()) then
      factor = 0.0_real64
      return
    end if
    factor = REDUCTION_FACTORS(self%reduction_level)
  end function macropore_reduction_factor

  logical function macropore_reduction_same_values(self, other) result(same)
    class(macropore_reduction_continuation_t), intent(in) :: self
    type(macropore_reduction_continuation_t), intent(in) :: other
    same = self%initialized .eqv. other%initialized .and. &
         self%reduction_level == other%reduction_level .and. &
         self%accepted_step_count == other%accepted_step_count .and. &
         transfer(self%recovery_dt, 0_8) == transfer(other%recovery_dt, 0_8)
  end function macropore_reduction_same_values

  subroutine propose_macropore_reduction_escalation(committed, current_dt, dtmin, dtmax, candidate, retry_dt, available)
    type(macropore_reduction_continuation_t), intent(in) :: committed
    real(real64), intent(in) :: current_dt, dtmin, dtmax
    type(macropore_reduction_continuation_t), intent(out) :: candidate
    real(real64), intent(out) :: retry_dt
    logical, intent(out) :: available

    candidate = committed
    retry_dt = 0.0_real64
    available = .false.

    if (.not. committed%ready()) return
    if (.not. ieee_is_finite(current_dt) .or. .not. ieee_is_finite(dtmin) .or. .not. ieee_is_finite(dtmax)) return
    if (current_dt <= 0.0_real64 .or. dtmin <= 0.0_real64 .or. dtmax < dtmin) return
    if (committed%reduction_level >= MACROPORE_REDUCTION_MAX_LEVEL) return

    candidate%reduction_level = committed%reduction_level + 1
    candidate%recovery_dt = current_dt
    ! Exact source does not reset NStep on escalation.
    candidate%accepted_step_count = committed%accepted_step_count

    retry_dt = sqrt(dtmin*dtmax)
    available = candidate%ready() .and. ieee_is_finite(retry_dt) .and. retry_dt > 0.0_real64
  end subroutine propose_macropore_reduction_escalation

  subroutine propose_macropore_reduction_acceptance(committed, accepted_dt, candidate, recovered, ok)
    type(macropore_reduction_continuation_t), intent(in) :: committed
    real(real64), intent(in) :: accepted_dt
    type(macropore_reduction_continuation_t), intent(out) :: candidate
    logical, intent(out) :: recovered
    logical, intent(out) :: ok

    candidate = committed
    recovered = .false.
    ok = .false.

    if (.not. committed%ready()) return
    if (.not. ieee_is_finite(accepted_dt) .or. accepted_dt <= 0.0_real64) return

    if (committed%reduction_level > 0) then
      if (candidate%accepted_step_count < MACROPORE_REDUCTION_RECOVERY_STEPS) &
           candidate%accepted_step_count = candidate%accepted_step_count + 1

      if (accepted_dt > committed%recovery_dt .or. &
          candidate%accepted_step_count >= MACROPORE_REDUCTION_RECOVERY_STEPS) then
        candidate%recovery_dt = accepted_dt
        candidate%accepted_step_count = 0
        candidate%reduction_level = candidate%reduction_level - 1
        recovered = .true.
      end if
    end if

    ok = candidate%ready()
  end subroutine propose_macropore_reduction_acceptance

end module mod_fmr_macropore_reduction_continuation
