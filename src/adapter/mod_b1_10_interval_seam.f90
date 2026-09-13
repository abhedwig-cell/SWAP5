module mod_b1_10_interval_seam
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter, public :: B1_10_INTERVAL_TIME_TOL = 1.0e-8_real64

  type, public :: b1_10_interval_seam_t
    logical :: active = .false.
    logical :: prepared = .false.
    logical :: complete = .false.
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  end type b1_10_interval_seam_t

  public :: begin_b1_10_interval, b1_10_interval_valid

contains

  subroutine begin_b1_10_interval(interval, t0, t1)
    type(b1_10_interval_seam_t), intent(inout) :: interval
    real(real64), intent(in) :: t0, t1
    interval = b1_10_interval_seam_t()
    interval%t0 = t0
    interval%t1 = t1
    interval%active = t1 > t0 + B1_10_INTERVAL_TIME_TOL
  end subroutine begin_b1_10_interval

  pure logical function b1_10_interval_valid(interval) result(valid)
    type(b1_10_interval_seam_t), intent(in) :: interval
    valid = interval%active .and. interval%t1 > interval%t0 + B1_10_INTERVAL_TIME_TOL
  end function b1_10_interval_valid

end module mod_b1_10_interval_seam
