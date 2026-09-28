module mod_ppa_low03_aquifer_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW03_AQUIFER_TABLE_OK = 0
  integer, parameter, public :: PPA_LOW03_AQUIFER_TABLE_INVALID_INPUT = 1
  public :: evaluate_ppa_low03_aquifer_table

contains

  ! B1.11 SWBOTB=3, SW3=2: deepgw = AFGEN(HAQTAB, T1900+dt).
  subroutine evaluate_ppa_low03_aquifer_table(date_t1900, aquifer_head, query_t1900, deepgw, status)
    real(real64), intent(in) :: date_t1900(:), aquifer_head(:), query_t1900
    real(real64), intent(out) :: deepgw
    integer, intent(out) :: status
    integer :: upper
    real(real64) :: slope

    deepgw = 0.0_real64
    status = PPA_LOW03_AQUIFER_TABLE_INVALID_INPUT
    if (size(date_t1900) == 0 .or. size(date_t1900) /= size(aquifer_head)) return
    if (.not. ieee_is_finite(query_t1900) .or. .not. all(ieee_is_finite(date_t1900)) .or. &
        .not. all(ieee_is_finite(aquifer_head))) return
    if (any(aquifer_head < -10000.0_real64) .or. any(aquifer_head > 1000.0_real64)) return
    if (size(date_t1900) > 1) then
      if (any(date_t1900(2:) <= date_t1900(:size(date_t1900)-1))) return
    end if

    if (query_t1900 <= date_t1900(1)) then
      deepgw = aquifer_head(1)
    else if (query_t1900 > date_t1900(size(date_t1900))) then
      deepgw = aquifer_head(size(aquifer_head))
    else
      do upper = 2, size(date_t1900)
        if (date_t1900(upper) >= query_t1900) exit
      end do
      slope = (aquifer_head(upper) - aquifer_head(upper-1)) / &
              (date_t1900(upper) - date_t1900(upper-1))
      deepgw = aquifer_head(upper-1) + (query_t1900 - date_t1900(upper-1)) * slope
    end if
    if (.not. ieee_is_finite(deepgw)) then
      deepgw = 0.0_real64
      return
    end if
    status = PPA_LOW03_AQUIFER_TABLE_OK
  end subroutine evaluate_ppa_low03_aquifer_table

end module mod_ppa_low03_aquifer_table
