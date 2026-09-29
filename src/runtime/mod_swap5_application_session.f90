module mod_swap5_application_session
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_canonical_contracts, only: canonical_interval_t
  implicit none
  private

  integer, parameter, public :: SWAP5_SESSION_OK = 0
  integer, parameter, public :: SWAP5_SESSION_INVALID = 1

  type, public :: swap5_application_session_t
    private
    logical :: initialized = .false.
    integer(int64) :: generation = 0_int64
  contains
    procedure, public :: initialize => session_initialize
    procedure, public :: initialized_ok => session_initialized
    procedure, public :: validate_interval => session_validate_interval
    procedure, public :: generation_id => session_generation
  end type swap5_application_session_t

contains

  subroutine session_initialize(self, generation, status)
    class(swap5_application_session_t), intent(inout) :: self
    integer(int64), intent(in) :: generation
    integer, intent(out) :: status

    self%initialized = .false.
    self%generation = 0_int64
    status = SWAP5_SESSION_INVALID
    if (generation <= 0_int64) return
    self%generation = generation
    self%initialized = .true.
    status = SWAP5_SESSION_OK
  end subroutine session_initialize

  logical function session_initialized(self) result(ok)
    class(swap5_application_session_t), intent(in) :: self
    ok = self%initialized .and. self%generation > 0_int64
  end function session_initialized

  logical function session_validate_interval(self, interval) result(valid)
    class(swap5_application_session_t), intent(in) :: self
    type(canonical_interval_t), intent(in) :: interval
    valid = self%initialized_ok() .and. ieee_is_finite(interval%t0) .and. &
         ieee_is_finite(interval%t1) .and. interval%t1 > interval%t0
  end function session_validate_interval

  integer(int64) function session_generation(self) result(generation)
    class(swap5_application_session_t), intent(in) :: self
    generation = self%generation
  end function session_generation

end module mod_swap5_application_session
