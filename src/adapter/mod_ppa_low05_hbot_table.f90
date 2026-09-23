module mod_ppa_low05_hbot_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW05_HBOT_OK = 0
  integer, parameter, public :: PPA_LOW05_HBOT_INVALID_INPUT = 1
  public :: evaluate_ppa_low05_hbot_table

contains

  subroutine evaluate_ppa_low05_hbot_table(date_t1900, head_cm, query_t1900, head_cm_out, status)
    real(real64), intent(in) :: date_t1900(:), head_cm(:), query_t1900
    real(real64), intent(out) :: head_cm_out
    integer, intent(out) :: status
    integer :: upper
    real(real64) :: slope

    head_cm_out = 0.0_real64
    status = PPA_LOW05_HBOT_INVALID_INPUT
    if (size(date_t1900) == 0 .or. size(date_t1900) /= size(head_cm)) return
    if (.not. ieee_is_finite(query_t1900) .or. .not. all(ieee_is_finite(date_t1900)) .or. &
        .not. all(ieee_is_finite(head_cm))) return
    if (size(date_t1900) > 1) then
      if (any(date_t1900(2:) <= date_t1900(:size(date_t1900)-1))) return
    end if

    if (query_t1900 <= date_t1900(1)) then
      head_cm_out = head_cm(1)
    else if (query_t1900 > date_t1900(size(date_t1900))) then
      head_cm_out = head_cm(size(head_cm))
    else
      do upper = 2, size(date_t1900)
        if (date_t1900(upper) >= query_t1900) exit
      end do
      slope = (head_cm(upper) - head_cm(upper-1)) / (date_t1900(upper) - date_t1900(upper-1))
      head_cm_out = head_cm(upper-1) + (query_t1900 - date_t1900(upper-1)) * slope
    end if
    if (.not. ieee_is_finite(head_cm_out)) then
      head_cm_out = 0.0_real64
      return
    end if
    status = PPA_LOW05_HBOT_OK
  end subroutine evaluate_ppa_low05_hbot_table

end module mod_ppa_low05_hbot_table
