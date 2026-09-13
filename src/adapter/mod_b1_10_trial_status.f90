module mod_b1_10_trial_status
  implicit none
  private

  integer, parameter, public :: B1_10_TRIAL_STATUS_UNSET = 0
  integer, parameter, public :: B1_10_TRIAL_STATUS_SUCCESS = 1
  integer, parameter, public :: B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL = 2
  integer, parameter, public :: B1_10_TRIAL_STATUS_FATAL_CONTRACT = 3

  integer, parameter, public :: B1_10_TRIAL_REASON_NONE = 0
  integer, parameter, public :: B1_10_TRIAL_REASON_RICHARDS_TERMINAL_NONCONVERGENCE = 1001
  integer, parameter, public :: B1_10_TRIAL_REASON_INVALID_INTERVAL = 2001
  integer, parameter, public :: B1_10_TRIAL_REASON_INTERVAL_NOT_PREPARED = 2002
  integer, parameter, public :: B1_10_TRIAL_REASON_INCOMPLETE_RETURN = 2003

  type, public :: b1_10_trial_status_t
    integer :: code = B1_10_TRIAL_STATUS_UNSET
    integer :: reason = B1_10_TRIAL_REASON_NONE
  contains
    procedure :: succeeded => b1_10_trial_succeeded
    procedure :: retryable => b1_10_trial_retryable
    procedure :: fatal => b1_10_trial_fatal
  end type b1_10_trial_status_t

contains

  pure logical function b1_10_trial_succeeded(self) result(ok)
    class(b1_10_trial_status_t), intent(in) :: self
    ok = self%code == B1_10_TRIAL_STATUS_SUCCESS
  end function b1_10_trial_succeeded

  pure logical function b1_10_trial_retryable(self) result(ok)
    class(b1_10_trial_status_t), intent(in) :: self
    ok = self%code == B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL
  end function b1_10_trial_retryable

  pure logical function b1_10_trial_fatal(self) result(ok)
    class(b1_10_trial_status_t), intent(in) :: self
    ok = self%code == B1_10_TRIAL_STATUS_FATAL_CONTRACT
  end function b1_10_trial_fatal

end module mod_b1_10_trial_status
